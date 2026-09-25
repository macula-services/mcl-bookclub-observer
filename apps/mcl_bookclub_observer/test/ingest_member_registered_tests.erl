%% @doc The member_registered ingestion, listener through store.
%%
%% The payloads below are what a macula_subscriber ACTUALLY receives on the
%% wire: keys as `{text, Bin}' tuples (the frame decoder does NOT atomize
%% pubsub payload keys) and string values `{text, Bin}'-wrapped. The
%% policy must resolve both -- that tolerance is the point of the tests --
%% and the publisher (the fact's own node id, from the event meta) rides
%% along: it is the node a verification call pins.
-module(ingest_member_registered_tests).

-include_lib("eunit/include/eunit.hrl").

store_test_() ->
    {setup,
     fun observer_test_store:start/0,
     fun observer_test_store:stop/1,
     [fun a_wire_fact_is_recorded/0,
      fun a_duplicate_fact_changes_nothing/0,
      fun a_malformed_fact_is_skipped/0]}.

pure_test_() ->
    [fun the_policy_accepts_atom_binary_and_wire_keys/0].

a_wire_fact_is_recorded() ->
    %% The exact live wire shape: {text, Bin} keys AND values.
    Fact = #{{text, <<"member_id">>} => {text, <<"member-aa">>},
             {text, <<"club_id">>} => {text, <<"bookclub-aa">>},
             {text, <<"club_name">>} => {text, <<"The Crooked Shelf">>},
             {text, <<"name">>} => {text, <<"Bea">>},
             {text, <<"registered_at">>} => 42},
    Publisher = <<0:256>>,
    {noreply, _} = ingest_member_registered:handle_event(
                      <<"io.macula/mcl-bookclub/bookclub/member/member_registered_v1">>,
                      Fact, #{publisher => Publisher}, ok),
    [[MemberId, ClubId, ClubName, Name, 42, PublisherHex]] =
        observer_read_model_store:q(
          "SELECT member_id, club_id, club_name, name, registered_at, publisher"
          " FROM members WHERE member_id = 'member-aa'", []),
    ?assertEqual(<<"member-aa">>, MemberId),
    ?assertEqual(<<"bookclub-aa">>, ClubId),
    ?assertEqual(<<"The Crooked Shelf">>, ClubName),
    ?assertEqual(<<"Bea">>, Name),
    ?assertEqual(binary:encode_hex(Publisher), PublisherHex).

a_duplicate_fact_changes_nothing() ->
    Fact = #{member_id => <<"member-bb">>, club_id => <<"bookclub-bb">>,
             club_name => <<"The Crooked Shelf">>, name => <<"Bea">>,
             registered_at => 42},
    {noreply, _} = ingest_member_registered:handle_event(<<"t">>, Fact, #{}, ok),
    {noreply, _} = ingest_member_registered:handle_event(<<"t">>, Fact, #{}, ok),
    [[1]] = observer_read_model_store:q(
              "SELECT COUNT(*) FROM members WHERE member_id = 'member-bb'", []).

%% A fact that fails shape checks is noise to skip, not an error to retry:
%% retrying would re-deliver the same malformed payload forever.
a_malformed_fact_is_skipped() ->
    Bad = #{{text, <<"member_id">>} => {text, <<"member-cc">>},
            {text, <<"club_id">>} => {text, <<"bookclub-cc">>},
            {text, <<"club_name">>} => {text, <<"The Crooked Shelf">>},
            {text, <<"registered_at">>} => 42},
    {noreply, _} = ingest_member_registered:handle_event(<<"t">>, Bad, #{}, ok),
    [[0]] = observer_read_model_store:q(
              "SELECT COUNT(*) FROM members WHERE member_id = 'member-cc'", []).

the_policy_accepts_atom_binary_and_wire_keys() ->
    Publisher = <<1:256>>,
    AtomKeyed = #{member_id => <<"member-1">>, club_id => <<"bookclub-1">>,
                  club_name => <<"C">>, name => <<"Bea">>, registered_at => 1},
    ?assertMatch({record, _},
                 on_member_registered_fact_maybe_record:handle(AtomKeyed, Publisher)),
    BinaryKeyed = #{<<"member_id">> => <<"member-1">>,
                    <<"club_id">> => <<"bookclub-1">>,
                    <<"club_name">> => <<"C">>,
                    <<"name">> => <<"Bea">>,
                    <<"registered_at">> => 1},
    ?assertMatch({record, _},
                 on_member_registered_fact_maybe_record:handle(BinaryKeyed, Publisher)),
    WireKeyed = #{{text, <<"member_id">>} => {text, <<"member-1">>},
                  {text, <<"club_id">>} => {text, <<"bookclub-1">>},
                  {text, <<"club_name">>} => {text, <<"C">>},
                  {text, <<"name">>} => {text, <<"Bea">>},
                  {text, <<"registered_at">>} => 1},
    ?assertMatch({record, _},
                 on_member_registered_fact_maybe_record:handle(WireKeyed, Publisher)),
    ?assertEqual(skip,
                 on_member_registered_fact_maybe_record:handle(not_a_map, Publisher)).