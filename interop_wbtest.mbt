///|
/// Interop tests primarily run through `tests/interop/scripts/run.sh`, which
/// builds the Go third-party servers, starts them, and exports
/// `REQBEST_INTEROP=1` so the tests below only execute when the well-known
/// x/net h2c and quic-go servers are actually available.
#cfg(target="native")
fn raise_failure(message : String) -> Unit raise {
  fail(message)
}

///|
#cfg(target="native")
fn interop_assert(value : Bool, message : String) -> Unit raise {
  guard value else { raise_failure(message) }
}

///|
#cfg(target="native")
fn interop_require_server() -> Unit raise {
  guard @env.get_env_var("REQBEST_INTEROP") == Some("1") else {
    raise_failure(
      "third-party interop tests are controlled by tests/interop/scripts/run.sh",
    )
  }
}

///|
#cfg(target="native")
fn interop_assert_golang_h2_response(
  response : ResponseBody,
  http_method : String,
) -> Unit raise {
  interop_assert(
    response.response.code == 200,
    "expected status 200, got \{response.response.code}",
  )
  interop_assert(
    response.response.headers.get("x-reqbest-interop") == Some("golang"),
    "missing x-reqbest-interop: golang header",
  )
  interop_assert(
    response.response.headers.get("x-reqbest-proto") == Some("HTTP/2.0"),
    "x-reqbest-proto was not HTTP/2.0",
  )
  let body = response.text()
  interop_assert(
    body.contains("proto=HTTP/2.0"),
    "body did not report HTTP/2.0: \{body}",
  )
  interop_assert(
    body.contains("method=\{http_method}"),
    "body did not report method \{http_method}: \{body}",
  )
}

///|
#cfg(target="native")
async test "golang x/net h2c GET interop" {
  interop_require_server()
  let client = RequestClient::builder()
    .http2_prior_knowledge()
    .timeout(10000)
    .build()
  let response = client.get("http://127.0.0.1:18080/get?x=1").send()
  interop_assert_golang_h2_response(response, "GET")
  interop_assert(
    response.text().contains("path=/get?x=1"),
    "body did not report path /get?x=1: \{response.text()}",
  )
}

///|
#cfg(target="native")
async test "golang x/net h2c POST body interop" {
  interop_require_server()
  let client = RequestClient::builder()
    .http2_prior_knowledge()
    .timeout(10000)
    .build()
  let response = client
    .post("http://127.0.0.1:18080/post")
    .body("hello h2")
    .send()
  interop_assert_golang_h2_response(response, "POST")
  interop_assert(
    response.text().contains("body=hello h2"),
    "body did not echo the POST payload: \{response.text()}",
  )
}

///|
#cfg(target="native")
async test "golang quic-go HTTP/3 GET interop" {
  interop_require_server()
  let client = RequestClient::builder()
    .http3_prior_knowledge()
    .timeout(15000)
    .danger_accept_invalid_certs(true)
    .build()
  let response = client.get("https://localhost:18443/get?x=1").send()
  interop_assert(
    response.response.code == 200,
    "expected status 200, got \{response.response.code}",
  )
  interop_assert(
    response.response.headers.get("x-reqbest-interop") == Some("golang"),
    "missing x-reqbest-interop: golang header",
  )
  interop_assert(
    response.response.headers.get("x-reqbest-proto") == Some("HTTP/3.0"),
    "x-reqbest-proto was not HTTP/3.0",
  )
  let body = response.text()
  interop_assert(
    body.contains("proto=HTTP/3.0"),
    "body did not report HTTP/3.0: \{body}",
  )
  interop_assert(
    body.contains("method=GET"),
    "body did not report GET: \{body}",
  )
  interop_assert(
    body.contains("path=/get?x=1"),
    "body did not report path /get?x=1: \{body}",
  )
}
