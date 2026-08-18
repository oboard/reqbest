///|
test "parse cookie success" {
  debug_inspect(
    Cookie::parse("Cookie=value"),
    content=(
      #|{
      #|  name: "Cookie",
      #|  value: "value",
      #|  path: None,
      #|  expires_raw: None,
      #|  max_age: None,
      #|  domain: None,
      #|  secure: false,
      #|  http_only: false,
      #|  extensions: [],
      #|}
    ),
  )
  debug_inspect(
    Cookie::parse("Cookie="),
    content=(
      #|{
      #|  name: "Cookie",
      #|  value: "",
      #|  path: None,
      #|  expires_raw: None,
      #|  max_age: None,
      #|  domain: None,
      #|  secure: false,
      #|  http_only: false,
      #|  extensions: [],
      #|}
    ),
  )
  debug_inspect(
    Cookie::parse(
      "Cookie2=value2;path=/path/to/xxx; EXPIRES=Sun, 06 Nov 1994 08:49:37 GMT;Max-age=420000; domain=example.moonbitlang.com;SECURE; httponly; whatever=whatever",
    ),
    content=(
      #|{
      #|  name: "Cookie2",
      #|  value: "value2",
      #|  path: Some("/path/to/xxx"),
      #|  expires_raw: Some("Sun, 06 Nov 1994 08:49:37 GMT"),
      #|  max_age: Some(420000),
      #|  domain: Some("example.moonbitlang.com"),
      #|  secure: true,
      #|  http_only: true,
      #|  extensions: ["whatever=whatever"],
      #|}
    ),
  )
}

///|
test "parse cookie failure" {
  try Cookie::parse("Cookie") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|BadRequest
        ),
      )
  } noraise {
    _ => fail("expected Cookie::parse to raise")
  }
  try Cookie::parse("Cookie=value;Max-Age=xxx") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|BadRequest
        ),
      )
  } noraise {
    _ => fail("expected Cookie::parse to raise")
  }
}

///|
test "parse cookie scanner edge cases" {
  // Known attribute names without a value stay extensions (as before).
  debug_inspect(
    Cookie::parse("x=1;path"),
    content=(
      #|{
      #|  name: "x",
      #|  value: "1",
      #|  path: None,
      #|  expires_raw: None,
      #|  max_age: None,
      #|  domain: None,
      #|  secure: false,
      #|  http_only: false,
      #|  extensions: ["path"],
      #|}
    ),
  )
  // A flag name with a value is an extension, not the flag.
  debug_inspect(
    Cookie::parse("x=1;Secure=yes"),
    content=(
      #|{
      #|  name: "x",
      #|  value: "1",
      #|  path: None,
      #|  expires_raw: None,
      #|  max_age: None,
      #|  domain: None,
      #|  secure: false,
      #|  http_only: false,
      #|  extensions: ["Secure=yes"],
      #|}
    ),
  )
  // Empty attribute segments are kept as empty extensions.
  debug_inspect(
    Cookie::parse("a=b;;c=d"),
    content=(
      #|{
      #|  name: "a",
      #|  value: "b",
      #|  path: None,
      #|  expires_raw: None,
      #|  max_age: None,
      #|  domain: None,
      #|  secure: false,
      #|  http_only: false,
      #|  extensions: ["", "c=d"],
      #|}
    ),
  )
  // Trailing whitespace of an attribute value is stripped (attribute trim),
  // while the cookie value keeps its whitespace.
  debug_inspect(
    Cookie::parse("x=1 ; Path=/a  ; Max-Age=42 "),
    content=(
      #|{
      #|  name: "x",
      #|  value: "1 ",
      #|  path: Some("/a"),
      #|  expires_raw: None,
      #|  max_age: Some(42),
      #|  domain: None,
      #|  secure: false,
      #|  http_only: false,
      #|  extensions: [],
      #|}
    ),
  )
  // The first cookie name is not trimmed; attribute names are.
  debug_inspect(
    Cookie::parse("  spaced=value ;  Path=/x"),
    content=(
      #|{
      #|  name: "  spaced",
      #|  value: "value ",
      #|  path: Some("/x"),
      #|  expires_raw: None,
      #|  max_age: None,
      #|  domain: None,
      #|  secure: false,
      #|  http_only: false,
      #|  extensions: [],
      #|}
    ),
  )
}
