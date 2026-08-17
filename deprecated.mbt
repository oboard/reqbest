///|
fn RequestMethod::write_show(self : RequestMethod, logger : &Logger) -> Unit {
  match self {
    Get => logger.write_string("Get")
    Head => logger.write_string("Head")
    Post => logger.write_string("Post")
    Put => logger.write_string("Put")
    Delete => logger.write_string("Delete")
    Connect => logger.write_string("Connect")
    Options => logger.write_string("Options")
    Trace => logger.write_string("Trace")
    Patch => logger.write_string("Patch")
  }
}

///|
fn Protocol::write_show(self : Protocol, logger : &Logger) -> Unit {
  match self {
    Http => logger.write_string("Http")
    Https => logger.write_string("Https")
  }
}

///|
fn Response::write_show(self : Response, logger : &Logger) -> Unit {
  logger.write_string("{code: ")
  logger.write_object(self.code)
  logger.write_string(", reason: ")
  logger.write_object(self.reason)
  logger.write_string(", headers: ")
  write_string_map_show(logger, self.headers)
  logger.write_string("}")
}

///|
fn write_string_map_show(logger : &Logger, map : Map[String, String]) -> Unit {
  logger.write_string("{")
  let mut first = true
  for key, value in map {
    if first {
      first = false
    } else {
      logger.write_string(", ")
    }
    logger.write_object(key)
    logger.write_string(": ")
    logger.write_object(value)
  }
  logger.write_string("}")
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for RequestMethod

///|
pub impl Show for RequestMethod with fn output(self, logger) {
  self.write_show(logger)
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for Response

///|
pub impl Show for Response with fn output(self, logger) {
  self.write_show(logger)
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for Protocol

///|
pub impl Show for Protocol with fn output(self, logger) {
  self.write_show(logger)
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for URIParseError

///|
pub impl Show for URIParseError with fn output(self, logger) {
  match self {
    InvalidFormat => logger.write_string("InvalidFormat")
    UnsupportedProtocol(protocol) =>
      logger
      ..write_string("UnsupportedProtocol(")
      ..write_object(protocol)
      .write_string(")")
  }
}

///|
#cfg(target="native")
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for ProxyError

///|
#cfg(target="native")
pub impl Show for ProxyError with fn output(self, logger) {
  match self {
    ProxyError(response) => {
      logger.write_string("ProxyError(")
      response.write_show(logger)
      logger.write_string(")")
    }
  }
}

///|
#cfg(target="native")
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for HttpProtocolError

///|
#cfg(target="native")
pub impl Show for HttpProtocolError with fn output(self, logger) {
  match self {
    BadRequest => logger.write_string("BadRequest")
    HttpVersionNotSupported(version) =>
      logger
      ..write_string("HttpVersionNotSupported(")
      ..write_object(version)
      .write_string(")")
    NotImplemented => logger.write_string("NotImplemented")
  }
}
