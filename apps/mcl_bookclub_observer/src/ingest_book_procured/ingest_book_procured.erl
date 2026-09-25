%% @doc Listener: book_procured_v1 facts from the mesh.
%%
%% Same three-module shape as ingest_member_registered: unwrap, hand to the
%% policy, act on the decision, nothing else.
-module(ingest_book_procured).

-behaviour(macula_subscriber).

-export([init/1, handle_event/4]).

init(Args) ->
    {ok, Args}.

handle_event(_Topic, Payload, _Meta, State) ->
    recorded(on_book_procured_fact_maybe_record:handle(Payload)),
    {noreply, State}.

recorded({record, Book}) ->
    _ = observer_read_model_store:record_book(Book),
    ok;
recorded(skip) ->
    ok.
