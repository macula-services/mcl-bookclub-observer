# mcl-bookclub-observer
#
# The consumer half of the bookclub's facts: a storeless mesh service that
# subscribes to mcl-bookclub's topics, folds what it sees into its own sqlite
# read model, and serves a scoreboard over the mesh.
#
# ONE DATA FILE ON THE /data VOLUME: the sqlite read model at
# /data/bookclub_observer.sqlite3. Without the mount every recreate forgets
# everything observed -- which is exactly as serious as losing the bookclub's
# store, and exactly as easy to prevent.
#
# ⚠ THE TEAM IMAGE PAIR, PINNED BY DATED TAG AND DIGEST, same pair and same
# digests as every sibling service. The runtime is pinned in four places and
# they must agree; mcl_bookclub_observer_service_tests compares all four.
FROM ghcr.io/macula-io/macula-ci-otp:20260923-1444@sha256:dd2ba6eb858a0eacedf0179300323fe5c6da46fb308d22da0ca8cfcd1f0718dc AS builder

# The OTP release, asserted here because the image tag names a date.
RUN erl -noshell -eval ' \
    Otp = string:trim(element(2, file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])))), \
    Mldsa = lists:member(mldsa87, crypto:supports(public_keys)), \
    io:format("OTP ~s, mldsa87 ~p~n", [Otp, Mldsa]), \
    case {Otp, Mldsa} of \
        {<<"28.4.3">>, true} -> halt(0); \
        _                    -> halt(1) \
    end.'

WORKDIR /build

# Dependencies resolve from rebar.config alone, so this layer survives every
# change to config/ and apps/.
COPY rebar.config ./
RUN rebar3 get-deps

COPY config ./config
COPY apps ./apps
RUN rebar3 as prod release

FROM ghcr.io/macula-io/macula-pq-runtime:20260923-1444@sha256:15a5501b7277804c5a62c93121d157773d1401d238a1bf630ef4b50fc2f1df09
# LINKS THE PACKAGE TO THE REPOSITORY, so ghcr shows it there and it inherits
# the repository's visibility.
LABEL org.opencontainers.image.source="https://github.com/macula-services/mcl-bookclub-observer"
# The commit this image was built from (build-push passes github.sha).
ARG REVISION=unknown
LABEL org.opencontainers.image.revision="${REVISION}"
WORKDIR /app
COPY --from=builder /build/_build/prod/rel/mcl_bookclub_observer ./

ENV HOME=/app
ENV RELX_REPLACE_OS_VARS=true

ENV MCL_NODE_NAME=mcl_bookclub_observer
ENV MCL_NODE_HOST=127.0.0.1
ENV MCL_COOKIE=mcl_bookclub_observer
ENV MCL_HEALTH_PORT=8453
# The sqlite read model.
ENV MCL_DATA_DIR=/data

VOLUME ["/etc/mcl/secrets", "/data"]

EXPOSE 8453
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${MCL_HEALTH_PORT}/health" || exit 1

CMD ["/app/bin/mcl_bookclub_observer", "foreground"]
