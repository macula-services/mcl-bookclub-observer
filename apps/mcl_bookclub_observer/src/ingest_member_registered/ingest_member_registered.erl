%% @doc Listener: member_registered_v1 facts from the mesh.
%%
%% The first of the three-module shape (listener -> policy -> projection):
%% verify the payload is a map, unwrap the wire shapes, hand the decision to
%% the policy, and nothing else. mcl_om:boot/1 wires this module as a
%% supervised macula_subscriber from the service's subscriptions/0; the
%% supervisor owns reconnects and replays, so there is no subscription code
%% here to get wrong.
-module(ingest_member_registered).

-behaviour(macula_subscriber).

-export([init/1, handle_event/4]).

init(Args) ->
    {ok, Args}.

handle_event(_Topic, Payload, _Meta, State) ->
    recorded(on_member_registered_fact_maybe_record:handle(Payload)),
    {noreply, State}.

recorded({record, Member}) ->
    _ = observer_read_model_store:record_member(Member),
    ok;
recorded(skip) ->
    ok.
