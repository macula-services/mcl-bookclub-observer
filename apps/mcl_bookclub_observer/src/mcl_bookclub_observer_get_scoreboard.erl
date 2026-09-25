%% @doc The mesh face of the scoreboard, advertised as
%% `mcl-bookclub-observer/get_scoreboard'.
%%
%% Local first, mesh second: the scoreboard is answered from the observer's
%% own read model, and then VERIFIED against the bookclub over the mesh --
%% a call to mcl-bookclub/get_bookclub_by_id for the last club the observer
%% saw. The bookclub's answer arriving is itself the cross-service proof
%% this whole observer exists to make; its absence is reported, never
%% hidden.
-module(mcl_bookclub_observer_get_scoreboard).

-behaviour(macula_response).

-export([init/1, handle_request/2]).

-define(BOOKCLUB_ORG, <<"mcl-bookclub">>).
-define(TIMEOUT_MS, 5000).

init(_Args) -> {ok, undefined}.

handle_request(_Payload, State) ->
    replied(get_scoreboard:answer(), State).

replied({ok, Board}, State) ->
    {reply, to_wire(verified(Board)), State};
replied({error, Reason}, State) ->
    {error, Reason, State}.

%% The verification names what it found: yes when the bookclub answered for
%% the last club observed, no when it was reached and refused or missed it,
%% unknown when no club has been observed yet.
verified(#{last_registered := #{club_id := ClubId}} = Board) ->
    Board#{bookclub_verified => verified_call(ClubId)};
verified(#{last_registered := none} = Board) ->
    Board#{bookclub_verified => unknown}.

verified_call(ClubId) ->
    case mcl_om:call_capability(?BOOKCLUB_ORG, <<"get_bookclub_by_id">>,
                                #{club_id => ClubId}, ?TIMEOUT_MS) of
        {ok, _} -> yes;
        {error, _} -> no
    end.

to_wire(B) when is_binary(B) -> {text, B};
to_wire(true) -> 1;
to_wire(false) -> 0;
to_wire(M) when is_map(M) -> maps:map(fun(_K, V) -> to_wire(V) end, M);
to_wire(Other) -> Other.
