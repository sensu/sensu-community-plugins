#!/usr/bin/env escript
%% -*- erlang -*-
%%
%% Simple (and mostly naive) script that connects to a remote Erlang node,
%% fetches memory and process statistics and prints them in a Sensu compatible way
%% for metrics gathering (great for Graphite)
%%
%% Usage:
%% ./erlang_stats.erl -c epic_erlang_cookie -n metrics@127.0.0.1 -r epic_erlang_app@127.0.0.1 -s prod.epic_erlang_app -p named_process1 -d true
%%
%% Copyright 2013 Panagiotis Papadomitsos <pj@ezgr.net>.
%%
%% Released under the same terms as Sensu (the MIT license); see LICENSE
%% for details.

main(Options) ->
    ParsedOptions = parse_options(Options),
    ok = set_local_node_name(ParsedOptions),
    ok = set_connection_cookie(ParsedOptions),
    ok = connect_to_remote_node(ParsedOptions),
    ok = collect_metrics(ParsedOptions),
    halt(0).

usage() ->
    io:format(standard_error, "Usage: ~s [-s SCHEME] [-c COOKIE] [-n NODE_NAME] [-r REMOTE_NODE]~n~n", [escript:script_name()]),
    io:format(standard_error, "  -s SCHEME       Set the metric scheme (default: host FQDN)~n", []),
    io:format(standard_error, "  -p PROCESSES    Set a comma-separated list of named processes to gather process info from~n", []),
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
        "-s" ->
            [Scheme|NewOptions] = Options,
            parse_options(NewOptions, [{scheme, Scheme}|ParsedOptions]);
        "-d" ->
            [_Debug|NewOptions] = Options,
            parse_options(NewOptions, [{debug, true}|ParsedOptions]);
        "-p" ->
            [ReadProcesses|NewOptions] = Options,
            Processes = string:tokens(ReadProcesses, ","),
            parse_options(NewOptions, [{processes, Processes}|ParsedOptions]);
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
    Node = proplists:get_value(node, ParsedOptions, "metrics@localhost.localdomain"),
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
        _OtherAnswer ->
            io:format(standard_error, "Invalid remote node specified or a connection could not be made!~n", []),
            halt(3)
    end.

print_metric(Scheme, Category, Key, Value, Timestamp) when is_atom(Key) ->
    print_metric(Scheme, Category, atom_to_list(Key), Value, Timestamp);
print_metric(Scheme, Category, Key, Value, Timestamp) when is_list(Key) ->
    io:format("~s.~s.~s ~B ~B~n", [Scheme, Category, Key, Value, Timestamp]).

print_metric(Scheme, Key, Value, Timestamp) when is_atom(Key) ->
    print_metric(Scheme, atom_to_list(Key), Value, Timestamp);
print_metric(Scheme, Key, Value, Timestamp) when is_list(Key) ->
    io:format("~s.~s ~B ~B~n", [Scheme, Key, Value, Timestamp]).

fetch_rpc_metric(Node, M, F, A, Callback, Debug) when is_list(Node) ->
    fetch_rpc_metric(list_to_atom(Node), M, F, A, Callback, Debug);
fetch_rpc_metric(Node, M, F, A, Callback, Debug) when is_atom(Node), is_atom(M), is_atom(F), is_list(A), is_function(Callback), is_atom(Debug) ->
    case rpc:call(Node, M, F, A) of
        {badrpc, Reason} when Debug =:= true ->
            io:format(standard_error, "RPC call failed with reason: ~p~n", [Reason]),
            error;
        {badrpc, _Reason} when Debug =:= false ->
            error;
        Result ->
            Callback(Result)
    end.

collect_metrics(ParsedOptions) ->
    Scheme = lists:flatten(proplists:get_value(scheme, ParsedOptions, element(2, inet:gethostname())), ".erlang"),
    RemoteNode = proplists:get_value(remote, ParsedOptions, "erlang@localhost.localdomain"),
    Debug = proplists:get_value(debug, ParsedOptions, false),
    Processes = proplists:get_value(processes, ParsedOptions, []),
    {Mega, Secs, _Micro} = erlang:now(),
    Timestamp = Mega * 1000000 + Secs,
    % Memory statistics
    fetch_rpc_metric(RemoteNode, erlang, memory, [], fun(MemoryMetrics) ->
        lists:foreach(fun({Key, Value}) ->
            print_metric(Scheme, "memory", Key, Value, Timestamp)
        end, MemoryMetrics)
    end, Debug),
    % Total number of processes
    fetch_rpc_metric(RemoteNode, erlang, processes, [], fun(LiveProcesses) ->
        print_metric(Scheme, "processes", erlang:length(LiveProcesses), Timestamp)
    end, Debug),
    % Context switches
    fetch_rpc_metric(RemoteNode, erlang, statistics, [context_switches], fun({Switches, 0}) ->
        print_metric(Scheme, "context_switches", Switches, Timestamp)
    end, Debug),
    % GC Metrics
    fetch_rpc_metric(RemoteNode, erlang, statistics, [garbage_collection], fun({NumberofGCs, WordsReclaimed, 0}) ->
        print_metric(Scheme, "number_of_gcs", NumberofGCs, Timestamp),
        print_metric(Scheme, "words_reclaimed", WordsReclaimed, Timestamp)
    end, Debug),
    % I/O Metrics
    fetch_rpc_metric(RemoteNode, erlang, statistics, [io], fun({{input, Input}, {output, Output}}) ->
            print_metric(Scheme, "input_io_bytes", Input, Timestamp),
            print_metric(Scheme, "output_io_bytes", Output, Timestamp)
    end, Debug),
    % Total number of scheduler reductions
    fetch_rpc_metric(RemoteNode, erlang, statistics, [reductions], fun({TotalReductions, _ReductionsSinceLastCall}) ->
            print_metric(Scheme, "reductions", TotalReductions, Timestamp)
    end, Debug),
    % Total nubmer of processes in the run_queue of each scheduler
    fetch_rpc_metric(RemoteNode, erlang, statistics, [run_queue], fun(RunQueue) ->
            print_metric(Scheme, "run_queue", RunQueue, Timestamp)
    end, Debug),
    % Process-specific info
    lists:foreach(fun(Process) ->
        fetch_rpc_metric(RemoteNode, erlang, whereis, [list_to_atom(Process)], fun(Pid) ->
            fetch_rpc_metric(RemoteNode, erlang, process_info, [Pid], fun(ProcessInfo) ->
                print_metric(Scheme, "process_info", Process ++ ".message_queue_len", proplists:get_value(message_queue_len, ProcessInfo, 0), Timestamp),
                print_metric(Scheme, "process_info", Process ++ ".total_heap_size", proplists:get_value(total_heap_size, ProcessInfo, 0), Timestamp),
                print_metric(Scheme, "process_info", Process ++ ".heap_size", proplists:get_value(heap_size, ProcessInfo, 0), Timestamp),
                print_metric(Scheme, "process_info", Process ++ ".reductions", proplists:get_value(reductions, ProcessInfo, 0), Timestamp),
                GCInfo = proplists:get_value(garbage_collection, ProcessInfo, []),
                print_metric(Scheme, "process_info", Process ++ ".minor_gcs", proplists:get_value(minor_gcs, GCInfo, 0), Timestamp)
            end, Debug)
        end, Debug)
    end, Processes),
    ok.
