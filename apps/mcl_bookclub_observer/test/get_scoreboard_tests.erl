%% @doc The scoreboard: what was observed, answered and verified.
%%
%% The capability handler is exercised without the mesh: the scoreboard
%% comes from the local read model, and the one mesh call --
%% mcl-bookclub/get_bookclub_by_id -- is mecked, like every fleet suite
%% mocks its wire.
-module(get_scoreboard_tests).

-include_lib("eunit/include/eunit.hrl").

store_test_() ->
    {setup,
     fun observer_test_store:start/0,
     fun observer_test_store:stop/1,
     [fun the_scoreboard_is_empty_until_facts_arrive/0,
      fun the_scoreboard_counts_what_was_observed/0]}.

capability_test_() ->
    {foreach,
     fun observer_test_store:start/0,
     fun observer_test_store:stop/1,
     [fun the_capability_verifies_the_bookclub/0,
      fun the_capability_reports_unknown_with_no_club_observed/0,
      fun the_capability_reports_no_when_the_bookclub_refuses/0]}.

the_scoreboard_is_empty_until_facts_arrive() ->
    {ok, Board} = get_scoreboard:answer(),
    ?assertEqual(#{members => 0,
                   books_on_shelf => 0,
                   books_retired => 0,
                   last_registered => none}, Board).

the_scoreboard_counts_what_was_observed() ->
    {noreply, _} = ingest_member_registered:handle_event(
                     <<"t">>, #{member_id => <<"member-aa">>,
                               club_id => <<"bookclub-aa">>,
                               name => <<"Bea">>, registered_at => 42}, #{}, ok),
    {noreply, _} = ingest_book_procured:handle_event(
                     <<"t">>, #{book_id => <<"book-aa">>,
                               club_id => <<"bookclub-aa">>,
                               title => <<"T1">>, author => <<"A1">>,
                               procured_at => 1}, #{}, ok),
    {noreply, _} = ingest_book_retired:handle_event(
                     <<"t">>, #{book_id => <<"book-bb">>,
                               club_id => <<"bookclub-aa">>,
                               title => <<"T2">>, author => <<"A2">>,
                               procured_at => 1, retired_by => <<"raf">>,
                               retired_at => 2}, #{}, ok),
    {ok, Board} = get_scoreboard:answer(),
    ?assertEqual(1, maps:get(members, Board)),
    ?assertEqual(1, maps:get(books_on_shelf, Board)),
    ?assertEqual(1, maps:get(books_retired, Board)),
    ?assertEqual(#{club_id => <<"bookclub-aa">>, name => <<"Bea">>,
                   registered_at => 42}, maps:get(last_registered, Board)).

the_capability_verifies_the_bookclub() ->
    {noreply, _} = ingest_member_registered:handle_event(
                     <<"t">>, #{member_id => <<"member-aa">>,
                               club_id => <<"bookclub-aa">>,
                               name => <<"Bea">>, registered_at => 42}, #{}, ok),
    ok = meck_mesh({ok, #{}}),
    try
        {reply, Wire, undefined} =
            mcl_bookclub_observer_get_scoreboard:handle_request(#{}, undefined),
        ?assertEqual(yes, maps:get(bookclub_verified, Wire)),
        ?assertEqual(1, maps:get(members, Wire)),
        ?assertEqual({text, <<"Bea">>}, maps:get(name, maps:get(last_registered, Wire)))
    after
        meck:unload(mcl_om)
    end.

the_capability_reports_unknown_with_no_club_observed() ->
    ok = meck_mesh({ok, #{}}),
    try
        {reply, Wire, undefined} =
            mcl_bookclub_observer_get_scoreboard:handle_request(#{}, undefined),
        ?assertEqual(unknown, maps:get(bookclub_verified, Wire)),
        ?assertEqual(none, maps:get(last_registered, Wire))
    after
        meck:unload(mcl_om)
    end.

the_capability_reports_no_when_the_bookclub_refuses() ->
    {noreply, _} = ingest_member_registered:handle_event(
                     <<"t">>, #{member_id => <<"member-aa">>,
                               club_id => <<"bookclub-aa">>,
                               name => <<"Bea">>, registered_at => 42}, #{}, ok),
    ok = meck_mesh({error, not_found}),
    try
        {reply, Wire, undefined} =
            mcl_bookclub_observer_get_scoreboard:handle_request(#{}, undefined),
        ?assertEqual(no, maps:get(bookclub_verified, Wire))
    after
        meck:unload(mcl_om)
    end.

%%============================================================================
%% Helpers
%%============================================================================

meck_mesh(Reply) ->
    meck:new(mcl_om, [passthrough]),
    meck:expect(mcl_om, call_capability,
                fun(_Org, <<"get_bookclub_by_id">>, _Payload, _Timeout) -> Reply end).
