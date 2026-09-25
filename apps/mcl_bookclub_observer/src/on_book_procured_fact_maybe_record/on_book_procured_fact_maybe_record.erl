%% @doc Policy: should this book_procured fact be recorded?
%%
%% The admit/supersede decision. A procured fact is admitted only if the
%% book is not ALREADY retired: the retire supersedes, and a procured fact
%% that arrives late (or replays after a retire) must not resurrect the
%% book onto the shelf. That consult is the one read this policy makes, and
%% it is the whole reason the decision lives in its own module.
%%
%% Fields are read with mcl_om_wire:field/2 -- the real wire shapes are
%% `{text, Bin}' keys and values, and a hand-rolled maps:get is the bug
%% that silently drops every fact.
-module(on_book_procured_fact_maybe_record).

-export([handle/1]).

%% @doc {record, Params} for a well-formed fact that does not resurrect a
%% retired book, skip otherwise.
-spec handle(term()) -> {record, map()} | skip.
handle(Fact) when is_map(Fact) ->
    admitted(book_id(Fact), club_id(Fact), title(Fact), author(Fact),
             procured_at(Fact));
handle(_) ->
    skip.

admitted(BookId, ClubId, Title, Author, At)
        when is_binary(BookId), BookId =/= <<>>,
             is_binary(ClubId), ClubId =/= <<>>,
             is_binary(Title), Title =/= <<>>,
             is_binary(Author), Author =/= <<>>,
             is_integer(At) ->
    case observer_read_model_store:book_status(BookId) of
        {ok, <<"retired">>} -> skip;
        {ok, _} -> {record, book(BookId, ClubId, Title, Author, At)};
        {error, _} -> {record, book(BookId, ClubId, Title, Author, At)}
    end;
admitted(_, _, _, _, _) ->
    skip.

book(BookId, ClubId, Title, Author, At) ->
    #{book_id => BookId, club_id => ClubId, title => Title,
      author => Author, procured_at => At}.

book_id(Fact) -> mcl_om_wire:field(book_id, Fact).
club_id(Fact) -> mcl_om_wire:field(club_id, Fact).
title(Fact) -> mcl_om_wire:field(title, Fact).
author(Fact) -> mcl_om_wire:field(author, Fact).
procured_at(Fact) -> mcl_om_wire:field(procured_at, Fact).
