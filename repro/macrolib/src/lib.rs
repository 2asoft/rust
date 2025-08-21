use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, Item};

#[proc_macro_attribute]
pub fn attrib_macro(_args: TokenStream, input: TokenStream) -> TokenStream {
    // Parse the input to examine attributes
    let parsed_item = parse_macro_input!(input as Item);

    // Debug output to see what attributes are available
    let attrs = match &parsed_item {
        Item::Fn(item_fn) => &item_fn.attrs,
        Item::Struct(item_struct) => &item_struct.attrs,
        Item::Enum(item_enum) => &item_enum.attrs,
        _ => &vec![],
    };

    eprintln!("=== PROC MACRO DEBUG ===");
    eprintln!("Number of attributes found: {}", attrs.len());
    for (i, attr) in attrs.iter().enumerate() {
        eprintln!("Attribute {}: {}", i, quote!(#attr));
    }
    eprintln!("=== END DEBUG ===");

    quote! {
      fn foo() -> &'static str {
        "foo"
      }
    }
    .into()
}

#[proc_macro_derive(CustomDerive)]
pub fn custom_derive(input: TokenStream) -> TokenStream {
    // Debug print to see what attributes we receive
    let input_str = input.to_string();
    eprintln!("=== CUSTOM DERIVE DEBUG ===");
    eprintln!("Received input: {}", input_str);
    eprintln!("=== END DERIVE DEBUG ===");

    // Return empty impl (or whatever you want)
    TokenStream::new()
}
