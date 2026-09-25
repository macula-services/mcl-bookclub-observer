%% @doc The member_registered ingestion, listener through store.
%%
%% The payload is what a macula_subscriber actually receives: keys atomized
%% by the frame decoder and string values as CBOR `{text, Bin}' tuples. The
%% listener must unwrap both -- that tolerance is the point of the tests.
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
    [fun the_policy_accepts_atom_and_binary_keys/0].

a_wire_fact_is_recorded() ->
    Fact = #{<<"member_id">> => {text, <<"member-aa">>},
             <<"club_id">> => {text, <<"bookclub-aa">>},
             <<"name">> => {text, <<"Bea">>},
             <<"registered_at">> => 42},
    {noreply, _} = ingest_member_registered:handle_event(
                      <<"io.macula/mcl-bookclub/bookclub/member/member_registered_v1">>,
                      Fact, #{}, ok),
    [[MemberId, ClubId, Name, 42]] =
        observer_read_model_store:q(
          "SELECT member_id, club_id, name, registered_at"
          " FROM members WHERE member_id = 'member-aa'", []),
    ?assertEqual(<<"member-aa">>, MemberId),
    ?assertEqual(<<"bookclub-aa">>, ClubId),
    ?assertEqual(<<"Bea">>, Name).

a_duplicate_fact_changes_nothing() ->
    Fact = #{member_id => <<"member-bb">>, club_id => <<"bookclub-bb">>,
             name => <<"Bea">>, registered_at => 42},
    {noreply, _} = ingest_member_registered:handle_event(<<"t">>, Fact, #{}, ok),
    {noreply, _} = ingest_member_registered:handle_event(<<"t">>, Fact, #{}, ok),
    [[1]] = observer_read_model_store:q(
              "SELECT COUNT(*) FROM members WHERE member_id = 'member-bb'", []).

%% A fact that fails shape checks is noise to skip, not an error to retry:
%% retrying would re-deliver the same malformed payload forever.
a_malformed_fact_is_skipped() ->
    Bad = #{<<"member_id">> => {text, <<"member-cc">>},
            <<"club_id">> => {text, <<"bookclub-cc">>},
            <<"registered_at">> => 42},
    {noreply, _} = ingest_member_registered:handle_event(<<"t">>, Bad, #{}, ok),
    [[0]] = observer_read_model_store:q(
              "SELECT COUNT(*) FROM members WHERE member_id = 'member-cc'", []).

the_policy_accepts_atom_and_binary_keys() ->
    AtomKeyed = #{member_id => <<"member-1">>, club_id => <<"bookclub-1">>,
                  name => <<"Bea">>, registered_at => 1},
    ?assertMatch({record, _},
                 on_member_registered_fact_maybe_record:handle(AtomKeyed)),
    BinaryKeyed = #{<<"member_id">> => <<"member-1">>,
                    <<"club_id">> => <<"bookclub-1">>,
                    <<"name">> => <<"Bea">>,
                    <<"registered_at">> => 1},
    ?assertMatch({record, _},
                 on_member_registered_fact_maybe_record:handle(BinaryKeyed)),
    ?assertEqual(skip,
                 on_member_registered_fact_maybe_record:handle(not_a_map)).
