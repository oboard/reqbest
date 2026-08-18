# oboard/reqbest

A MoonBit HTTP networking library with native HTTP/1.1, experimental HTTP/2
and HTTP/3 transports, and JavaScript Fetch support.

⚡ **Blazing fast**: reqbest is the fastest HTTP client in our cross-runtime
benchmark — 21,585 requests/sec, ahead of Go, Rust `hyper`, Bun, and Node.js.

[![Version](https://img.shields.io/badge/dynamic/json?url=https%3A//mooncakes.io/api/v0/manifest/oboard/reqbest&query=%24.latest_version&label=mooncakes&color=yellow)](https://mooncakes.io/docs/oboard/reqbest)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)

## Features

- 🚀 **Async support**: Request APIs are async on native and JavaScript targets.
- 🌐 **HTTP methods**: GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD, CONNECT,
  and TRACE are represented by `RequestMethod`.
- 📄 **Response helpers**: Read response bodies as binary, text, or JSON.
- 🌊 **Streaming HTTP/1.1**: Native stream APIs expose request/response bodies
  through `@io.Reader` and `@io.Writer`.
- 📦 **Compression**: Native responses can decode `gzip`, `deflate`, `br`, and
  `zstd` content encodings.
- 🎯 **Multi-backend**: Native uses MoonBit transports; JavaScript uses the
  platform Fetch implementation.
- 🔧 **Builder options**: Configure default headers, timeout, protocol mode,
  proxy, and certificate verification.

## Installation

Add to your `moon.mod.json`:

```bash
moon add oboard/reqbest
```

## Quick Start

### Basic GET Request

```moonbit nocheck
let response = @reqbest.get("https://api.github.com") catch {
    Err(e) => println("Error: " + e.to_string())
}
println("Response: " + response.text())
```

### Request Builder

```moonbit nocheck
///|
let client = @reqbest.RequestClient::builder()
  .default_header("User-Agent", "reqbest")
  .timeout(10000)
  .build()

///|
let response = client
  .post("https://api.example.com/items")
  .json({ "name": "moonbit" })
  .send()
```

### HTTP/2 Prior Knowledge

```moonbit nocheck
///|
let client = @reqbest.RequestClient::builder()
  .http2_prior_knowledge()
  .timeout(10000)
  .build()

///|
let response = client.get("http://localhost:3000/").send()
println(response.text())
```

### HTTP/3 Prior Knowledge

```moonbit nocheck
///|
let client = @reqbest.RequestClient::builder()
  .http3_prior_knowledge()
  .timeout(10000)
  .build()

///|
let response = client.get("https://example.com/").send()
println(response.text())
```

`danger_accept_invalid_certs(true)` disables certificate and hostname
verification. It is intended for local testing only.

## Protocol Support

| Mode | Native status | Notes |
| --- | --- | --- |
| HTTP/1.1 | Supported | Direct TCP/TLS transport with streaming APIs. |
| HTTP/2 | Experimental | Prior-knowledge client, HPACK, SETTINGS/HEADERS/DATA, PING, WINDOW_UPDATE, and GOAWAY handling. |
| HTTP/3 | Experimental | UDP QUIC path with X25519, TLS 1.3 ServerHello, EncryptedExtensions, Finished, QUIC Retry, Handshake ACKs, H3 SETTINGS, request streams, and response decoding. |
| JavaScript | Runtime-managed | Uses Fetch; protocol negotiation is handled by the host runtime. |

HTTP/2 and HTTP/3 are currently single-request transports. They do not yet
provide a hyper-style connection task, connection pooling, multiplexed request
scheduling, broad retransmission/loss recovery, or full certificate-chain
validation.

## Hyper Comparison

`hyper` separates an established connection into a request sender and a
connection future that continuously drives protocol state. `reqbest` currently keeps
HTTP/2 and HTTP/3 as compact single-request loops. The implementation is moving
toward the same separation of concerns:

- request construction is handled by `RequestClient` and `RequestBuilder`;
- protocol-specific transports live in HTTP/2 and HTTP/3 modules;
- connection state such as QUIC packet number spaces, Retry handling, and TLS
  transcript state is kept below the request API.

Unlike `hyper`, this package includes a MoonBit-native experimental QUIC/TLS
1.3/HTTP/3 path. That path is intentionally conservative and still needs more
transport work before it should be treated as production-ready.

## Benchmarks

Sequential HTTP/1.1 GET requests against a local server (128-byte payload,
10,000 requests, 200 warmup). Higher is better.

| Runtime | Requests/sec |
| --- | --- |
| **reqbest** | **21,585** |
| Go | 16,146 |
| hyper (Rust) | 14,540 |
| Bun | 13,451 |
| Node.js | 8,517 |

Run it yourself:

```sh
node benchmarks/scripts/run-http-client-bench.mjs --requests 10000 --warmup 200
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
