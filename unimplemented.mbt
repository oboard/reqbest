///|
/// This package currently does not support JavaScript backend
#cfg(not(target="native"))
#coverage.skip
pub let unimplemented : Unit = {
  ignore(@io.pipe)
  ignore(@socket.unimplemented)
  let _ : (&@io.Reader) -> _ = r => @gzip.Decoder(r)
}

///|
/// Keep the `tls` import used on targets where TLS ships as a stub.
/// (async 0.20.6 removed `tls.unimplemented` from the wasm target, where
/// the real TLS implementation from `tls.wasm.mbt` is compiled instead.)
#cfg(not(any(target="native", target="wasm")))
#coverage.skip
fn _tls_unimplemented_reference() -> Unit {
  ignore(@tls.unimplemented)
}

///|
/// On wasm TLS is implemented, so reference a real symbol instead.
#cfg(target="wasm")
#coverage.skip
fn _tls_wasm_reference() -> Unit {
  ignore(@tls.TrustedRoot::NoVerification)
}

///|
#cfg(not(target="js"))
#coverage.skip
#warnings("-alert_unimplemented")
let _unused : Unit = ignore(@js_async.AbortController::new)
