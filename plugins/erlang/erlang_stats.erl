#!/usr/bin/env escript
%% -*- erlang -*-
%%
%% Simple (and mostly naive) script that connects to a remote Erlang node,
%% fetches memory and process statistics and prints them in a Sensu compatible way
%% for metrics gathering (great for Graphite)
%%
%% Usage:
%% ./erlang_stats.erl -c epic_erlang_cookie -n stats@127.0.0.1 -r epic_erlang_app@127.0.0.1 -s prod.epic_erlang_app
%%
%% Copyright 2013 Panagiotis Papadomitsos <pj@ezgr.net>.
%%
%% Released under the same terms as Sensu (the MIT license); see LICENSE
%% for details.

main(Options) ->
    ParsedOptions = parse_options(Options),
    ok = set_local_node_name(ParsedOptions),
    ok = set_cookie(ParsedOptions),
    ok = connect_to_remote_node(ParsedOptions),
    ok = collect_stats(ParsedOptions),
    halt(0).

usage() ->
    io:format(standard_error, "Usage: ~s [-s SCHEME] [-c COOKIE] [-n NODE_NAME] [-r REMOTE_NODE]~n~n", [escript:script_name()]),
    io:format(standard_error, "  -s SCHEME       Set the metric scheme (default: host FQDN)~n", []),
    io:format(standard_error, "  -c COOKIE       Set the Erlang cookie~n", []),
    io:format(standard_error, "  -n NODE_NAME    Set the Erlang node name (automatic short/long name detection)~n", []),
    io:format(standard_error, "  -r REMOTE_NODE  Set the Erlang node to connect to~n~n", []).

parse_options(Options) ->
    parse_options(Options, []).

%% We consider you a sane person that will provide the appropriate parameters
%% along with the switches, so no sanity check here
parse_options([Option|Options], ParsedOptions) ->
    case Option of
        "-s" ->
            [Scheme|NewOptions] = Options,
            parse_options(NewOptions, [{scheme, Scheme}|ParsedOptions]);
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
            halt(1);
        _ ->
            usage(),
            io:format(standard_error, "Invalid option specified!~n", []),
            halt(1)
    end;
parse_options([], ParsedOptions) ->
    ParsedOptions.

set_local_node_name(ParsedOptions) ->
    Node = proplists:get_value(node, ParsedOptions, "erlang@localhost.localdomain"),
    case lists:member($@, Node) of
        true ->
            net_kernel:start([list_to_atom(Node), longnames]);
        false ->
            net_kernel:start([list_to_atom(Node), shortnames])
    end,
    ok.

set_cookie(ParsedOptions) ->
    Cookie = proplists:get_value(cookie, ParsedOptions, "secret"),
    erlang:set_cookie(node(), list_to_atom(Cookie)),
    ok.

connect_to_remote_node(ParsedOptions) ->
    RemoteNode = proplists:get_value(remote, ParsedOptions, "erlang@localhost"),
    case net_adm:ping(list_to_atom(RemoteNode)) of
        pong ->
            ok;
        _OtherAnswer ->
            usage(),
            io:format(standard_error, "Invalid remote node specified or a connection could not be made!~n", []),
            halt(1)
    end.

collect_stats(ParsedOptions) ->
    Scheme = proplists:get_value(scheme, ParsedOptions, element(2, inet:gethostname()) ++ ".erlang"),
    RemoteNode = proplists:get_value(remote, ParsedOptions, "erlang@localhost"),
    {Mega, Secs, _Micro} = erlang:now(),
    Timestamp = Mega * 1000000 + Secs,
    case rpc:call(list_to_atom(RemoteNode), erlang, memory, []) of
        {badrpc, Reason} ->
            io:format(standard_error, "Could not fetch remote metrics with reason: ~p", [Reason]);
        MemoryStats when is_list(MemoryStats) ->
            lists:foreach(fun({Key, Value}) ->
                ActualKey = Scheme ++ ".memory." ++ atom_to_list(Key),
                io:format("~s ~B ~B~n", [ActualKey, Value, Timestamp])
            end, MemoryStats)
    end,
    case rpc:call(list_to_atom(RemoteNode), erlang, processes, []) of
        {badrpc, NReason} ->
            io:format(standard_error, "Could not fetch remote metrics with reason: ~p", [NReason]);
        Processes when is_list(Processes) ->
            io:format("~s ~B ~B~n", [Scheme ++ ".processes", erlang:length(Processes), Timestamp])
    end,

    ok.
