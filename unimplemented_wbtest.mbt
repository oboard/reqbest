///|
#cfg(not(target="native"))
fn _ignore_unused_import() -> Unit {
  let _ : (&@io.Reader) -> _ = r => @gzip.Decoder(r)
  ignore(@async.sleep)
  ignore(@fs.unimplemented)
  ignore(@utf8.encode(""))
}
