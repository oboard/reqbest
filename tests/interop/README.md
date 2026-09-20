# Third-party interoperability tests

reqbest's HTTP/2 and HTTP/3 client implementations are tested against two
well-known, specification-conforming third-party server implementations:

| Protocol | Implementation                           | Endpoint              |
|----------|-------------------------------------------|-----------------------|
| HTTP/2   | `golang.org/x/net/http2` (h2c, prior knowledge) | `127.0.0.1:18080`     |
| HTTP/3   | `github.com/quic-go/quic-go/http3`       | `127.0.0.1:18443`     |

Both reference servers are built from a single, self-contained Go module
(`tests/interop/go/main.go`). They are only compiled and started when you ask
for the interop run; the regular `moon test` run skips them.

## Running the interop suite

From the repository root:

```sh
./tests/interop/scripts/run.sh
```

The script:

1. Builds the reference server **offline** from the local Go module cache
   (`GOPROXY=off` + `go.mod` with pinned `replace` directives, so no network
   access is required).
2. Starts both servers and waits for the `H2C_READY` / `H3_READY` lines.
3. Runs `moon test --target native -p oboard/reqbest interop_wbtest.mbt` with
   `REQBEST_INTEROP=1` so the suite is enabled.
4. Tears the server down and leaves the server log at
   `tests/interop/server.log`.

Without `REQBEST_INTEROP=1` the three interop tests report
`third-party interop tests are controlled by tests/interop/scripts/run.sh` —
that is the intended skip signal, not a failure.

## What is covered

- **HTTP/2 (`golang.org/x/net` h2c)** — `GET` and `POST` with a body. The test
  asserts `HTTP 200`, echoes back `proto=` / `method=` / `path=` from the
  handler, and checks the handler markers `X-Reqbest-Interop: golang` and
  `X-Reqbest-Proto: HTTP/2.0`.
- **HTTP/3 (quic-go)** — a full QUIC v1 handshake (Initial keys, header
  protection, TLS 1.3 inside QUIC crypto frames), the HTTP/3 control and
  request streams, and a QPACK-encoded response. The test asserts `HTTP 200`,
  `X-Reqbest-Proto: HTTP/3.0`, and that the body matches the request.

The self-signed certificate for HTTP/3 lives in `tests/interop/certs/` and is
used with `.danger_accept_invalid_certs(true)` (reqbest's client does not yet
implement chain validation; with verification off, hostname checking is also
bypassed, so `localhost` is fine).

## Debugging

Set `REQBEST_INTEROP_TRACE=1` before running `run.sh` to make the Go server
log a one-line summary (type, packet-number hint, length) of every QUIC
datagram it reads or writes — essential when diagnosing a handshake stall.

```sh
REQBEST_INTEROP_TRACE=1 ./tests/interop/scripts/run.sh
```

## Notable client limitations surfaced by these tests

reqbest's QUIC client is intentionally minimal: a single request per
connection, no connection migration, no loss recovery beyond acknowledging
what was received, and one crypto stream per handshake. quic-go requires the
client to acknowledge server packets in the handshake and application key
phases; without those ACKs the server's congestion window would not allow it
to deliver the full handshake flight or the response, which is why the tests
are the first exercise of that code path.
