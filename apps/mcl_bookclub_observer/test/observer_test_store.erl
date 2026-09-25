%% @doc Shared store boot for the observer's desk suites: the sqlite read
%% model, opened the way the supervisor opens it. The mesh never starts --
%% the listener suites call the subscriber callbacks directly, like every
%% fleet suite, and the verification suite mecks the one mesh call.
-module(observer_test_store).

-export([start/0, stop/1, path/1]).

-spec start() -> {string(), [atom()], pid()}.
start() ->
    Dir = filename:join(["/tmp", "observer_tests",
                         integer_to_list(erlang:unique_integer([positive]))]),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    {ok, Started} = application:ensure_all_started([esqlite]),
    {ok, Store} = observer_read_model_store:start_link(path(Dir)),
    unlink(Store),
    {Dir, Started, Store}.

-spec stop({string(), [atom()], pid()}) -> ok.
stop({Dir, Started, Store}) ->
    exit(Store, shutdown),
    [application:stop(App) || App <- lists:reverse(Started)],
    file:del_dir_r(Dir).

-spec path(string()) -> string().
path(Dir) ->
    filename:join(Dir, "bookclub_observer.sqlite3").
