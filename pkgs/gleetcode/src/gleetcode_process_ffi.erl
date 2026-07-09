-module(gleetcode_process_ffi).
-export([run/3, sleep/1]).

run(Command, Args, Cwd) ->
    case os:find_executable(binary_to_list(Command)) of
        false ->
            {error, <<"Executable not found">>};
        Path ->
            Port = open_port(
                {spawn_executable, Path},
                [
                    binary,
                    exit_status,
                    stderr_to_stdout,
                    use_stdio,
                    {cd, binary_to_list(Cwd)},
                    {args, [binary_to_list(Arg) || Arg <- Args]}
                ]
            ),
            collect_output(Port, [])
    end.

collect_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_output(Port, [Data | Acc]);
        {Port, {exit_status, Status}} ->
            {ok, {Status, iolist_to_binary(lists:reverse(Acc))}}
    end.

sleep(Ms) ->
    timer:sleep(Ms),
    nil.

