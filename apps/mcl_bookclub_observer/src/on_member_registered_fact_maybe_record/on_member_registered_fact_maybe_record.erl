%% @doc Policy: should this member_registered fact be recorded?
%%
%% The decision module, pure apart from its name: admit a well-formed fact,
%% skip anything else. A fact that fails shape checks is NOT an error to
%% retry -- retrying would re-deliver the same malformed payload forever --
%% it is noise to skip, which is the whole reason the decision has its own
%% module instead of living inside the listener.
-module(on_member_registered_fact_maybe_record).

-export([handle/1]).

%% @doc {record, Params} for a well-formed fact, skip otherwise. Keys may
%% be atoms or binaries (the wire atomizes; nothing is trusted).
-spec handle(term()) -> {record, map()} | skip.
handle(Fact) when is_map(Fact) ->
    admitted(member_id(Fact), club_id(Fact), name(Fact), registered_at(Fact));
handle(_) ->
    skip.

admitted(MemberId, ClubId, Name, At)
        when is_binary(MemberId), MemberId =/= <<>>,
             is_binary(ClubId), ClubId =/= <<>>,
             is_binary(Name), Name =/= <<>>,
             is_integer(At) ->
    {record, #{member_id => MemberId, club_id => ClubId,
               name => Name, registered_at => At}};
admitted(_, _, _, _) ->
    skip.

member_id(Fact) -> field(member_id, Fact).
club_id(Fact) -> field(club_id, Fact).
name(Fact) -> field(name, Fact).
registered_at(Fact) -> field(registered_at, Fact).

field(Key, Fact) ->
    maps:get(Key, Fact, maps:get(atom_to_binary(Key, utf8), Fact, undefined)).
