%% @doc The observer's sqlite read model: one gen_server owning one esqlite
%% connection.
%%
%% A NIF connection belongs to the process that opened it, so every write
%% and read goes through this process. All writes are INSERT OR REPLACE
%% keyed on the fact's natural key -- absolute and idempotent, the same
%% discipline as the bookclub's projections, but with a difference worth
%% naming: a mesh FACT carries no applied position (no event_id, no
%% version), so this read model's idempotency is key-based last-write-wins
%% and its rows carry no position column.
-module(observer_read_model_store).

-behaviour(gen_server).

-export([start_link/1, record_member/1, record_book/1, retire_book/1,
         book_status/1, counts/0, last_member/0, q/2, schema/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    conn :: esqlite3:esqlite3()
}).

%% @doc The schema, in creation order. The one place the read model's shape
%% is written down.
-spec schema() -> [string()].
schema() ->
    ["CREATE TABLE IF NOT EXISTS members ("
     " member_id     TEXT PRIMARY KEY,"
     " club_id       TEXT NOT NULL,"
     " name          TEXT NOT NULL,"
     " registered_at INTEGER NOT NULL)",
     "CREATE TABLE IF NOT EXISTS books ("
     " book_id     TEXT PRIMARY KEY,"
     " club_id     TEXT NOT NULL,"
     " title       TEXT NOT NULL,"
     " author      TEXT NOT NULL,"
     " status      TEXT NOT NULL,"
     " procured_at INTEGER NOT NULL,"
     " retired_at  INTEGER,"
     " retired_by  TEXT)"].

-spec start_link(string()) -> {ok, pid()} | {error, term()}.
start_link(SqlitePath) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, SqlitePath, []).

%% @doc Record one observed registration, idempotently. The params map is
%% the validated fact the policy admitted.
-spec record_member(map()) -> ok | {error, term()}.
record_member(Params) ->
    gen_server:call(?MODULE, {record_member, Params}, 5000).

%% @doc Record one observed procurement: status 'on_shelf'.
-spec record_book(map()) -> ok | {error, term()}.
record_book(Params) ->
    gen_server:call(?MODULE, {record_book, Params}, 5000).

%% @doc Record one observed retirement: status 'retired', from the fact's
%% own payload (the bookclub's retired fact echoes procured_at).
-spec retire_book(map()) -> ok | {error, term()}.
retire_book(Params) ->
    gen_server:call(?MODULE, {retire_book, Params}, 5000).

%% @doc One book's current status, or not_found -- the policy consults it to
%% decide whether a late procured fact would resurrect a retired book.
-spec book_status(binary()) -> {ok, binary()} | {error, term()}.
book_status(BookId) ->
    gen_server:call(?MODULE, {book_status, BookId}, 5000).

%% @doc {Members, BooksOnShelf, BooksRetired}.
-spec counts() -> {non_neg_integer(), non_neg_integer(), non_neg_integer()} | {error, term()}.
counts() ->
    gen_server:call(?MODULE, counts, 5000).

%% @doc The most recently registered member, or none.
-spec last_member() -> map() | none | {error, term()}.
last_member() ->
    gen_server:call(?MODULE, last_member, 5000).

%% @doc One parameterised read, for tests and inspection.
-spec q(string(), list()) -> [list()] | {error, term()}.
q(Sql, Args) ->
    gen_server:call(?MODULE, {q, Sql, Args}, 5000).

%%====================================================================
%% gen_server
%%====================================================================

init(SqlitePath) ->
    ok = filelib:ensure_dir(SqlitePath),
    opened(esqlite3:open(SqlitePath)).

opened({ok, Conn}) ->
    schemed(Conn, create_schema(Conn, schema()));
opened({error, Reason}) ->
    {stop, {open_failed, Reason}}.

schemed(Conn, ok) ->
    {ok, #state{conn = Conn}};
schemed(_Conn, {error, Reason}) ->
    {stop, {schema_failed, Reason}}.

handle_call({record_member, #{member_id := MemberId, club_id := ClubId,
                              name := Name, registered_at := At}},
            _From, #state{conn = Conn} = State) ->
    {reply,
     do_exec(Conn,
             "INSERT OR REPLACE INTO members (member_id, club_id, name, registered_at)"
             " VALUES (?, ?, ?, ?)",
             [MemberId, ClubId, Name, At]),
     State};
handle_call({record_book, #{book_id := BookId, club_id := ClubId,
                            title := Title, author := Author, procured_at := At}},
            _From, #state{conn = Conn} = State) ->
    {reply,
     do_exec(Conn,
             "INSERT OR REPLACE INTO books"
             " (book_id, club_id, title, author, status, procured_at, retired_at, retired_by)"
             " VALUES (?, ?, ?, ?, 'on_shelf', ?, NULL, NULL)",
             [BookId, ClubId, Title, Author, At]),
     State};
handle_call({retire_book, #{book_id := BookId, club_id := ClubId,
                            title := Title, author := Author,
                            procured_at := ProcuredAt,
                            retired_by := RetiredBy, retired_at := RetiredAt}},
            _From, #state{conn = Conn} = State) ->
    {reply,
     do_exec(Conn,
             "INSERT OR REPLACE INTO books"
             " (book_id, club_id, title, author, status, procured_at, retired_at, retired_by)"
             " VALUES (?, ?, ?, ?, 'retired', ?, ?, ?)",
             [BookId, ClubId, Title, Author, ProcuredAt, RetiredAt, RetiredBy]),
     State};
handle_call({book_status, BookId}, _From, #state{conn = Conn} = State) ->
    {reply, book_status_q(Conn, BookId), State};
handle_call(counts, _From, #state{conn = Conn} = State) ->
    {reply, counts_q(Conn), State};
handle_call(last_member, _From, #state{conn = Conn} = State) ->
    {reply, last_member_q(Conn), State};
handle_call({q, Sql, Args}, _From, #state{conn = Conn} = State) ->
    {reply, esqlite3:q(Conn, Sql, Args), State};
handle_call(ping, _From, State) ->
    {reply, ok, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal
%%====================================================================

create_schema(Conn, [Sql | Rest]) ->
    case esqlite3:exec(Conn, Sql) of
        ok -> create_schema(Conn, Rest);
        {error, Reason} -> {error, Reason}
    end;
create_schema(_Conn, []) ->
    ok.

do_exec(Conn, Sql, Args) ->
    case esqlite3:q(Conn, Sql, Args) of
        [] -> ok;
        {error, Reason} -> {error, Reason};
        Rows -> {error, {unexpected_rows, Rows}}
    end.

book_status_q(Conn, BookId) ->
    case esqlite3:q(Conn, "SELECT status FROM books WHERE book_id = ?", [BookId]) of
        [[Status] | _] -> {ok, Status};
        [] -> {error, not_found};
        {error, Reason} -> {error, Reason}
    end.

counts_q(Conn) ->
    case {esqlite3:q(Conn, "SELECT COUNT(*) FROM members", []),
          esqlite3:q(Conn, "SELECT COUNT(*) FROM books WHERE status = 'on_shelf'", []),
          esqlite3:q(Conn, "SELECT COUNT(*) FROM books WHERE status = 'retired'", [])} of
        {[[Members]], [[OnShelf]], [[Retired]]} -> {Members, OnShelf, Retired};
        {{error, _} = Error, _, _} -> Error;
        {_, {error, _} = Error, _} -> Error;
        {_, _, {error, _} = Error} -> Error
    end.

last_member_q(Conn) ->
    case esqlite3:q(Conn,
                    "SELECT club_id, name, registered_at FROM members"
                    " ORDER BY registered_at DESC LIMIT 1",
                    []) of
        [[ClubId, Name, At] | _] -> #{club_id => ClubId, name => Name, registered_at => At};
        [] -> none;
        {error, Reason} -> {error, Reason}
    end.
