///|
test "resolve_url" {
  debug_inspect(
    resolve_url("http://www.example.org"),
    content=(
      #|(Http, 80, "www.example.org", "/")
    ),
  )
  debug_inspect(
    resolve_url("http://www.example.org/path/to"),
    content=(
      #|(Http, 80, "www.example.org", "/path/to")
    ),
  )
  debug_inspect(
    resolve_url("https://www.example.org/path/to?search=q"),
    content=(
      #|(Https, 443, "www.example.org", "/path/to?search=q")
    ),
  )
  try resolve_url("ftp://www.example.org") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|UnsupportedProtocol("ftp")
        ),
      )
  } noraise {
    _ => fail("expected resolve_url to raise")
  }
  debug_inspect(
    resolve_url("http://www.example.org:10042"),
    content=(
      #|(Http, 10042, "www.example.org", "/")
    ),
  )
  debug_inspect(
    resolve_url("http://www.example.org:10042/path"),
    content=(
      #|(Http, 10042, "www.example.org", "/path")
    ),
  )
  try resolve_url("http://www.example.org:0") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|InvalidFormat
        ),
      )
  } noraise {
    _ => fail("expected resolve_url to raise")
  }
  try resolve_url("http://www.example.org:100042") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|InvalidFormat
        ),
      )
  } noraise {
    _ => fail("expected resolve_url to raise")
  }
  // The regex keeps the original case of the scheme, so an uppercase scheme
  // still reports an unsupported protocol instead of a format error.
  try resolve_url("HTTP://www.example.org") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|UnsupportedProtocol("HTTP")
        ),
      )
  } noraise {
    _ => fail("expected resolve_url to raise")
  }
  // Empty host is rejected by the regex (the previous parser accepted it).
  try resolve_url("http://:80/path") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|InvalidFormat
        ),
      )
  } noraise {
    _ => fail("expected resolve_url to raise")
  }
}
