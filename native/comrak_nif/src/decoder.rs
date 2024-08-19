use crate::types::nodes::{AttrValue, ExNode};
use comrak::{
    nodes::{AstNode, NodeHeading, NodeValue},
    Arena,
};
use rustler::{Binary, Decoder, Error, Term};

pub fn to_comrak_ast<'a>(arena: &'a Arena<AstNode<'a>>, ex_node: &ExNode) -> &'a AstNode<'a> {
    todo!()
}
