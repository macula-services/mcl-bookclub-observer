%% @doc Policy: should this book_retired fact be recorded?
%%
%% The supersede half: a well-formed retired fact is ALWAYS recorded, in
%% whatever order it arrives -- it carries procured_at (the bookclub's
%% retired fact echoes it), so the write is a whole-row REPLACE and never
%% depends on the procured fact having been seen first.
%%
%% Fields are read with mcl_om_wire:field/2 -- the real wire shapes are
%% `{text, Bin}' keys and values, and a hand-rolled maps:get is the bug
%% that silently drops every fact.
-module(on_book_retired_fact_maybe_record).

-export([handle/1]).

%% @doc {record, Params} for a well-formed fact, skip otherwise.
-spec handle(term()) -> {record, map()} | skip.
handle(Fact) when is_map(Fact) ->
    admitted(book_id(Fact), club_id(Fact), club_name(Fact), title(Fact),
             author(Fact), procured_at(Fact), retired_by(Fact), retired_at(Fact));
handle(_) ->
    skip.

admitted(BookId, ClubId, ClubName, Title, Author, ProcuredAt, RetiredBy, RetiredAt)
        when is_binary(BookId), BookId =/= <<>>,
             is_binary(ClubId), ClubId =/= <<>>,
             is_binary(ClubName),
             is_binary(Title), Title =/= <<>>,
             is_binary(Author), Author =/= <<>>,
             is_integer(ProcuredAt),
             is_binary(RetiredBy), RetiredBy =/= <<>>,
             is_integer(RetiredAt) ->
    {record, #{book_id => BookId, club_id => ClubId, club_name => ClubName,
               title => Title, author => Author, procured_at => ProcuredAt,
               retired_by => RetiredBy, retired_at => RetiredAt}};
admitted(_, _, _, _, _, _, _, _) ->
    skip.

book_id(Fact) -> mcl_om_wire:field(book_id, Fact).
club_id(Fact) -> mcl_om_wire:field(club_id, Fact).
club_name(Fact) -> mcl_om_wire:field(club_name, Fact).
title(Fact) -> mcl_om_wire:field(title, Fact).
author(Fact) -> mcl_om_wire:field(author, Fact).
procured_at(Fact) -> mcl_om_wire:field(procured_at, Fact).
retired_by(Fact) -> mcl_om_wire:field(retired_by, Fact).
retired_at(Fact) -> mcl_om_wire:field(retired_at, Fact).
