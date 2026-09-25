# mcl-bookclub-observer

**The consumer half of mcl-bookclub's facts: a storeless mesh service that
subscribes to what the bookclub publishes, folds it into its own read model,
and serves a scoreboard over the mesh.**

Where [mcl-bookclub](https://github.com/macula-services/mcl-bookclub) is the
producer — events, projections, emitters — this service is the consumer. It
owns no reckon-db store and never dispatches a command: it watches three fact
topics and answers one question ("what has the bookclub been up to?").

## What it does

| Topic (published by mcl-bookclub) | What the observer does with it |
|---|---|
| `bookclub/member/member_registered_v1` | records the member |
| `bookclub/book/book_procured_v1` | records the book as on-shelf — unless it is already retired |
| `bookclub/book/book_retired_v1` | supersedes: records the book as retired, in any arrival order |

Each fact goes through the three-module shape from mcl_om's
`guides/read_model_services.md`: a **listener** (a `macula_subscriber`, wired
by `subscriptions/0`) unwraps the wire payload and hands it to a **policy**
(the admit/supersede decision — the retired-book one is the reason the
policy is its own module), which hands it to the **read model** (one sqlite
file, absolute idempotent writes).

The one capability, `mcl-bookclub-observer/get_scoreboard`, answers from the
local read model and then **verifies the bookclub over the mesh** by calling
`mcl-bookclub/get_bookclub_by_id` for the last club observed — a live
cross-service call on every answer, reported as `bookclub_verified`.

## Why it exists

This service is the end-to-end proof of the FACT transport: the bookclub
emits, this observer consumes, and the two meet only over the mesh. Its
tests cover everything except the mesh itself (the one mesh call is mecked,
like every fleet suite); the live smoke test is the scoreboard's
`bookclub_verified => yes` on a box where both run.

## Status

First version: the three ingestions, the supersede policy, the scoreboard,
and the verification call. Not yet: history/trends, per-member views,
paged lists.

## Running it

    rebar3 compile
    rebar3 eunit
    rebar3 lint
    rebar3 dialyzer

    scripts/health.sh                      # against a running node

The runtime is pinned to OTP 28.4.3 (`.tool-versions`, Containerfile, lint
workflow); run `mise x erlang@28.4.3 -- rebar3 eunit` if your shell is on
another release. Building the image: `podman build -t mcl-bookclub-observer
-f Containerfile .`.

## Configuration

`config/sys.config.src` carries the realm, its trust anchor and the PQ
profile; `deploy/docker-compose.yml` is runnable as-is (`MCL_REALM`,
`MCL_REALM_KEY`, station seeds, and `MCL_COOKIE` from
`~/.macula/secrets/mcl-bookclub-observer.env`). The read model lives on the
`/data` volume.
