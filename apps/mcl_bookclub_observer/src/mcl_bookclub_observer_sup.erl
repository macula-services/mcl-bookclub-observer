%% @doc Supervises this service's own processes: the sqlite read model.
%%
%% The mesh subscribers are NOT here -- mcl_om:boot/1 wires the service's
%% subscriptions/0 triples into its own supervised pubsub tree, before
%% start/1 runs. What this service supervises is its store of observed
%% facts.
-module(mcl_bookclub_observer_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SqlitePath = filename:join(data_dir(), "bookclub_observer.sqlite3"),
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, [
        #{id => observer_read_model_store,
          start => {observer_read_model_store, start_link, [SqlitePath]},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [observer_read_model_store]}
    ]}}.

%% The same variable the bookclub's divisions read; the default only exists
%% for a laptop, the compose file mounts /data and sets it.
data_dir() ->
    chosen(os:getenv("MCL_DATA_DIR")).

chosen(false) -> "/tmp/mcl_bookclub_observer";
chosen("")    -> "/tmp/mcl_bookclub_observer";
chosen(Path)  -> Path.
