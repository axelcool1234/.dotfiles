-module(gleetcode_version_ffi).
-export([get_version/0]).

get_version() ->
    application:load(gleetcode),
    case application:get_key(gleetcode, vsn) of
        {ok, Vsn} -> unicode:characters_to_binary(Vsn);
        undefined -> <<"unknown">>
    end.

