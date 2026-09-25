%% @doc The service contract, asserted locally.
%%
%% mcl_om resolves its callbacks BY NAME at startup, so a service that
%% forgets one dies with `undef' where nobody is watching. The
%% `-behaviour(mcl_om_service)' attribute turns that into a compile error;
%% this suite asserts everything the compiler cannot see: the shapes, the
%% names, the runtime pins, and the two lists that must stay in step --
%% subscriptions/0 and identity_spec/0. Nothing local boots mcl_om.
-module(mcl_bookclub_observer_service_tests).

-include_lib("eunit/include/eunit.hrl").

-define(APP, mcl_bookclub_observer).
-define(SERVICE, mcl_bookclub_observer_service).

exports_every_required_callback_test() ->
    _ = code:ensure_loaded(?SERVICE),
    Required = [{info, 0}, {start, 1}, {stop, 1},
                {health, 0}, {capabilities, 0}, {identity_spec, 0},
                {subscriptions, 0}],
    Missing = [F || {N, A} = F <- Required,
                    not erlang:function_exported(?SERVICE, N, A)],
    ?assertEqual([], Missing).

info_carries_the_three_keys_test() ->
    #{name := Name, version := Vsn, description := Desc} = ?SERVICE:info(),
    ?assert(is_binary(Name)),
    ?assert(is_binary(Vsn)),
    ?assert(is_binary(Desc)),
    ?assertEqual(<<"mcl-bookclub-observer">>, Name).

%% THE TWO NAMES MUST AGREE: the OTP application is snake_case, the mesh
%% name is kebab-case. They describe one service.
mesh_name_matches_the_application_test() ->
    #{name := Wire} = ?SERVICE:info(),
    Snake = atom_to_binary(?APP, utf8),
    ?assertEqual(binary:replace(Snake, <<"_">>, <<"-">>, [global]), Wire).

info_version_matches_the_application_test() ->
    _ = application:load(?APP),
    {ok, Vsn} = application:get_key(?APP, vsn),
    #{version := Reported} = ?SERVICE:info(),
    ?assertEqual(list_to_binary(Vsn), Reported).

%% The service's health IS the health of its read model: degraded until the
%% store is up, ok with it. One test, in that order, so the assertion never
%% depends on another test's leftovers.
health_probes_the_read_model_test() ->
    ?assertMatch({degraded, _}, ?SERVICE:health()),
    DataDir = tmp_dir(),
    os:putenv("MCL_DATA_DIR", DataDir),
    try
        {ok, Started} = application:ensure_all_started([esqlite]),
        {ok, Sup} = mcl_bookclub_observer_sup:start_link(),
        ?assertEqual(ok, ?SERVICE:health()),
        unlink(Sup),
        exit(Sup, shutdown),
        lists:foreach(fun(A) -> application:stop(A) end, lists:reverse(Started))
    after
        os:unsetenv("MCL_DATA_DIR"),
        file:del_dir_r(DataDir)
    end.

%% One capability today; the assertion is here so that growing the list is a
%% deliberate act with a name written down.
announces_exactly_the_existing_capabilities_test() ->
    ?assertEqual([#{name => <<"get_scoreboard">>,
                    version => 1,
                    handler => {mcl_bookclub_observer_get_scoreboard, []},
                    auth => open}],
                 ?SERVICE:capabilities()).

identity_spec_has_the_shape_mcl_om_expects_test() ->
    #{scope := Scope, actions := Actions,
      resources := Resources, ttl_days := Ttl} = ?SERVICE:identity_spec(),
    ?assert(is_binary(Scope)),
    ?assert(is_list(Actions)),
    ?assert(is_list(Resources)),
    ?assert(is_integer(Ttl) andalso Ttl > 0).

%% What is announced, what is subscribed and what authority is asked for
%% must stay in step: one action per capability, one resource per topic.
authority_matches_what_is_announced_and_subscribed_test() ->
    #{actions := Actions, resources := Resources} = ?SERVICE:identity_spec(),
    ?assertEqual([<<"get_scoreboard">>], Actions),
    Topics = [Topic || {Topic, _, _} <- ?SERVICE:subscriptions()],
    ?assertEqual(Resources, [topic_resource(T) || T <- Topics]),
    ?assertEqual(length(Actions), length(?SERVICE:capabilities())).

%% THE TOPICS ARE A CONTRACT WITH ANOTHER SERVICE. The authority for these
%% exact strings is mcl_bookclub_facts in macula-services/mcl-bookclub; a
%% topic change on either side of the wire must be a failing test
%% somewhere, not a silent unsubscription.
the_subscribed_topics_are_the_bookclub_s_published_topics_test() ->
    ?assertEqual([{<<"io.macula/mcl-bookclub/bookclub/member/member_registered_v1">>,
                   ingest_member_registered, []},
                  {<<"io.macula/mcl-bookclub/bookclub/book/book_procured_v1">>,
                   ingest_book_procured, []},
                  {<<"io.macula/mcl-bookclub/bookclub/book/book_retired_v1">>,
                   ingest_book_retired, []}],
                 ?SERVICE:subscriptions()).

%% The observer is storeless BY CONSTRUCTION: no reckon/evoq dep exists to
%% import, and no store callback exists to trigger the store wiring. This
%% asserts the callback half of that boundary.
the_service_opens_no_event_store_test() ->
    ?assertNot(erlang:function_exported(?SERVICE, store_id, 0)),
    ?assertNot(erlang:function_exported(?SERVICE, data_dir, 0)).

%% The supervisor starts and stops cleanly on its own, without mcl_om.
supervisor_starts_and_stops_test() ->
    {ok, Pid} = mcl_bookclub_observer_sup:start_link(),
    ?assert(is_process_alive(Pid)),
    ?assertMatch([{observer_read_model_store, _, _, _}],
                 supervisor:which_children(Pid)),
    unlink(Pid),
    exit(Pid, shutdown).

%%==============================================================================
%% The runtime is pinned in four places and they must agree
%%==============================================================================

the_runtime_agrees_between_the_image_the_ci_and_this_vm_test() ->
    Check = "\\{<<\"([0-9]+\\.[0-9]+\\.[0-9]+)\">>, true\\} -> halt\\(0\\);",
    Image = pinned("Containerfile", Check),
    Ci = pinned(".github/workflows/lint.yml", Check),
    Tools = pinned(".tool-versions", "^erlang ([0-9]+\\.[0-9]+\\.[0-9]+)$"),
    ?assertEqual([Image], lists:usort([Image, Ci, Tools, running_otp()])).

images_are_the_digest_pinned_team_pair_test() ->
    Digest = ":[0-9]{8}-[0-9]{4}@sha256:[0-9a-f]{64}",
    ?assertMatch(<<_/binary>>,
                 pinned("Containerfile",
                        "^FROM (ghcr\\.io/macula-io/macula-ci-otp)" ++ Digest ++ " AS builder$")),
    ?assertMatch(<<_/binary>>,
                 pinned("Containerfile",
                        "^FROM (ghcr\\.io/macula-io/macula-pq-runtime)" ++ Digest ++ "$")),
    ?assertEqual(pinned("Containerfile", "^FROM (ghcr\\.io/[^ ]+) AS builder$"),
                 pinned(".github/workflows/lint.yml", "^\\s+image: (ghcr\\.io/[^\\s]+)$")).

the_image_carries_its_revision_test() ->
    ?assertEqual(<<"REVISION">>, pinned("Containerfile", "^ARG (REVISION)=unknown$")),
    ?assertMatch(<<_/binary>>,
                 pinned("Containerfile",
                        "LABEL (org\\.opencontainers\\.image\\.revision=\"\\$\\{REVISION\\}\")")).

%% The full release, 28.4.3 and not 28: `otp_release' names only the major.
running_otp() ->
    {ok, Version} = file:read_file(filename:join([code:root_dir(), "releases",
                                                  erlang:system_info(otp_release),
                                                  "OTP_VERSION"])),
    string:trim(Version).

pinned(Relative, Pattern) ->
    {ok, Text} = file:read_file(alongside(Relative)),
    {match, [Version]} = re:run(Text, Pattern,
                                [multiline, {capture, all_but_first, binary}]),
    Version.

alongside(Name) -> climb(filename:dirname(code:which(?MODULE)), Name, 8).

climb(_Dir, Name, 0) -> Name;
climb(Dir, Name, Left) ->
    Candidate = filename:join(Dir, Name),
    found(filelib:is_regular(Candidate), Candidate, Dir, Name, Left).

found(true, Candidate, _Dir, _Name, _Left) -> Candidate;
found(false, _Candidate, Dir, Name, Left) ->
    climb(filename:dirname(Dir), Name, Left - 1).

%% A topic's resource under the observer's scope: the path after the org.
topic_resource(Topic) ->
    [_Realm, _Org | Path] = binary:split(Topic, <<"/">>, [global]),
    iolist_to_binary(lists:join("/", Path)).

tmp_dir() ->
    Dir = filename:join(["/tmp", "mcl_bookclub_observer_service_tests",
                         integer_to_list(erlang:unique_integer([positive]))]),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Dir.
