//// Development-friendly structural formatting for arbitrary Gleam values.
////
//// This automatic inspection relies on JavaScript constructor names. It is
//// intended for unminified development builds; minified builds should supply
//// explicit `Formatters` through the public API.

@external(javascript, "./inspect_ffi.mjs", "inspectValue")
pub fn value(value: value) -> String

@external(javascript, "./inspect_ffi.mjs", "constructorName")
pub fn name(value: value) -> String
