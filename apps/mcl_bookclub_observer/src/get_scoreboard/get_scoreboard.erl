%% @doc get_scoreboard: the observer's own view of the bookclub.
%%
%% A pure query over the read model: member count, shelf counts, and the
%% most recent registration (club, name, when). The mesh capability wraps
%% this and adds the live verification of the bookclub itself.
-module(get_scoreboard).

-export([answer/0]).

%% @doc The scoreboard, or a store error. last_registered is `none' until
%% the first fact arrives -- the observer says what it saw, and "nothing
%% yet" is a truthful scoreboard.
-spec answer() -> {ok, map()} | {error, term()}.
answer() ->
    board(observer_read_model_store:counts(),
          observer_read_model_store:last_member()).

board({Members, OnShelf, Retired}, Last) when is_map(Last) ->
    {ok, #{members => Members,
           books_on_shelf => OnShelf,
           books_retired => Retired,
           last_registered => Last}};
board({Members, OnShelf, Retired}, none) ->
    {ok, #{members => Members,
           books_on_shelf => OnShelf,
           books_retired => Retired,
           last_registered => none}};
board(_Counts, {error, _} = Error) ->
    {error, Error};
board({error, _} = Error, _Last) ->
    {error, Error}.
