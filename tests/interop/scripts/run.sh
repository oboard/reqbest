#!/usr/bin/env bash
# Run reqbest's third-party interoperability tests.
#
# This script builds a self-contained Go binary that embeds both:
#   - golang.org/x/net/http2/h2c   (prior-knowledge HTTP/2 cleartext, h2c)
#   - github.com/quic-go/quic-go/http3 (HTTP/3 over QUIC)
#
# and then runs the MoonBit interop tests against those live servers.
# The Go modules resolve from the local module cache with GOPROXY=off (see
# tests/interop/go/go.mod for the pinned, cached versions), so no network
# access is required once the cache is populated.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GO_DIR="${REPO_ROOT}/tests/interop/go"
BIN_DIR="${REPO_ROOT}/tests/interop/bin"
BINARY="${BIN_DIR}/reqbest-interop-server"
LOG_FILE="${REPO_ROOT}/tests/interop/server.log"

mkdir -p "${BIN_DIR}"

echo "==> building third-party interop server (offline module cache)"
(cd "${GO_DIR}" && GOFLAGS=-mod=mod GOPROXY=off go build -o "${BINARY}" .)

echo "==> starting interop server (h2c: 127.0.0.1:18080 / h3: 127.0.0.1:18443)"
"${BINARY}" > "${LOG_FILE}" 2>&1 &
SERVER_PID=$!

CLEANED=0
cleanup() {
  if [[ ${CLEANED} -eq 0 ]]; then
    CLEANED=1
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Wait for both readiness lines.
for _ in $(seq 1 100); do
  if grep -q 'H3_READY' "${LOG_FILE}" 2>/dev/null; then
    break
  fi
  sleep 0.1
done

grep -q 'H2C_READY' "${LOG_FILE}" || { echo "H2C server did not start"; cat "${LOG_FILE}"; exit 1; }
grep -q 'H3_READY' "${LOG_FILE}" || { echo "H3 server did not start"; cat "${LOG_FILE}"; exit 1; }

echo "==> running reqbest interop tests"
cd "${REPO_ROOT}"
export REQBEST_INTEROP=1
moon test --target native -p oboard/reqbest interop_wbtest.mbt
STATUS=$?

echo "==> third-party interop tests finished with status ${STATUS}"
exit "${STATUS}"
