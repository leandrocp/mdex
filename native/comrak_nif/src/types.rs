pub mod document;
pub mod elixir_types;
pub mod options;

pub mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}
