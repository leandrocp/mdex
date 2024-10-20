pub mod document;
pub mod nodes;
pub mod options;

pub mod atoms {
    rustler::atoms! {
        ok,
        error,
        invalid_structure,
        empty,
        missing_node_field,
        missing_attr_field,
        node_name_not_string,
        unknown_node_name,
        attr_key_not_string,
        unknown_attr_value,
    }
}
