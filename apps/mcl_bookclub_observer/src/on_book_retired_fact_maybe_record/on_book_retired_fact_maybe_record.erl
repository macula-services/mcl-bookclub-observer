%% @doc Policy: should this book_retired fact be recorded?
%%
%% The supersede half: a well-formed retired fact is ALWAYS recorded, in
%% whatever order it arrives -- it carries procured_at (the bookclub's
%% retired fact echoes it), so the write is a whole-row REPLACE and never
%% depends on the procured fact having been seen first.
-module(on_book_retired_fact_maybe_record).

-export([handle/1]).

%% @doc {record, Params} for a well-formed fact, skip otherwise.
-spec handle(term()) -> {record, map()} | skip.
handle(Fact) when is_map(Fact) ->
    admitted(book_id(Fact), club_id(Fact), title(Fact), author(Fact),
             procured_at(Fact), retired_by(Fact), retired_at(Fact));
handle(_) ->
    skip.

admitted(BookId, ClubId, Title, Author, ProcuredAt, RetiredBy, RetiredAt)
        when is_binary(BookId), BookId =/= <<>>,
             is_binary(ClubId), ClubId =/= <<>>,
             is_binary(Title), Title =/= <<>>,
             is_binary(Author), Author =/= <<>>,
             is_integer(ProcuredAt),
             is_binary(RetiredBy), RetiredBy =/= <<>>,
             is_integer(RetiredAt) ->
    {record, #{book_id => BookId, club_id => ClubId, title => Title,
               author => Author, procured_at => ProcuredAt,
               retired_by => RetiredBy, retired_at => RetiredAt}};
admitted(_, _, _, _, _, _, _) ->
    skip.

book_id(Fact) -> field(book_id, Fact).
club_id(Fact) -> field(club_id, Fact).
title(Fact) -> field(title, Fact).
author(Fact) -> field(author, Fact).
procured_at(Fact) -> field(procured_at, Fact).
retired_by(Fact) -> field(retired_by, Fact).
retired_at(Fact) -> field(retired_at, Fact).

field(Key, Fact) ->
    maps:get(Key, Fact, maps:get(atom_to_binary(Key, utf8), Fact, undefined)).
