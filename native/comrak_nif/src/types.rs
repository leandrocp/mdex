pub mod document;
pub mod options;

pub mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}
