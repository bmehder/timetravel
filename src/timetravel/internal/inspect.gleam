//// Development-friendly structural formatting for arbitrary Gleam values.

@external(javascript, "./inspect_ffi.mjs", "inspectValue")
pub fn value(value: value) -> String

@external(javascript, "./inspect_ffi.mjs", "constructorName")
pub fn name(value: value) -> String
