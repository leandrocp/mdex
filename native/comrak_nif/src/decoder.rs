use crate::types::nodes::{AttrValue, ExNode, NodeName};
use comrak::{
    nodes::{
        AstNode, ListDelimType, ListType, NodeCode, NodeCodeBlock, NodeDescriptionItem,
        NodeFootnoteDefinition, NodeFootnoteReference, NodeHeading, NodeHtmlBlock, NodeLink,
        NodeList, NodeMath, NodeMultilineBlockQuote, NodeShortCode, NodeTable, NodeValue,
        NodeWikiLink, TableAlignment,
    },
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
    if s.len() == 0 {
        return 0;
    }

    s.chars().next().unwrap() as u8
}

pub fn ex_node_to_comrak_ast<'a>(
    arena: &'a Arena<AstNode<'a>>,
    ex_node: &ExNode,
) -> &'a AstNode<'a> {
    match ex_node {
        ExNode::Element {
            name,
            attrs,
            children,
        } => {
            // println!("name: {:?}", name);
            // println!("attrs: {:?}", attrs);

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
                NodeName::DescriptionList => AstNode::from(NodeValue::DescriptionList),
                NodeName::DescriptionItem => {
                    let mut node = NodeDescriptionItem::default();

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"marker_offset", AttrValue::Usize(ref value)) => {
                                node.marker_offset = *value
                            }
                            (&"padding", AttrValue::Usize(ref value)) => node.padding = *value,
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::DescriptionItem(node))
                }
                NodeName::DescriptionTerm => AstNode::from(NodeValue::DescriptionTerm),
                NodeName::DescriptionDetails => AstNode::from(NodeValue::DescriptionDetails),
                NodeName::CodeBlock => {
                    let mut node = NodeCodeBlock::default();

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"fenced", AttrValue::Bool(ref value)) => node.fenced = *value,
                            (&"fence_char", AttrValue::Text(ref value)) => {
                                node.fence_char = string_to_char(value.clone())
                            }
                            (&"fence_length", AttrValue::Usize(ref value)) => {
                                node.fence_length = *value
                            }
                            (&"fence_offset", AttrValue::Usize(ref value)) => {
                                node.fence_offset = *value
                            }
                            (&"info", AttrValue::Text(ref value)) => node.info = value.clone(),
                            (&"literal", AttrValue::Text(ref value)) => {
                                node.literal = value.clone()
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::CodeBlock(node))
                }
                NodeName::HtmlBlock => {
                    let mut node = NodeHtmlBlock::default();

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"block_type", AttrValue::U8(ref value)) => node.block_type = *value,
                            (&"literal", AttrValue::Text(ref value)) => {
                                node.literal = value.clone()
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::HtmlBlock(node))
                }
                NodeName::Paragraph => AstNode::from(NodeValue::Paragraph),
                NodeName::Heading => {
                    let mut node = NodeHeading::default();

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"level", AttrValue::U8(ref value)) => node.level = *value,
                            (&"setext", AttrValue::Bool(ref value)) => node.setext = *value,
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::Heading(node))
                }
                NodeName::ThematicBreak => AstNode::from(NodeValue::ThematicBreak),
                NodeName::FootnoteDefinition => {
                    let mut node = NodeFootnoteDefinition::default();

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"name", AttrValue::Text(ref value)) => node.name = value.clone(),
                            (&"total_references", AttrValue::U32(ref value)) => {
                                node.total_references = *value
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::FootnoteDefinition(node))
                }
                NodeName::FootnoteReference => {
                    let mut node = NodeFootnoteReference::default();

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"name", AttrValue::Text(ref value)) => node.name = value.clone(),
                            (&"ref_num", AttrValue::U32(ref value)) => node.ref_num = *value,
                            (&"ix", AttrValue::U32(ref value)) => node.ix = *value,
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::FootnoteReference(node))
                }
                NodeName::Table => {
                    let mut node = NodeTable::default();

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"alignments", AttrValue::List(ref value)) => {
                                let alignments = value
                                    .iter()
                                    .map(|ta| match ta.as_str() {
                                        "none" => TableAlignment::None,
                                        "left" => TableAlignment::Left,
                                        "center" => TableAlignment::Center,
                                        "right" => TableAlignment::Right,
                                        _ => TableAlignment::None,
                                    })
                                    .collect::<Vec<TableAlignment>>();

                                node.alignments = alignments
                            }
                            (&"num_columns", AttrValue::Usize(ref value)) => {
                                node.num_columns = *value
                            }
                            (&"num_rows", AttrValue::Usize(ref value)) => node.num_rows = *value,
                            (&"num_nomempty_cells", AttrValue::Usize(ref value)) => {
                                node.num_nonempty_cells = *value
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::Table(node))
                }
                NodeName::TableRow => {
                    let mut table_row = NodeValue::TableRow(false);

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"header", AttrValue::Bool(ref value)) => {
                                table_row = NodeValue::TableRow(*value)
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(table_row)
                }
                NodeName::TableCell => AstNode::from(NodeValue::TableCell),
                NodeName::TaskItem => {
                    AstNode::from(NodeValue::TaskItem(attrs_to_task_item(attrs.to_vec())))
                }
                NodeName::SoftBreak => AstNode::from(NodeValue::SoftBreak),
                NodeName::LineBreak => AstNode::from(NodeValue::LineBreak),
                NodeName::Code => {
                    let mut node = NodeCode {
                        num_backticks: 0,
                        literal: "".to_string(),
                    };

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"num_backticks", AttrValue::Usize(ref value)) => {
                                node.num_backticks = *value
                            }
                            (&"literal", AttrValue::Text(ref value)) => {
                                node.literal = value.clone()
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::Code(node))
                }
                NodeName::HtmlInline => {
                    let mut html_inline = NodeValue::HtmlInline("".to_string());

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"raw_html", AttrValue::Text(ref value)) => {
                                html_inline = NodeValue::HtmlInline(value.clone())
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(html_inline)
                }
                NodeName::Emph => AstNode::from(NodeValue::Emph),
                NodeName::Strong => AstNode::from(NodeValue::Strong),
                NodeName::Strikethrough => AstNode::from(NodeValue::Strikethrough),
                NodeName::Link => {
                    AstNode::from(NodeValue::Link(attrs_to_node_link(attrs.to_vec())))
                }
                NodeName::Image => {
                    AstNode::from(NodeValue::Image(attrs_to_node_link(attrs.to_vec())))
                }
                NodeName::ShortCode => {
                    let mut node = NodeShortCode {
                        code: "".to_string(),
                        emoji: "".to_string(),
                    };

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"code", AttrValue::Text(ref value)) => node.code = value.clone(),
                            (&"emoji", AttrValue::Text(ref value)) => node.emoji = value.clone(),
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::ShortCode(node))
                }
                NodeName::Math => {
                    let mut node = NodeMath {
                        dollar_math: false,
                        display_math: false,
                        literal: "".to_string(),
                    };

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"dollar_math", AttrValue::Bool(ref value)) => {
                                node.dollar_math = *value
                            }
                            (&"display_math", AttrValue::Bool(ref value)) => {
                                node.display_math = *value
                            }
                            (&"literal", AttrValue::Text(ref value)) => {
                                node.literal = value.clone()
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::Math(node))
                }
                NodeName::MultilineBlockQuote => {
                    let mut node = NodeMultilineBlockQuote {
                        fence_length: 0,
                        fence_offset: 0,
                    };

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"fence_length", AttrValue::Usize(ref value)) => {
                                node.fence_length = *value
                            }
                            (&"fence_offset", AttrValue::Usize(ref value)) => {
                                node.fence_offset = *value
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::MultilineBlockQuote(node))
                }
                NodeName::Escaped => AstNode::from(NodeValue::Escaped),
                NodeName::WikiLink => {
                    let mut node = NodeWikiLink {
                        url: "".to_string(),
                    };

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"url", AttrValue::Text(ref value)) => node.url = value.clone(),
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(NodeValue::WikiLink(node))
                }
                NodeName::Underline => AstNode::from(NodeValue::Underline),
                NodeName::SpoileredText => AstNode::from(NodeValue::SpoileredText),
                NodeName::EscapedTag => {
                    let mut escaped_tag = NodeValue::EscapedTag("".to_string());

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"tag", AttrValue::Text(ref value)) => {
                                escaped_tag = NodeValue::EscapedTag(value.clone())
                            }
                            // FIXME: warning
                            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
                        }
                    }

                    AstNode::from(escaped_tag)
                }

                // FIXME: error?
                _ => {
                    println!("missing {:?}", name);
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

fn attrs_to_task_item(attrs: Vec<(&str, AttrValue)>) -> Option<char> {
    let mut symbol = None;

    for (key, value) in attrs {
        match (key, value) {
            ("checked", AttrValue::Bool(false)) => return None,
            ("symbol", AttrValue::Text(ref value)) => symbol = value.chars().next(),
            _ => {}
        }
    }

    symbol
}

fn attrs_to_node_link(attrs: Vec<(&str, AttrValue)>) -> NodeLink {
    let mut link = NodeLink {
        url: "".to_string(),
        title: "".to_string(),
    };

    for (key, value) in attrs {
        match (key, value) {
            ("url", AttrValue::Text(ref value)) => link.url = value.clone(),
            ("title", AttrValue::Text(ref value)) => link.title = value.clone(),
            // FIXME: warning
            (attr_name, _) => println!("unknown attr: {:?}", attr_name),
        }
    }

    link
}
