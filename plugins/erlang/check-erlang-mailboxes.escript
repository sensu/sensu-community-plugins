#!/usr/bin/env escript
%% -*- erlang -*-
%%
%% Simple (and mostly naive) script that connects to a remote Erlang node,
%% and checks process mailboxes, printing them in a Sensu compatible way
%% for checks
%%
%% Usage:
%% ./check-erlang-mailboxes.escript -c epic_erlang_cookie -n metrics@127.0.0.1 -r epic_erlang_app@127.0.0.1 -W 1000 -C 5000 -d true
%%
%% Copyright 2014 Panagiotis Papadomitsos <pj@ezgr.net>.
%%
%% Released under the same terms as Sensu (the MIT license); see LICENSE
%% for details.

%% #RED
main(Options) ->
    ParsedOptions = parse_options(Options),
    ok = set_local_node_name(ParsedOptions),
    ok = set_connection_cookie(ParsedOptions),
    ok = connect_to_remote_node(ParsedOptions),
    ok = crawl_mailboxes(ParsedOptions),
    halt(0).

usage() ->
    io:format(standard_error, "Usage: ~s [-C CRITICAL] [-W WARNING] [-p PROCESSES] [-c COOKIE] [-n NODE_NAME] [-r REMOTE_NODE]~n~n", [escript:script_name()]),
    io:format(standard_error, "  -C CRITICAL     The number of messages in a mailbox considered critical~n", []),
    io:format(standard_error, "  -W WARNING      The number of messages in a mailbox considered warning level~n", []),
    io:format(standard_error, "  -c COOKIE       Set the Erlang cookie~n", []),
    io:format(standard_error, "  -n NODE_NAME    Set the Erlang node name (automatic short/long name detection)~n", []),
    io:format(standard_error, "  -r REMOTE_NODE  Set the Erlang node to connect to~n", []),
    io:format(standard_error, "  -d true         Enable debug mode to catch RPC call failures~n~n", []).

parse_options(Options) ->
    parse_options(Options, []).

%% We consider you a sane person that will provide the appropriate parameters
%% along with the switches, so no sanity check here
parse_options([Option|Options], ParsedOptions) ->
    case Option of
        "-d" ->
            [_Debug|NewOptions] = Options,
            parse_options(NewOptions, [{debug, true}|ParsedOptions]);
        "-C" ->
            [Critical|NewOptions] = Options,
            parse_options(NewOptions, [{critical, Critical}|ParsedOptions]);
        "-W" ->
            [Warning|NewOptions] = Options,
            parse_options(NewOptions, [{warning, Warning}|ParsedOptions]);
        "-c" ->
            [Cookie|NewOptions] = Options,
            parse_options(NewOptions, [{cookie, Cookie}|ParsedOptions]);
        "-n" ->
            [Node|NewOptions] = Options,
            parse_options(NewOptions, [{node, Node}|ParsedOptions]);
        "-r" ->
            [Remote|NewOptions] = Options,
            parse_options(NewOptions, [{remote, Remote}|ParsedOptions]);
        "-h" ->
            usage(),
            halt(0);
        _ ->
            usage(),
            io:format(standard_error, "Invalid option specified!~n", []),
            halt(3)
    end;
parse_options([], ParsedOptions) ->
    if
        length(ParsedOptions) < 1 ->
            usage(),
            halt(3);
        true ->
            ParsedOptions
    end.

set_local_node_name(ParsedOptions) ->
    Node = proplists:get_value(node, ParsedOptions, "sensucheck@localhost.localdomain"),
    case lists:member($@, Node) of
        true ->
            net_kernel:start([list_to_atom(Node), longnames]);
        false ->
            net_kernel:start([list_to_atom(Node), shortnames])
    end,
    ok.

set_connection_cookie(ParsedOptions) ->
    Cookie = proplists:get_value(cookie, ParsedOptions, "secret"),
    erlang:set_cookie(node(), list_to_atom(Cookie)),
    ok.

connect_to_remote_node(ParsedOptions) ->
    RemoteNode = proplists:get_value(remote, ParsedOptions, "erlang@localhost.localdomain"),
    case net_adm:ping(list_to_atom(RemoteNode)) of
        pong ->
            ok;
        pang ->
            io:format(standard_error, "Invalid remote node specified or a connection could not be made!~n", []),
            halt(3)
    end.

crawl_mailboxes(ParsedOptions) ->
    RemoteNode = proplists:get_value(remote, ParsedOptions, "erlang@localhost.localdomain"),
    Warning = case proplists:get_value(warning, ParsedOptions, 1000) of
            W when is_list(W) -> list_to_integer(W);
            W -> W
        end,
    Critical = case proplists:get_value(critical, ParsedOptions, 5000) of
            C when is_list(C) -> list_to_integer(C);
            C -> C
        end,
    RemoteNode = proplists:get_value(remote, ParsedOptions, "erlang@localhost.localdomain"),
    Debug = proplists:get_value(debug, ParsedOptions, false),
    try
        ok = crawl_mailboxes(Warning, Critical, RemoteNode, Debug)
    catch
        throw:process_over_limits ->
            ok;
        throw:process_does_not_exist ->
            ok
    end,
    ok.

crawl_mailboxes(Warning, Critical, RemoteNode, Debug) ->
    case fetch_rpc_metric(RemoteNode, erlang, processes, [], Debug) of
        error ->
            warning("Could not connect to node ~s", [RemoteNode]),
            throw(could_not_connect_to_node);
        Processes when is_list(Processes) ->
            lists:map(fun(Proc) ->
                    case fetch_rpc_metric(RemoteNode, erlang, process_info, [Proc, [registered_name, message_queue_len]], Debug) of
                        [{registered_name, []}, {message_queue_len, Mbox}] when Mbox >= Critical ->
                            critical("Message queue length for process ~p is ~B", [Proc, Mbox]),
                            throw(process_over_limits);
                        [{registered_name, Name}, {message_queue_len, Mbox}] when Mbox >= Critical ->
                            critical("Message queue length for process ~s (~p) is ~B", [Name, Proc, Mbox]),
                            throw(process_over_limits);
                        [{registered_name, []}, {message_queue_len, Mbox}] when Mbox >= Warning ->
                            warning("Message queue length for process ~p is ~B", [Proc, Mbox]),
                            throw(process_over_limits);
                        [{registered_name, Name}, {message_queue_len, Mbox}] when Mbox >= Warning ->
                            warning("Message queue length for process ~s (~p) is ~B", [Name, Proc, Mbox]),
                            throw(process_over_limits);
                        [{registered_name, _}, {message_queue_len, Mbox}] when Mbox < Warning ->
                            ok;
                        undefined ->
                            ok;
                        error ->
                            warning("Could not connect to node ~s", [RemoteNode]),
                            throw(could_not_connect_to_node)
                    end
                end, Processes),
            io:format("ErlCheck OK: All processes have mailboxes below limits~n")
    end.

fetch_rpc_metric(Node, M, F, A, Debug) when is_list(Node) ->
    fetch_rpc_metric(list_to_atom(Node), M, F, A, Debug);
fetch_rpc_metric(Node, M, F, A, Debug) when is_atom(Node), is_atom(M), is_atom(F), is_list(A), is_atom(Debug) ->
    case rpc:call(Node, M, F, A) of
        {badrpc, Reason} when Debug =:= true ->
            io:format(standard_error, "RPC call failed with reason: ~p~n", [Reason]),
            error;
        {badrpc, _Reason} when Debug =:= false ->
            error;
        Result ->
            Result
    end.

warning(Message, Args) ->
    io:format("ErlCheck WARNING: " ++ Message ++ "~n", Args),
    ok.

critical(Message, Args) ->
    io:format("ErlCheck CRITICAL: " ++ Message ++ "~n", Args),
    ok.
