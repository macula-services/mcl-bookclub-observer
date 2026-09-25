%% @doc get_scoreboard: the observer's own view of the bookclub fleet.
%%
%% A pure query over the read model: totals across every observed club,
%% plus one row per club (its name, membership, shelf counts, most recent
%% registration, and the node that publishes its facts). One topic set
%% serves a thousand clubs; this module is where they are told apart --
%% by club_id in the payload, never by namespace.
-module(get_scoreboard).

-export([answer/0]).

%% @doc The scoreboard, or a store error. `clubs' is `[]' until the first
%% fact arrives -- the observer says what it saw, and "nothing yet" is a
%% truthful scoreboard.
-spec answer() -> {ok, map()} | {error, term()}.
answer() ->
    board(observer_read_model_store:counts(),
          observer_read_model_store:clubs()).

board({Members, OnShelf, Retired}, {ok, Clubs}) ->
    {ok, #{members => Members,
           books_on_shelf => OnShelf,
           books_retired => Retired,
           clubs => Clubs}};
board({error, _} = Error, _Clubs) ->
    {error, Error};
board(_Counts, {error, _} = Error) ->
    {error, Error}.
