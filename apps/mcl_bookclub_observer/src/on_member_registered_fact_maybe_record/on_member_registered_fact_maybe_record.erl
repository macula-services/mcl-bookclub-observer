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
%%
%% The PUBLISHER (the fact's own node id, from the event meta) is admitted
%% alongside the fact: it is the node a verification call pins, the answer
%% to "which club, of the thousand, published this".
-module(on_member_registered_fact_maybe_record).

-export([handle/2]).

%% @doc {record, Params} for a well-formed fact, skip otherwise.
-spec handle(term(), term()) -> {record, map()} | skip.
handle(Fact, Publisher) when is_map(Fact) ->
    admitted(member_id(Fact), club_id(Fact), club_name(Fact), name(Fact),
             registered_at(Fact), Publisher);
handle(_, _) ->
    skip.

admitted(MemberId, ClubId, ClubName, Name, At, Publisher)
        when is_binary(MemberId), MemberId =/= <<>>,
             is_binary(ClubId), ClubId =/= <<>>,
             is_binary(ClubName),
             is_binary(Name), Name =/= <<>>,
             is_integer(At) ->
    {record, #{member_id => MemberId, club_id => ClubId,
               club_name => ClubName, name => Name,
               registered_at => At, publisher => Publisher}};
admitted(_, _, _, _, _, _) ->
    skip.

member_id(Fact) -> mcl_om_wire:field(member_id, Fact).
club_id(Fact) -> mcl_om_wire:field(club_id, Fact).
club_name(Fact) -> mcl_om_wire:field(club_name, Fact).
name(Fact) -> mcl_om_wire:field(name, Fact).
registered_at(Fact) -> mcl_om_wire:field(registered_at, Fact).
