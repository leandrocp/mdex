use crate::types::{
    atoms::{
        attr_key_not_string, empty, invalid_structure, missing_attr_field, missing_node_field,
        node_name_not_string, unknown_attr_value, unknown_node_name,
    },
    nodes::{AttrValue, ExNode, NodeName},
};
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

#[derive(Debug)]
pub enum DecodeError {
    InvalidStructure {
        found: String,
    },
    Empty {
        found: String,
    },
    MissingNodeField {
        found: String,
    },
    MissingAttrField {
        found: String,
        node: String,
    },
    NodeNameNotString {
        found: String,
        node: String,
        kind: String,
    },
    UnknownNodeName {
        found: String,
        node: String,
    },
    AttrKeyNotString {
        found: String,
        node: String,
        attr: String,
        kind: String,
    },
    UnknownAttrValue {
        found: String,
        node: String,
        attr: String,
        kind: String,
    },
}

impl Encoder for DecodeError {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            DecodeError::InvalidStructure { found } => {
                let reason = invalid_structure().encode(env);
                (reason, found).encode(env)
            }
            DecodeError::Empty { found } => {
                let reason = empty().encode(env);
                (reason, found).encode(env)
            }
            DecodeError::MissingNodeField { found } => {
                let reason = missing_node_field().encode(env);
                (reason, found).encode(env)
            }
            DecodeError::MissingAttrField { found, node } => {
                let reason = missing_attr_field().encode(env);
                (reason, found, node).encode(env)
            }
            DecodeError::NodeNameNotString { found, node, kind } => {
                let reason = node_name_not_string().encode(env);
                (reason, found, node, kind).encode(env)
            }
            DecodeError::UnknownNodeName { found, node } => {
                let reason = unknown_node_name().encode(env);
                (reason, found, node).encode(env)
            }
            DecodeError::AttrKeyNotString {
                found,
                node,
                attr,
                kind,
            } => {
                let reason = attr_key_not_string().encode(env);
                (reason, found, node, attr, kind).encode(env)
            }
            DecodeError::UnknownAttrValue {
                found,
                node,
                attr,
                kind,
            } => {
                let reason = unknown_attr_value().encode(env);
                (reason, found, node, attr, kind).encode(env)
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
        let list: Vec<Term> = term.decode().map_err(|_| DecodeError::InvalidStructure {
            found: format!("{:?}", term),
        })?;

        if list.len() != 1 {
            return Err(DecodeError::Empty {
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

    let node: (Term, Term, Term) = term.decode().map_err(|_| DecodeError::MissingNodeField {
        found: format!("{:?}", term),
    })?;

    let name = node
        .0
        .decode::<Binary>()
        .map_err(|_| DecodeError::NodeNameNotString {
            found: format!("{:?}", node.0),
            node: format!("{:?}", node),
            kind: format!("{:?}", rustler::Term::get_type(node.0)),
        })?;
    let name =
        std::str::from_utf8(name.as_slice()).map_err(|_| DecodeError::NodeNameNotString {
            found: format!("{:?}", node.0),
            node: format!("{:?}", node),
            kind: format!("{:?}", rustler::Term::get_type(node.0)),
        })?;
    let name = NodeName::from_str(name).map_err(|_| DecodeError::UnknownNodeName {
        found: name.to_string(),
        node: format!("{:?}", node),
    })?;

    let attrs: Vec<(Term, Term)> = node.1.decode().map_err(|_| DecodeError::MissingAttrField {
        found: format!("{:?}", node.1),
        node: format!("{:?}", node),
    })?;

    let attrs = attrs
        .into_iter()
        .map(|(key, value)| {
            let key_binary: Binary = key.decode().map_err(|_| DecodeError::AttrKeyNotString {
                found: format!("{:?}", key),
                node: format!("{:?}", node),
                attr: format!("{:?}", (key, value)),
                kind: format!("{:?}", rustler::Term::get_type(key)),
            })?;
            let key = std::str::from_utf8(key_binary.as_slice()).map_err(|_| {
                DecodeError::AttrKeyNotString {
                    found: format!("{:?}", key),
                    node: format!("{:?}", node),
                    attr: format!("{:?}", (key, value)),
                    kind: format!("{:?}", rustler::Term::get_type(key)),
                }
            })?;

            let attr_value: AttrValue =
                value.decode().map_err(|_| DecodeError::UnknownAttrValue {
                    found: format!("{:?}", value),
                    node: format!("{:?}", node),
                    attr: format!("{:?}", (key, value)),
                    kind: format!("{:?}", rustler::Term::get_type(value)),
                })?;

            Ok((key, attr_value))
        })
        .collect::<Result<Vec<_>, Error>>()?;

    let children: Vec<Term> = node.2.decode().map_err(|_| DecodeError::InvalidStructure {
        found: format!("E7 {:?}", node.1),
    })?;

    let children = children
        .into_iter()
        .map(|child_term| decode_node(&child_term))
        .collect::<Result<Vec<_>, Error>>()?;

    Ok(ExNode::Element {
        name,
        attrs,
        children,
    })
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
                            (attr_name, attr_value) => {
                                unknown_attr("front_matter", attr_name, attr_value)
                            }
                        }
                    }

                    AstNode::from(front_matter)
                }
                NodeName::BlockQuote => AstNode::from(NodeValue::BlockQuote),
                NodeName::List => {
                    AstNode::from(NodeValue::List(attrs_to_node_list("list", attrs.to_vec())))
                }
                NodeName::Item => {
                    AstNode::from(NodeValue::Item(attrs_to_node_list("item", attrs.to_vec())))
                }
                NodeName::DescriptionList => AstNode::from(NodeValue::DescriptionList),
                NodeName::DescriptionItem => {
                    let mut node = NodeDescriptionItem::default();

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"marker_offset", AttrValue::Usize(ref value)) => {
                                node.marker_offset = *value
                            }
                            (&"marker_offset", AttrValue::U8(ref value)) => {
                                node.marker_offset = *value as usize
                            }
                            (&"padding", AttrValue::Usize(ref value)) => node.padding = *value,
                            (&"padding", AttrValue::U8(ref value)) => {
                                node.padding = *value as usize
                            }
                            (attr_name, attr_value) => {
                                unknown_attr("description_item", attr_name, attr_value)
                            }
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
                            (&"fence_length", AttrValue::U8(ref value)) => {
                                node.fence_length = *value as usize
                            }
                            (&"fence_offset", AttrValue::Usize(ref value)) => {
                                node.fence_offset = *value
                            }
                            (&"fence_offset", AttrValue::U8(ref value)) => {
                                node.fence_offset = *value as usize
                            }
                            (&"info", AttrValue::Text(ref value)) => node.info = value.clone(),
                            (&"literal", AttrValue::Text(ref value)) => {
                                node.literal = value.clone()
                            }
                            (attr_name, attr_value) => {
                                unknown_attr("code_block", attr_name, attr_value)
                            }
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
                            (attr_name, att_value) => {
                                unknown_attr("html_block", attr_name, att_value)
                            }
                        }
                    }

                    AstNode::from(NodeValue::HtmlBlock(node))
                }
                NodeName::Paragraph => AstNode::from(NodeValue::Paragraph),
                NodeName::Heading => {
                    let mut node = NodeHeading {
                        level: 1,
                        setext: false,
                    };

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"level", AttrValue::U8(ref value)) => node.level = *value,
                            (&"setext", AttrValue::Bool(ref value)) => node.setext = *value,
                            (attr_name, attr_value) => {
                                unknown_attr("heading", attr_name, attr_value)
                            }
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
                            (&"total_references", AttrValue::U8(ref value)) => {
                                node.total_references = *value as u32
                            }
                            (attr_name, attr_value) => {
                                unknown_attr("footnote_definition", attr_name, attr_value)
                            }
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
                            (&"ref_num", AttrValue::U8(ref value)) => node.ref_num = *value as u32,
                            (&"ix", AttrValue::U32(ref value)) => node.ix = *value,
                            (&"ix", AttrValue::U8(ref value)) => node.ix = *value as u32,
                            (attr_name, attr_value) => {
                                unknown_attr("footnote_reference", attr_name, attr_value)
                            }
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
                            (&"num_columns", AttrValue::U8(ref value)) => {
                                node.num_columns = *value as usize
                            }
                            (&"num_rows", AttrValue::Usize(ref value)) => node.num_rows = *value,
                            (&"num_rows", AttrValue::U8(ref value)) => {
                                node.num_rows = *value as usize
                            }
                            (&"num_nonempty_cells", AttrValue::Usize(ref value)) => {
                                node.num_nonempty_cells = *value
                            }
                            (&"num_nonempty_cells", AttrValue::U8(ref value)) => {
                                node.num_nonempty_cells = *value as usize
                            }
                            (attr_name, attr_value) => unknown_attr("table", attr_name, attr_value),
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
                            (attr_name, attr_value) => {
                                unknown_attr("table_row", attr_name, attr_value)
                            }
                        }
                    }

                    AstNode::from(table_row)
                }
                NodeName::TableCell => AstNode::from(NodeValue::TableCell),
                NodeName::TaskItem => AstNode::from(NodeValue::TaskItem(attrs_to_task_item(
                    "task_item",
                    attrs.to_vec(),
                ))),
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
                            (&"num_backticks", AttrValue::U8(ref value)) => {
                                node.num_backticks = *value as usize
                            }
                            (&"literal", AttrValue::Text(ref value)) => {
                                node.literal = value.clone()
                            }
                            (attr_name, attr_value) => unknown_attr("code", attr_name, attr_value),
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
                            (attr_name, attr_value) => {
                                unknown_attr("html_inline", attr_name, attr_value)
                            }
                        }
                    }

                    AstNode::from(html_inline)
                }
                NodeName::Emph => AstNode::from(NodeValue::Emph),
                NodeName::Strong => AstNode::from(NodeValue::Strong),
                NodeName::Strikethrough => AstNode::from(NodeValue::Strikethrough),
                NodeName::Superscript => AstNode::from(NodeValue::Superscript),
                NodeName::Link => {
                    AstNode::from(NodeValue::Link(attrs_to_node_link("link", attrs.to_vec())))
                }
                NodeName::Image => AstNode::from(NodeValue::Image(attrs_to_node_link(
                    "image",
                    attrs.to_vec(),
                ))),
                NodeName::ShortCode => {
                    let mut node = NodeShortCode {
                        code: "".to_string(),
                        emoji: "".to_string(),
                    };

                    for (key, value) in attrs {
                        match (key, value) {
                            (&"code", AttrValue::Text(ref value)) => node.code = value.clone(),
                            (&"emoji", AttrValue::Text(ref value)) => node.emoji = value.clone(),
                            (attr_name, attr_value) => {
                                unknown_attr("short_code", attr_name, attr_value)
                            }
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
                            (attr_name, attr_value) => unknown_attr("math", attr_name, attr_value),
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
                            (&"fence_length", AttrValue::U8(ref value)) => {
                                node.fence_length = *value as usize
                            }
                            (&"fence_offset", AttrValue::Usize(ref value)) => {
                                node.fence_offset = *value
                            }
                            (&"fence_offset", AttrValue::U8(ref value)) => {
                                node.fence_offset = *value as usize
                            }
                            (attr_name, attr_value) => {
                                unknown_attr("multiline_block_quote", attr_name, attr_value)
                            }
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
                            (attr_name, attr_value) => {
                                unknown_attr("wiki_link", attr_name, attr_value)
                            }
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
                            (attr_name, attr_value) => {
                                unknown_attr("escaped_tag", attr_name, attr_value)
                            }
                        }
                    }

                    AstNode::from(escaped_tag)
                }
            };

            let node = arena.alloc(node_value);

            for child in children {
                let child_node = ex_node_to_comrak_ast(arena, child);
                node.append(child_node);
            }

            node
        }
        ExNode::Text(content) => {
            let text = AstNode::from(NodeValue::Text(content.clone()));
            arena.alloc(text)
        }
    }
}

fn string_to_char(s: String) -> u8 {
    if s.is_empty() {
        return 0;
    }

    s.chars().next().unwrap_or(' ') as u8
}

fn unknown_attr(node_name: &str, attr_name: &str, attr_value: &AttrValue) {
    log::warn!(
        "unknown attribute {} on node {} with value {:?}",
        attr_name,
        node_name,
        attr_value
    );
}

fn attrs_to_node_list(node_name: &str, attrs: Vec<(&str, AttrValue)>) -> NodeList {
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
            ("marker_offset", AttrValue::U8(ref value)) => list.marker_offset = *value as usize,
            ("padding", AttrValue::Usize(ref value)) => list.padding = *value,
            ("padding", AttrValue::U8(ref value)) => list.padding = *value as usize,
            ("start", AttrValue::Usize(ref value)) => list.start = *value,
            ("start", AttrValue::U8(ref value)) => list.start = *value as usize,
            ("delimiter", AttrValue::Text(ref value)) => {
                list.delimiter = to_delim_type(value.as_str())
            }
            ("bullet_char", AttrValue::Text(ref value)) => {
                list.bullet_char = string_to_char(value.clone())
            }
            ("tight", AttrValue::Bool(ref value)) => list.tight = *value,
            (attr_name, attr_value) => unknown_attr(node_name, attr_name, &attr_value),
        }
    }

    list
}

fn attrs_to_task_item(node_name: &str, attrs: Vec<(&str, AttrValue)>) -> Option<char> {
    let mut symbol = None;

    for (key, value) in attrs {
        match (key, value) {
            ("checked", AttrValue::Bool(false)) => return None,
            ("symbol", AttrValue::Text(ref value)) => symbol = value.chars().next(),
            (attr_name, attr_value) => unknown_attr(node_name, attr_name, &attr_value),
        }
    }

    symbol
}

fn attrs_to_node_link(node_name: &str, attrs: Vec<(&str, AttrValue)>) -> NodeLink {
    let mut link = NodeLink {
        url: "".to_string(),
        title: "".to_string(),
    };

    for (key, value) in attrs {
        match (key, value) {
            ("url", AttrValue::Text(ref value)) => link.url = value.clone(),
            ("title", AttrValue::Text(ref value)) => link.title = value.clone(),
            (attr_name, attr_value) => unknown_attr(node_name, attr_name, &attr_value),
        }
    }

    link
}
