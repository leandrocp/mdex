pub mod nodes;
pub mod options;

pub mod atoms {
    rustler::atoms! {
        ok,
        error,
        invalid_ast,
        invalid_ast_node_name,
        invalid_ast_node_attr_key,
        invalid_ast_node_attr_value,
    }
}
