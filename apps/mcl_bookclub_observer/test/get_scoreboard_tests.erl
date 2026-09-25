%% @doc The scoreboard: what was observed, answered and verified.
%%
%% One row per observed club, sorted by club id, plus totals. The
%% capability handler is exercised without the mesh: the scoreboard comes
%% from the local read model, and the one mesh call per club --
%% mcl-bookclub/get_bookclub_by_id, PINNED to the node that published the
%% club's facts -- is mecked, like every fleet suite mocks its wire.
-module(get_scoreboard_tests).

-include_lib("eunit/include/eunit.hrl").

store_test_() ->
    {setup,
     fun observer_test_store:start/0,
     fun observer_test_store:stop/1,
     [fun the_scoreboard_is_empty_until_facts_arrive/0,
      fun the_scoreboard_counts_what_was_observed_per_club/0]}.

capability_test_() ->
    {foreach,
     fun observer_test_store:start/0,
     fun observer_test_store:stop/1,
     [fun the_capability_verifies_each_club_pinned_to_its_publisher/0,
      fun the_capability_reports_unknown_with_no_club_observed/0,
      fun the_capability_reports_no_when_a_club_refuses/0]}.

the_scoreboard_is_empty_until_facts_arrive() ->
    {ok, Board} = get_scoreboard:answer(),
    ?assertEqual(#{members => 0,
                   books_on_shelf => 0,
                   books_retired => 0,
                   clubs => []}, Board).

the_scoreboard_counts_what_was_observed_per_club() ->
    Publisher = <<7:256>>,
    member(<<"member-aa">>, <<"bookclub-aa">>, <<"The Crooked Shelf">>, <<"Bea">>, 42, Publisher),
    member(<<"member-ab">>, <<"bookclub-ab">>, <<"The Other Shelf">>, <<"Coco">>, 43, <<8:256>>),
    book(<<"book-aa">>, <<"bookclub-aa">>, <<"The Crooked Shelf">>, 1),
    retired(<<"book-bb">>, <<"bookclub-ab">>, <<"The Other Shelf">>, 2),
    {ok, Board} = get_scoreboard:answer(),
    ?assertEqual(2, maps:get(members, Board)),
    ?assertEqual(1, maps:get(books_on_shelf, Board)),
    ?assertEqual(1, maps:get(books_retired, Board)),
    [ClubA, ClubB] = maps:get(clubs, Board),
    ?assertEqual(<<"bookclub-aa">>, maps:get(club_id, ClubA)),
    ?assertEqual(<<"The Crooked Shelf">>, maps:get(club_name, ClubA)),
    ?assertEqual(1, maps:get(members, ClubA)),
    ?assertEqual(1, maps:get(books_on_shelf, ClubA)),
    ?assertEqual(0, maps:get(books_retired, ClubA)),
    ?assertEqual(#{name => <<"Bea">>, registered_at => 42},
                 maps:get(last_registered, ClubA)),
    ?assertEqual(binary:encode_hex(Publisher), maps:get(publisher, ClubA)),
    ?assertEqual(<<"bookclub-ab">>, maps:get(club_id, ClubB)),
    ?assertEqual(1, maps:get(books_retired, ClubB)).

the_capability_verifies_each_club_pinned_to_its_publisher() ->
    Publisher = <<7:256>>,
    member(<<"member-aa">>, <<"bookclub-aa">>, <<"The Crooked Shelf">>, <<"Bea">>, 42, Publisher),
    %% mcl_om >= 0.28.2: the /5 pin branch is live, so the stub must be the
    %% /5 arity -- and the test asserts the call IS pinned to the publisher
    %% the fact named. An unpinned call reaches whichever node the DHT
    %% lists first, and with a second club under the same org the wrong
    %% node answers not_found.
    ok = meck_mesh(fun(_Org, _Name, #{club_id := _}, _Timeout, #{advertiser := Adv}) ->
                           ?assertEqual(Publisher, Adv),
                           {ok, #{}}
                   end),
    try
        {reply, Wire, undefined} =
            mcl_bookclub_observer_get_scoreboard:handle_request(#{}, undefined),
        [Club] = maps:get(clubs, Wire),
        ?assertEqual(yes, maps:get(bookclub_verified, Club)),
        ?assertEqual({text, <<"The Crooked Shelf">>}, maps:get(club_name, Club))
    after
        meck:unload(mcl_om)
    end.

the_capability_reports_unknown_with_no_club_observed() ->
    ok = meck_mesh(fun(_Org, _Name, _Payload, _Timeout, _Opts) -> {ok, #{}} end),
    try
        {reply, Wire, undefined} =
            mcl_bookclub_observer_get_scoreboard:handle_request(#{}, undefined),
        ?assertEqual([], maps:get(clubs, Wire))
    after
        meck:unload(mcl_om)
    end.

the_capability_reports_no_when_a_club_refuses() ->
    member(<<"member-aa">>, <<"bookclub-aa">>, <<"The Crooked Shelf">>, <<"Bea">>, 42, <<7:256>>),
    ok = meck_mesh(fun(_Org, _Name, _Payload, _Timeout, _Opts) -> {error, not_found} end),
    try
        {reply, Wire, undefined} =
            mcl_bookclub_observer_get_scoreboard:handle_request(#{}, undefined),
        [Club] = maps:get(clubs, Wire),
        ?assertEqual(no, maps:get(bookclub_verified, Club))
    after
        meck:unload(mcl_om)
    end.

%%============================================================================
%% Helpers
%%============================================================================

member(MemberId, ClubId, ClubName, Name, At, Publisher) ->
    {noreply, _} = ingest_member_registered:handle_event(
                     <<"t">>, #{member_id => MemberId,
                                club_id => ClubId,
                                club_name => ClubName,
                                name => Name,
                                registered_at => At},
                     #{publisher => Publisher}, ok).

book(BookId, ClubId, ClubName, At) ->
    {noreply, _} = ingest_book_procured:handle_event(
                     <<"t">>, #{book_id => BookId, club_id => ClubId,
                                club_name => ClubName,
                                title => <<"T1">>, author => <<"A1">>,
                                procured_at => At}, #{}, ok).

retired(BookId, ClubId, ClubName, At) ->
    {noreply, _} = ingest_book_retired:handle_event(
                     <<"t">>, #{book_id => BookId, club_id => ClubId,
                                club_name => ClubName,
                                title => <<"T2">>, author => <<"A2">>,
                                procured_at => 1, retired_by => <<"raf">>,
                                retired_at => At}, #{}, ok).

meck_mesh(Expect) ->
    meck:new(mcl_om, [passthrough]),
    meck:expect(mcl_om, call_capability, Expect).
