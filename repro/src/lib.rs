#![allow(unused)]

#[expect(clippy::disallowed_macros)]
mod bar {
    #[macrolib::attrib_macro]
    fn foo() {}
}

#[expect(clippy::disallowed_macros, reason = "I said so")]
#[macrolib::attrib_macro]
fn foo() {}

#[expect(clippy::disallowed_macros)]
#[derive(Clone)]
struct Baz;

#[expect(clippy::disallowed_macros)]
mod qux {
    #[derive(Clone)]
    struct Quux;
}

// These are commented out for now, until the bug with disallowed_macros lint and custom derive
// macros is resolved.
//#[expect(clippy::disallowed_macros)]
//#[derive(macrolib::CustomDerive)]
//struct Corge;
