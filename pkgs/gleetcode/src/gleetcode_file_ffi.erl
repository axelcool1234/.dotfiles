-module(gleetcode_file_ffi).
-export([write_file/2, write_private_file/2, ensure_dir/1, list_dir/1]).

write_file(Path, Contents) ->
    case file:write_file(Path, Contents) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

write_private_file(Path, Contents) ->
    case file:write_file(Path, Contents) of
        ok ->
            case file:change_mode(Path, 8#600) of
                ok -> {ok, nil};
                {error, Reason} -> {error, Reason}
            end;
        {error, Reason} -> {error, Reason}
    end.

ensure_dir(Path) ->
    case filelib:ensure_dir(Path) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

list_dir(Path) ->
    case file:list_dir(Path) of
        {ok, Entries} ->
            {ok, [unicode:characters_to_binary(E) || E <- Entries]};
        {error, Reason} -> {error, Reason}
    end.

