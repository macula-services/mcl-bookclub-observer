%% @doc The member_registered ingestion, listener through store.
%%
%% The payloads below are what a macula_subscriber ACTUALLY receives on the
%% wire: keys as `{text, Bin}' tuples (the frame decoder does NOT atomize
%% pubsub payload keys) and string values `{text, Bin}'-wrapped. The
%% policy must resolve both -- that tolerance is the point of the tests.
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
             {text, <<"name">>} => {text, <<"Bea">>},
             {text, <<"registered_at">>} => 42},
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
    Bad = #{{text, <<"member_id">>} => {text, <<"member-cc">>},
            {text, <<"club_id">>} => {text, <<"bookclub-cc">>},
            {text, <<"registered_at">>} => 42},
    {noreply, _} = ingest_member_registered:handle_event(<<"t">>, Bad, #{}, ok),
    [[0]] = observer_read_model_store:q(
              "SELECT COUNT(*) FROM members WHERE member_id = 'member-cc'", []).

the_policy_accepts_atom_binary_and_wire_keys() ->
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
    WireKeyed = #{{text, <<"member_id">>} => {text, <<"member-1">>},
                  {text, <<"club_id">>} => {text, <<"bookclub-1">>},
                  {text, <<"name">>} => {text, <<"Bea">>},
                  {text, <<"registered_at">>} => 1},
    ?assertMatch({record, _},
                 on_member_registered_fact_maybe_record:handle(WireKeyed)),
    ?assertEqual(skip,
                 on_member_registered_fact_maybe_record:handle(not_a_map)).
