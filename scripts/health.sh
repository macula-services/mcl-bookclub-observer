#!/usr/bin/env bash
# Ask a running mcl-bookclub-observer how it is.
#
#   0  healthy
#   1  reachable, reports degraded or down
#   2  unreachable

set -euo pipefail

HOST="${1:-127.0.0.1}"
PORT="${MCL_HEALTH_PORT:-8453}"
URL="http://${HOST}:${PORT}/health"

if ! RESPONSE="$(curl -sS --max-time 5 -w '\n%{http_code}' "${URL}" 2>/dev/null)"; then
    echo "unreachable: ${URL}" >&2
    exit 2
fi

CODE="${RESPONSE##*$'\n'}"
BODY="${RESPONSE%$'\n'*}"

if command -v python3 >/dev/null 2>&1; then
    printf '%s' "${BODY}" | python3 -m json.tool 2>/dev/null || printf '%s\n' "${BODY}"
else
    printf '%s\n' "${BODY}"
fi

case "${CODE}" in
    200) exit 0 ;;
    "")  echo "no response from ${URL}" >&2 ; exit 2 ;;
    *)   echo "unhealthy (HTTP ${CODE}): ${URL}" >&2 ; exit 1 ;;
esac
