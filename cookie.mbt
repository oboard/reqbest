///|
pub fn Cookie::new(
  name : String,
  value : String,
  path? : String,
  expires_raw? : String,
  max_age? : Int64,
  domain? : String,
  secure? : Bool = false,
  http_only? : Bool = false,
  extensions? : Array[String] = [],
) -> Cookie {
  {
    name,
    value,
    path,
    expires_raw,
    max_age,
    domain,
    secure,
    http_only,
    extensions,
  }
}

///|
#cfg(target="native")
fn Cookie::parse(line : StringView) -> Cookie raise {
  // Tokenize `name=value; attr=val; flag` with a lexbuf-based scanner.
  // Each lexscan call consumes the prefix of one token and commits the
  // cursor, so repeated calls walk the cookie the same way a lexer consumes
  // a stream (see the streaming scanner pattern in the MoonBit docs).
  let lexbuf = @lexbuf.Lexbuf::from_string(line.to_owned())
  let name = lex_cookie_name(lexbuf)
  guard lex_cookie_equals(lexbuf) else { raise BadRequest }
  let value = lex_cookie_value(lexbuf)

  let mut path = None
  let mut expires_raw = None
  let mut max_age = None
  let mut domain = None
  let mut secure = false
  let mut http_only = false
  let extensions = []
  while lex_cookie_separator(lexbuf) {
    lex_cookie_skip_spaces(lexbuf)
    let attr_name = lex_cookie_name(lexbuf)
    let (attr_value, has_value) = if lex_cookie_equals(lexbuf) {
      (Some(lex_cookie_attr_value(lexbuf)), true)
    } else {
      (None, false)
    }
    match (attr_name.to_lower(), has_value) {
      ("path", true) => path = Some(attr_value.unwrap().to_owned())
      ("expires", true) => expires_raw = Some(attr_value.unwrap().to_owned())
      ("max-age", true) => {
        let value = @string.parse_int64(attr_value.unwrap()) catch {
          _ => raise BadRequest
        }
        max_age = Some(value)
      }
      ("domain", true) => domain = Some(attr_value.unwrap().to_owned())
      ("secure", false) => secure = true
      ("httponly", false) => http_only = true
      _ =>
        extensions.push(
          if has_value {
            attr_name.to_owned() + "=" + attr_value.unwrap().to_owned()
          } else {
            attr_name.to_owned()
          },
        )
    }
  }
  {
    name: name.to_owned(),
    value: value.to_owned(),
    path,
    expires_raw,
    max_age,
    domain,
    secure,
    http_only,
    extensions,
  }
}

///|
#cfg(target="native")
/// Scans a cookie name: every character up to the first `=` (or `;` for
/// attribute names, which never contain `;` because separators are consumed
/// as their own tokens). An empty name is allowed for compatibility with the
/// previous hand-written parser.
fn lex_cookie_name(lexbuf : @lexbuf.Lexbuf) -> StringView {
  lexscan lexbuf with longest {
    re"^[^=;]*" as name => name
  }
}

///|
#cfg(target="native")
/// Consumes a single `=` token, returning whether one was present.
fn lex_cookie_equals(lexbuf : @lexbuf.Lexbuf) -> Bool {
  lexscan lexbuf with longest {
    re"^=" => true
    _ => false
  }
}

///|
#cfg(target="native")
/// Scans a cookie value: everything up to the next `;` (possibly empty).
fn lex_cookie_value(lexbuf : @lexbuf.Lexbuf) -> StringView {
  lexscan lexbuf with longest {
    re"^[^;]*" as value => value
  }
}

///|
#cfg(target="native")
/// Like `lex_cookie_value`, but strips trailing whitespace to mirror the
/// whole-attribute trim performed by the previous parser.
fn lex_cookie_attr_value(lexbuf : @lexbuf.Lexbuf) -> StringView {
  lexscan lexbuf with longest {
    re"^[^;]*" as value => value.trim_end()
  }
}

///|
#cfg(target="native")
/// Consumes a single `;` separator, returning whether one was present.
fn lex_cookie_separator(lexbuf : @lexbuf.Lexbuf) -> Bool {
  lexscan lexbuf with longest {
    re"^;" => true
    _ => false
  }
}

///|
#cfg(target="native")
/// Skips leading whitespace before an attribute name; the previous parser
/// trimmed each attribute segment.
fn lex_cookie_skip_spaces(lexbuf : @lexbuf.Lexbuf) -> Unit {
  lexscan lexbuf with longest {
    re"^[[:space:]]+" as spaces => ignore(spaces)
    _ => ()
  }
}
