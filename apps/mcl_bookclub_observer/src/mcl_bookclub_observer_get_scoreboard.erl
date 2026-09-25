%% @doc The mesh face of the scoreboard, advertised as
%% `mcl-bookclub-observer/get_scoreboard'.
%%
%% Local first, mesh second: the scoreboard is answered from the observer's
%% own read model, and then VERIFIED against the bookclub over the mesh --
%% for each observed club, a call to mcl-bookclub/get_bookclub_by_id PINNED
%% to the node that published that club's facts. The pin is the
%% many-club model's answer to "which club": with a thousand clubs under
%% one procedure, an unpinned call reaches whoever the DHT lists first,
%% and a club that does not own the asked id answers not_found, which is a
%% valid answer and not a failover signal. The fact's publisher IS the
%% club's node, so the call goes to the node that can answer it.
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

%% The verification names what it found, per club: yes when the club's own
%% node answered, no when it was reached and refused or missed it, unknown
%% when the fact arrived without a publisher (or no club has been observed
%% yet).
verified(Board) ->
    Board#{clubs => [verify_club(Club) || Club <- maps:get(clubs, Board)]}.

verify_club(#{publisher := <<>>} = Club) ->
    Club#{bookclub_verified => unknown};
verify_club(#{publisher := PublisherHex} = Club) ->
    Publisher = binary:decode_hex(PublisherHex),
    Club#{bookclub_verified => verified_call(maps:get(club_id, Club), Publisher)}.

verified_call(ClubId, Publisher) ->
    verdict(pinned_call(ClubId, Publisher)).

%% The /5 call is the pin, carried by mcl_om >= 0.28.2; until that release
%% is published the locked 0.28.1 has only /4. The static call below is
%% therefore a forward reference -- suppressed here, deliberately, and the
%% runtime gate is function_exported/3.
-dialyzer({nowarn_function, pinned_call/2}).

pinned_call(ClubId, Publisher) ->
    case erlang:function_exported(mcl_om, call_capability, 5) of
        true ->
            %% mcl_om >= 0.28.2: the advertiser pin exists -- only the club's
            %% own node is dialed.
            mcl_om:call_capability(?BOOKCLUB_ORG, <<"get_bookclub_by_id">>,
                                   #{club_id => ClubId}, ?TIMEOUT_MS,
                                   #{advertiser => Publisher});
        false ->
            %% mcl_om < 0.28.2: no pin exists yet; call unpinned until the
            %% release carrying it is published. With one club on the mesh
            %% that is correct; the pin is what makes a thousand correct.
            mcl_om:call_capability(?BOOKCLUB_ORG, <<"get_bookclub_by_id">>,
                                   #{club_id => ClubId}, ?TIMEOUT_MS)
    end.

verdict({ok, _}) -> yes;
verdict({error, _}) -> no.

to_wire(B) when is_binary(B) -> {text, B};
to_wire(true) -> 1;
to_wire(false) -> 0;
to_wire(M) when is_map(M) -> maps:map(fun(_K, V) -> to_wire(V) end, M);
to_wire(L) when is_list(L) -> [to_wire(E) || E <- L];
to_wire(Other) -> Other.
