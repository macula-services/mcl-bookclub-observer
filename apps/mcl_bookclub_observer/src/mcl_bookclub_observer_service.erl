%% @doc The mcl_om service contract: what this service is and may do.
%%
%% SIX CALLBACKS, ALL REQUIRED, plus subscriptions/0 -- the declarative mesh
%% subscription list mcl_om:boot/1 wires into its supervised pubsub tree.
%%
%% STORELESS, ON PURPOSE: no store_id/0 + data_dir/0 pair, so no reckon-db.
%% This service observes the bookclub, it does not keep one. The dependency
%% list in rebar.config enforces the same boundary the callbacks state: no
%% evoq, no reckon -- an import would not compile.
-module(mcl_bookclub_observer_service).

-behaviour(mcl_om_service).

-export([info/0, start/1, stop/1, health/0, capabilities/0, identity_spec/0]).
-export([subscriptions/0]).

info() ->
    #{name => <<"mcl-bookclub-observer">>,
      version => <<"0.1.0">>,
      description => <<"A scoreboard over mcl-bookclub's published facts.">>}.

start(_Opts) -> mcl_bookclub_observer_sup:start_link().

stop(_State) -> ok.

%% The service's health IS the health of its read model: the store of
%% observed facts. (The subscriptions' own liveness is mcl_om's supervised
%% concern; a dead subscriber restarts and replays, exactly like a bookclub
%% projection.)
health() ->
    case ping(observer_read_model_store) of
        ok -> ok;
        Other -> {degraded, #{read_model_store => Other}}
    end.

ping(Name) ->
    try gen_server:call(Name, ping, 1000) of
        Reply -> Reply
    catch
        exit:{noproc, _} -> missing;
        exit:Reason -> {down, Reason}
    end.

%% WHAT THIS SERVICE ANNOUNCES IT CAN DO: one procedure, the scoreboard.
capabilities() ->
    [#{name => <<"get_scoreboard">>,
       version => 1,
       handler => {mcl_bookclub_observer_get_scoreboard, []},
       auth => open}].

%% THE AUTHORITY THIS SERVICE ASKS THE REALM FOR: its one procedure, and
%% read authority on the three bookclub topics it subscribes to. A test
%% keeps this list, capabilities/0 and subscriptions/0 in step.
identity_spec() ->
    #{scope => <<"mcl-bookclub-observer">>,
      actions => [<<"get_scoreboard">>],
      resources => [<<"bookclub/member/member_registered_v1">>,
                    <<"bookclub/book/book_procured_v1">>,
                    <<"bookclub/book/book_retired_v1">>],
      ttl_days => 30}.

%% THE TOPICS THIS SERVICE LIVES ON. The authority for these exact strings
%% is mcl_bookclub_facts in macula-services/mcl-bookclub (the emitter side);
%% a test pins the three so a topic change on either side of the wire is a
%% failing test somewhere, not a silent unsubscription.
subscriptions() ->
    [{<<"io.macula/mcl-bookclub/bookclub/member/member_registered_v1">>,
      ingest_member_registered, []},
     {<<"io.macula/mcl-bookclub/bookclub/book/book_procured_v1">>,
      ingest_book_procured, []},
     {<<"io.macula/mcl-bookclub/bookclub/book/book_retired_v1">>,
      ingest_book_retired, []}].
