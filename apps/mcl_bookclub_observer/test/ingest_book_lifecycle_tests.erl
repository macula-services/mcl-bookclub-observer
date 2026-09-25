%% @doc The book lifecycle ingestion: procured and retired facts, and the
%% supersede decision that keeps a late procured fact from resurrecting a
%% retired book.
-module(ingest_book_lifecycle_tests).

-include_lib("eunit/include/eunit.hrl").

store_test_() ->
    {setup,
     fun observer_test_store:start/0,
     fun observer_test_store:stop/1,
     [fun a_procured_then_retired_book_ends_retired/0,
      fun a_retired_fact_arriving_first_is_not_resurrected/0,
      fun a_malformed_retired_fact_is_skipped/0]}.

a_procured_then_retired_book_ends_retired() ->
    BookId = <<"book-aa">>,
    {noreply, _} = ingest_book_procured:handle_event(
                     <<"t">>, procured(BookId), #{}, ok),
    {noreply, _} = ingest_book_retired:handle_event(
                     <<"t">>, retired(BookId), #{}, ok),
    ?assertEqual({ok, <<"retired">>},
                 observer_read_model_store:book_status(BookId)),
    {_, OnShelf, Retired} = observer_read_model_store:counts(),
    ?assertEqual(0, OnShelf),
    ?assertEqual(1, Retired).

%% THE SUPERSEDE TEST. The retired fact arrives first (facts are
%% at-least-once and unordered across topics); a procured fact that arrives
%% late must NOT put the book back on the shelf. The policy consults the
%% store and skips -- that consult is the whole reason the policy exists as
%% its own module.
a_retired_fact_arriving_first_is_not_resurrected() ->
    BookId = <<"book-bb">>,
    {noreply, _} = ingest_book_retired:handle_event(
                     <<"t">>, retired(BookId), #{}, ok),
    {noreply, _} = ingest_book_procured:handle_event(
                     <<"t">>, procured(BookId), #{}, ok),
    ?assertEqual({ok, <<"retired">>},
                 observer_read_model_store:book_status(BookId)).

a_malformed_retired_fact_is_skipped() ->
    Bad = #{book_id => <<"book-cc">>, club_id => <<"bookclub-cc">>,
            title => <<"T">>, author => <<"A">>, procured_at => 1,
            retired_by => <<"raf">>},
    {noreply, _} = ingest_book_retired:handle_event(<<"t">>, Bad, #{}, ok),
    ?assertEqual({error, not_found},
                 observer_read_model_store:book_status(<<"book-cc">>)).

%%============================================================================
%% Helpers
%%============================================================================

procured(BookId) ->
    #{book_id => BookId, club_id => <<"bookclub-aa">>,
      title => <<"Project Hail Mary">>, author => <<"Andy Weir">>,
      procured_at => 100}.

retired(BookId) ->
    #{book_id => BookId, club_id => <<"bookclub-aa">>,
      title => <<"Project Hail Mary">>, author => <<"Andy Weir">>,
      procured_at => 100, retired_by => <<"raf">>, retired_at => 200}.
