%% @doc Policy: should this member_registered fact be recorded?
%%
%% The decision module, pure apart from its name: admit a well-formed fact,
%% skip anything else. A fact that fails shape checks is NOT an error to
%% retry -- retrying would re-deliver the same malformed payload forever --
%% it is noise to skip, which is the whole reason the decision has its own
%% module instead of living inside the listener.
%%
%% Fields are read with mcl_om_wire:field/2, which resolves the real wire
%% shapes in one call: pubsub payload keys arrive as `{text, Bin}' tuples
%% (the frame decoder does NOT atomize them), and string values arrive
%% `{text, Bin}'-wrapped; both are unwrapped. A hand-rolled maps:get here
%% is the bug that silently drops every fact.
-module(on_member_registered_fact_maybe_record).

-export([handle/1]).

%% @doc {record, Params} for a well-formed fact, skip otherwise.
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

member_id(Fact) -> mcl_om_wire:field(member_id, Fact).
club_id(Fact) -> mcl_om_wire:field(club_id, Fact).
name(Fact) -> mcl_om_wire:field(name, Fact).
registered_at(Fact) -> mcl_om_wire:field(registered_at, Fact).
