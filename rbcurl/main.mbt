///|
/// A curl-like HTTP client powered by reqbest.
/// Usage: rbcurl [options...] <url>

///|
fn split_first(line : String, sep : String) -> (String?, String?) {
  let n = line.length()
  for i = 0; i < n; i = i + 1 {
    if line[i] == sep[0] {
      return (
        Some(line[:i].trim().to_owned()),
        Some(line[i + 1:].trim().to_owned()),
      )
    }
  }
  (None, None)
}

///|
fn flag_active(matches : @argparse.Matches, name : String) -> Bool {
  // Flags with default_values=[""]: value is empty when not explicitly set.
  match matches.values {
    { "output": _, .. } if name == "output" => true
    { "remote-name": _, .. } if name == "remote-name" => true
    { "silent": [v], .. } if name == "silent" => v != ""
    { "request": _, .. } if name == "request" => true
    { "data": _, .. } if name == "data" => true
    { "upload-file": _, .. } if name == "upload-file" => true
    { "header": _, .. } if name == "header" => true
    { "user-agent": _, .. } if name == "user-agent" => true
    { "user": _, .. } if name == "user" => true
    { "proxy": _, .. } if name == "proxy" => true
    { "connect-timeout": _, .. } if name == "connect-timeout" => true
    { "insecure": [v], .. } if name == "insecure" => v != ""
    { "verbose": [v], .. } if name == "verbose" => v != ""
    { "location": [v], .. } if name == "location" => v != ""
    { "include": [v], .. } if name == "include" => v != ""
    { "head": _, .. } if name == "head" => true
    { "fail": _, .. } if name == "fail" => true
    { "http2": _, .. } if name == "http2" => true
    { "http3": _, .. } if name == "http3" => true
    _ => false
  }
}

///|
async fn rbcurl_fetch(
  url : String,
  proxy_url~ : String?,
  http_version~ : @reqbest.HttpVersion,
  timeout_ms~ : Int?,
  insecure~ : Bool,
  extra_headers~ : Map[String, String],
  custom_method~ : @reqbest.RequestMethod?,
  body_data~ : String,
  verbose~ : Bool,
  follow_redirects~ : Bool,
) -> @reqbest.ResponseBody {
  let builder = @reqbest.RequestClient::builder()
  let builder = builder.default_headers(extra_headers)
  let builder = match proxy_url {
    Some(p) => builder.proxy(@reqbest.Client(p))
    None => builder
  }
  let builder = match timeout_ms {
    Some(t) => builder.timeout(t)
    None => builder
  }
  let builder = match http_version {
    @reqbest.Http2 => builder.http2_prior_knowledge()
    @reqbest.Http3 => builder.http3_prior_knowledge()
    _ => builder.http1_only()
  }
  let builder = if insecure {
    builder.danger_accept_invalid_certs(true)
  } else {
    builder
  }
  let client = builder.build()

  if verbose {
    @stdio.stderr.write("*   URL: \{url}\n")
  }

  let meth : @reqbest.RequestMethod = match custom_method {
    Some(m) => m
    _ if body_data.length() > 0 => @reqbest.Post
    _ => @reqbest.Get
  }

  if verbose {
    let method_debug = match meth {
      @reqbest.Get => "GET"
      @reqbest.Post => "POST"
      @reqbest.Put => "PUT"
      @reqbest.Delete => "DELETE"
      @reqbest.Patch => "PATCH"
      @reqbest.Head => "HEAD"
      @reqbest.Options => "OPTIONS"
      @reqbest.Connect => "CONNECT"
      @reqbest.Trace => "TRACE"
    }
    @stdio.stderr.write("*   Method: \{method_debug}\n")
    if extra_headers.length() > 0 {
      @stdio.stderr.write("*   Custom headers:\n")
      for k, v in extra_headers {
        @stdio.stderr.write("*     \{k}: \{v}\n")
      }
    }
    if body_data.length() > 0 {
      @stdio.stderr.write("*   Body data: \{body_data}\n")
    }
  }

  if follow_redirects {
    return rbcurl_follow(client, meth, url, body_data, 0, verbose~)
  }

  let request_builder = client.request(meth, url)
  if body_data.length() > 0 {
    ignore(request_builder.body(body_data))
  }
  request_builder.send()
}

///|
async fn rbcurl_follow(
  client : @reqbest.RequestClient,
  meth : @reqbest.RequestMethod,
  url : String,
  body_data : String,
  depth : Int,
  verbose~ : Bool,
) -> @reqbest.ResponseBody {
  let request_builder = client.request(meth, url)
  if body_data.length() > 0 {
    ignore(request_builder.body(body_data))
  }
  let response_body = request_builder.send()
  let code = response_body.response.code

  if code >= 300 && code < 400 && depth < 10 {
    let location = response_body.response.headers["location"]
    if verbose {
      @stdio.stderr.write("*   Redirect [\{depth + 1}] -> \{location}\n")
    }
    rbcurl_follow(client, meth, location, body_data, depth + 1, verbose~)
  } else {
    response_body
  }
}

///|
fn extract_filename(url : String) -> String {
  let mut last_slash = -1
  for i = 0; i < url.length(); i = i + 1 {
    if url[i] == '/' {
      last_slash = i
    }
  }
  if last_slash >= 0 {
    url[last_slash + 1:].to_owned()
  } else {
    url
  }
}

///|
async fn main {
  let matches = @argparse.Command(
    "rbcurl",
    about="A curl-like HTTP tool powered by reqbest",
    options=[
      OptionArg("output", short='o', about="Write to file instead of stdout"),
      OptionArg(
        "remote-name",
        short='O',
        about="Write output to file named as the remote file",
      ),
      OptionArg("silent", short='s', about="Silent mode", default_values=[""]),
      OptionArg(
        "request",
        short='X',
        about="HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS)",
      ),
      OptionArg("data", short='d', about="HTTP POST data"),
      OptionArg(
        "upload-file",
        short='T',
        about="Transfer local FILE to destination (PUT)",
      ),
      OptionArg(
        "header",
        short='H',
        about="Custom HTTP header, e.g. -H 'Key: Value'",
      ),
      OptionArg(
        "user-agent",
        short='A',
        about="Send User-Agent <name> to server",
      ),
      OptionArg(
        "user",
        short='u',
        about="Server user and password, e.g. 'user:password'",
      ),
      OptionArg("proxy", about="HTTP proxy URL"),
      OptionArg("connect-timeout", about="Connection timeout in seconds"),
      OptionArg("insecure", short='k', about="Skip TLS cert verification", default_values=[
        "",
      ]),
      OptionArg(
        "verbose",
        short='v',
        about="Make the operation more talkative",
        default_values=[""],
      ),
      OptionArg("location", short='L', about="Follow redirects", default_values=[
        "",
      ]),
      OptionArg(
        "include",
        short='i',
        about="Include response headers in output",
        default_values=[""],
      ),
      OptionArg("head", short='I', about="Fetch headers only (HEAD)"),
      OptionArg(
        "fail",
        short='f',
        about="Fail fast with no output on HTTP errors",
      ),
      OptionArg("http2", about="Use HTTP/2"),
      OptionArg("http3", about="Use HTTP/3"),
    ],
    positionals=[
      PositionArg("url", about="URL to fetch", num_args=ValueRange(lower=1)),
    ],
  ).parse()

  let url = matches.values["url"][0]

  // --- Build extra headers ---
  let extra_headers : Map[String, String] = Map([])
  if flag_active(matches, "header") {
    for line in matches.values["header"] {
      let (key, val) = split_first(line, ":")
      if key is Some(k) && val is Some(v) {
        extra_headers[k] = v
      }
    }
  }
  if flag_active(matches, "user-agent") {
    extra_headers["User-Agent"] = matches.values["user-agent"][0]
  }
  if flag_active(matches, "user") {
    extra_headers["Authorization"] = "Basic \{matches.values["user"][0]}"
  }

  // --- Method ---
  let custom_method : @reqbest.RequestMethod? = if flag_active(
      matches, "request",
    ) {
    Some(
      match matches.values["request"][0].to_upper() {
        "POST" => @reqbest.Post
        "PUT" => @reqbest.Put
        "DELETE" => @reqbest.Delete
        "PATCH" => @reqbest.Patch
        "HEAD" => @reqbest.Head
        "OPTIONS" => @reqbest.Options
        _ => @reqbest.Get
      },
    )
  } else {
    None
  }
  let force_head : Bool = flag_active(matches, "head")
  let has_upload : Bool = flag_active(matches, "upload-file")

  let meth : @reqbest.RequestMethod = if force_head {
    @reqbest.Head
  } else if has_upload && custom_method is None {
    @reqbest.Put
  } else if custom_method is Some(m) {
    m
  } else if flag_active(matches, "data") {
    @reqbest.Post
  } else {
    @reqbest.Get
  }

  // --- Body data ---
  let body_data : String = if flag_active(matches, "data") {
    matches.values["data"][0]
  } else {
    ""
  }

  // --- Output ---
  let output_path : String? = if flag_active(matches, "output") {
    Some(matches.values["output"][0])
  } else if flag_active(matches, "remote-name") {
    Some(extract_filename(url))
  } else {
    None
  }

  // --- Connection options ---
  let proxy_url : String? = if flag_active(matches, "proxy") {
    Some(matches.values["proxy"][0])
  } else {
    None
  }
  let insecure : Bool = flag_active(matches, "insecure")
  let timeout_ms : Int? = if flag_active(matches, "connect-timeout") {
    Some(@string.parse_int(matches.values["connect-timeout"][0]) * 1000)
  } else {
    None
  }
  let http_version : @reqbest.HttpVersion = if flag_active(matches, "http3") {
    @reqbest.Http3
  } else if flag_active(matches, "http2") {
    @reqbest.Http2
  } else {
    @reqbest.Http1
  }

  // --- Output flags ---
  let verbose : Bool = flag_active(matches, "verbose")
  let follow_redirects : Bool = flag_active(matches, "location")
  let include_headers : Bool = flag_active(matches, "include")
  let silent : Bool = flag_active(matches, "silent")
  let fail_fast : Bool = flag_active(matches, "fail")

  // --- Execute ---
  let response_body = rbcurl_fetch(
    url,
    proxy_url~,
    http_version~,
    timeout_ms~,
    insecure~,
    extra_headers~,
    custom_method=Some(meth),
    body_data~,
    verbose~,
    follow_redirects~,
  )

  let response = response_body.response
  let body = response_body.body

  if fail_fast && response.code >= 400 {
    if !silent {
      @stdio.stderr.write("rbcurl: HTTP error \{response.code} on \{url}\n")
    }
    return
  }

  match output_path {
    Some(path) => {
      let file = @fs.open(path, mode=WriteOnly, create_mode=CreateOrTruncate)
      defer file.close()
      if include_headers {
        write_response_headers(file, response)
      }
      file.write(body)
    }
    None => {
      if include_headers {
        write_response_headers(@stdio.stdout, response)
      }
      @stdio.stdout.write(body)
    }
  }
}

///|
async fn write_response_headers(
  w : &@io.Writer,
  res : @reqbest.Response,
) -> Unit {
  w.write("HTTP/1.1 \{res.code} \{res.reason}\r\n")
  for k, v in res.headers {
    w.write("\{k}: \{v}\r\n")
  }
  w.write("\r\n")
}
