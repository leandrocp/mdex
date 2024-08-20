use crate::types::nodes::{AttrValue, ExNode, NodeName};
use comrak::{
    nodes::{AstNode, ListDelimType, ListType, NodeCodeBlock, NodeList, NodeValue},
    Arena,
};
use rustler::{Binary, Decoder, Encoder, Env, Error, NifResult, Term};
use std::str::FromStr;

mod atoms {
    rustler::atoms! {
        error,
        invalid_ast,
        invalid_ast_node_name,
        invalid_ast_node_attr_key,
        invalid_ast_node_attr_value,
    }
}

#[derive(Debug)]
pub enum DecodeError {
    InvalidAst { found: String },
    InvalidAstNodeName { found: String },
    InvalidAstNodeAttrKey { found: String },
    InvalidAstNodeAttrValue { found: String },
}

impl Encoder for DecodeError {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            DecodeError::InvalidAst { found } => {
                let atom = atoms::invalid_ast().encode(env);
                ((atom, found.encode(env))).encode(env)
            }
            DecodeError::InvalidAstNodeName { found } => {
                let atom = atoms::invalid_ast_node_name().encode(env);
                ((atom, found.encode(env))).encode(env)
            }
            DecodeError::InvalidAstNodeAttrKey { found } => {
                let atom = atoms::invalid_ast_node_attr_key().encode(env);
                ((atom, found.encode(env))).encode(env)
            }
            DecodeError::InvalidAstNodeAttrValue { found } => {
                let atom = atoms::invalid_ast_node_attr_value().encode(env);
                ((atom, found.encode(env))).encode(env)
            }
        }
    }
}

impl From<DecodeError> for Error {
    fn from(err: DecodeError) -> Error {
        Error::Term(Box::new(err))
    }
}

impl<'a> Decoder<'a> for ExNode<'a> {
    fn decode(term: Term<'a>) -> NifResult<Self> {
        // println!("term: {:?}", term);

        let list: Vec<Term> = term.decode().map_err(|_| DecodeError::InvalidAst {
            found: format!("{:?}", term),
        })?;
        if list.len() != 1 {
            return Err(DecodeError::InvalidAst {
                found: format!("{:?}", term),
            }
            .into());
        }

        decode_node(&list[0])
    }
}

fn decode_node<'a>(term: &Term<'a>) -> NifResult<ExNode<'a>> {
    if let Ok(text) = term.decode::<String>() {
        return Ok(ExNode::Text(text));
    }

    let tuple: (Term, Vec<(Term, Term)>, Vec<Term>) =
        term.decode().map_err(|_| DecodeError::InvalidAst {
            found: format!("{:?}", term),
        })?;

    let name = tuple
        .0
        .decode::<Binary>()
        .map_err(|_| DecodeError::InvalidAstNodeName {
            found: format!("{:?}", tuple.0),
        })?;
    let name =
        std::str::from_utf8(name.as_slice()).map_err(|_| DecodeError::InvalidAstNodeName {
            found: format!("{:?}", name.as_slice()),
        })?;
    let name = NodeName::from_str(name).map_err(|_| DecodeError::InvalidAstNodeName {
        found: format!("{:?}", name),
    })?;

    let attrs = tuple
        .1
        .into_iter()
        .map(|(key, value)| {
            let key_binary: Binary =
                key.decode()
                    .map_err(|_| DecodeError::InvalidAstNodeAttrKey {
                        found: format!("{:?}", key),
                    })?;
            let key = std::str::from_utf8(key_binary.as_slice()).map_err(|_| {
                DecodeError::InvalidAstNodeAttrKey {
                    found: format!("{:?}", key),
                }
            })?;
            let attr_value: AttrValue =
                value
                    .decode()
                    .map_err(|_| DecodeError::InvalidAstNodeAttrValue {
                        found: format!("{:?}", value),
                    })?;
            Ok((key, attr_value))
        })
        .collect::<Result<Vec<_>, Error>>()?;

    let children = tuple
        .2
        .into_iter()
        .map(|child_term| decode_node(&child_term))
        .collect::<Result<Vec<_>, Error>>()?;

    Ok(ExNode::Element {
        name,
        attrs,
        children,
    })
}

// FIXME:: error handle
fn string_to_char(s: String) -> u8 {
    println!("string_to_char: {:?}", s);
    if s.len() == 0 {
        return 0;
    }

    s.chars().next().unwrap() as u8
}

pub fn ex_node_to_comrak_ast<'a>(
    arena: &'a Arena<AstNode<'a>>,
    ex_node: &ExNode,
) -> &'a AstNode<'a> {
    println!("ex_node: {:?}", ex_node);

    match ex_node {
        ExNode::Element {
            name,
            attrs,
            children,
        } => {
            let node_value = match name {
                NodeName::Document => AstNode::from(NodeValue::Document),
                NodeName::FrontMatter => {
                    let mut front_matter = NodeValue::FrontMatter("".to_string());

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"content", AttrValue::Text(ref value)) => {
                                front_matter = NodeValue::FrontMatter(value.clone())
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(front_matter)
                }
                NodeName::BlockQuote => AstNode::from(NodeValue::BlockQuote),
                NodeName::List => {
                    AstNode::from(NodeValue::List(attrs_to_node_list(attrs.to_vec())))
                }
                NodeName::Item => {
                    AstNode::from(NodeValue::Item(attrs_to_node_list(attrs.to_vec())))
                }
                NodeName::Paragraph => AstNode::from(NodeValue::Paragraph),
                NodeName::CodeBlock => {
                    let mut code_block = NodeCodeBlock::default();

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"fenced", AttrValue::Bool(ref value)) => code_block.fenced = *value,
                            (&"fence_char", AttrValue::Text(ref value)) => {
                                code_block.fence_char = string_to_char(value.clone())
                            }
                            (&"fence_length", AttrValue::Usize(ref value)) => {
                                code_block.fence_length = *value
                            }
                            (&"fence_offset", AttrValue::Usize(ref value)) => {
                                code_block.fence_offset = *value
                            }
                            (&"info", AttrValue::Text(ref value)) => {
                                code_block.info = value.clone()
                            }
                            (&"literal", AttrValue::Text(ref value)) => {
                                code_block.literal = value.clone()
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::CodeBlock(code_block))
                }
                _ => {
                    println!("{:?}", name);
                    todo!()
                }
            };

            let node = arena.alloc(node_value.into());

            for child in children {
                let child_node = ex_node_to_comrak_ast(arena, child);
                node.append(child_node);
            }

            node
        }
        ExNode::Text(content) => {
            let text = AstNode::from(NodeValue::Text(content.clone()));
            arena.alloc(text.into())
        }
    }
}

fn attrs_to_node_list(attrs: Vec<(&str, AttrValue)>) -> NodeList {
    println!("list attrs: {:?}", attrs);
    let mut list = NodeList::default();

    let to_list_type = |value: &str| -> ListType {
        match value {
            "bullet" => ListType::Bullet,
            "ordered" => ListType::Ordered,
            _ => ListType::default(),
        }
    };

    let to_delim_type = |value: &str| -> ListDelimType {
        match value {
            "period" => ListDelimType::Period,
            "paren" => ListDelimType::Paren,
            _ => ListDelimType::default(),
        }
    };

    for (key, value) in attrs {
        match (key, value) {
            ("list_type", AttrValue::Text(ref value)) => {
                list.list_type = to_list_type(value.as_str())
            }
            ("marker_offset", AttrValue::Usize(ref value)) => list.marker_offset = *value,
            ("padding", AttrValue::Usize(ref value)) => list.padding = *value,
            ("start", AttrValue::Usize(ref value)) => list.start = *value,
            ("delimiter", AttrValue::Text(ref value)) => {
                list.delimiter = to_delim_type(value.as_str())
            }
            ("bullet_char", AttrValue::Text(ref value)) => {
                list.bullet_char = string_to_char(value.clone())
            }
            ("tight", AttrValue::Bool(ref value)) => list.tight = *value,
            // FIXME: warning
            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
        }
    }

    list
}
