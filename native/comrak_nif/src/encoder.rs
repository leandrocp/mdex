use crate::types::nodes::{AttrValue, ExNode, NodeName};
use comrak::nodes::{
    AstNode, ListDelimType, ListType, NodeLink, NodeList, NodeValue, TableAlignment,
};
use rustler::{Encoder, Env, Term};
use std::collections::HashMap;

impl Encoder for NodeName {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            Self::Document => "document",
            Self::FrontMatter => "front_matter",
            Self::BlockQuote => "block_quote",
            Self::List => "list",
            Self::Item => "item",
            Self::DescriptionList => "description_list",
            Self::DescriptionItem => "description_item",
            Self::DescriptionTerm => "description_term",
            Self::DescriptionDetails => "description_details",
            Self::CodeBlock => "code_block",
            Self::HtmlBlock => "html_block",
            Self::Paragraph => "paragraph",
            Self::Heading => "heading",
            Self::ThematicBreak => "thematic_break",
            Self::FootnoteDefinition => "footnote_definition",
            Self::Table => "table",
            Self::TableRow => "table_row",
            Self::TableCell => "table_cell",
            Self::TaskItem => "task_item",
            Self::SoftBreak => "soft_break",
            Self::LineBreak => "line_break",
            Self::Code => "code",
            Self::HtmlInline => "html_inline",
            Self::Emph => "emph",
            Self::Strong => "strong",
            Self::Strikethrough => "strikethrough",
            Self::Superscript => "superscript",
            Self::Link => "link",
            Self::Image => "image",
            Self::FootnoteReference => "footnote_reference",
            Self::ShortCode => "short_code",
            Self::Math => "math",
            Self::MultilineBlockQuote => "multiline_block_quote",
            Self::Escaped => "escaped",
            Self::WikiLink => "wiki_link",
            Self::Underline => "underline",
            Self::SpoileredText => "spoilered_text",
            Self::EscapedTag => "escaped_tag",
        }
        .encode(env)
    }
}

impl<'a> Encoder for ExNode<'a> {
    fn encode<'b>(&self, env: Env<'b>) -> Term<'b> {
        match self {
            Self::Text(text) => text.encode(env),

            Self::Element {
                name,
                attrs,
                children,
            } => (name, attrs, children).encode(env),
        }
    }
}

pub fn to_elixir_ast<'a>(node: &'a AstNode<'a>) -> ExNode {
    let node_data = node.data.borrow();

    match node_data.value {
        NodeValue::Text(ref text) => ExNode::Text(text.to_string()),
        _ => {
            let (name, attrs) = match node_data.value {
                NodeValue::Document => (NodeName::Document, HashMap::new()),
                NodeValue::FrontMatter(ref content) => (
                    NodeName::FrontMatter,
                    HashMap::from_iter(vec![("content", AttrValue::Text(content.to_owned()))]),
                ),
                NodeValue::BlockQuote => (NodeName::BlockQuote, HashMap::new()),
                NodeValue::List(ref attrs) => (NodeName::List, node_list_to_ast(attrs)),
                NodeValue::Item(ref attrs) => (NodeName::Item, node_list_to_ast(attrs)),
                NodeValue::DescriptionList => (NodeName::DescriptionList, HashMap::new()),
                NodeValue::DescriptionItem(ref attrs) => (
                    NodeName::DescriptionItem,
                    HashMap::from_iter(vec![
                        ("marker_offset", AttrValue::Usize(attrs.marker_offset)),
                        ("padding", AttrValue::Usize(attrs.padding)),
                    ]),
                ),
                NodeValue::DescriptionTerm => (NodeName::DescriptionTerm, HashMap::new()),
                NodeValue::DescriptionDetails => (NodeName::DescriptionDetails, HashMap::new()),
                NodeValue::CodeBlock(ref attrs) => (
                    NodeName::CodeBlock,
                    HashMap::from_iter(vec![
                        ("fenced", AttrValue::Bool(attrs.fenced)),
                        (
                            "fence_char",
                            AttrValue::Text(char_to_string(attrs.fence_char).unwrap_or_default()),
                        ),
                        ("fence_length", AttrValue::Usize(attrs.fence_length)),
                        ("fence_offset", AttrValue::Usize(attrs.fence_offset)),
                        ("info", AttrValue::Text(attrs.info.to_owned())),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ]),
                ),
                NodeValue::HtmlBlock(ref attrs) => (
                    NodeName::HtmlBlock,
                    HashMap::from_iter(vec![
                        ("block_type", AttrValue::U8(attrs.block_type)),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ]),
                ),
                NodeValue::Paragraph => (NodeName::Paragraph, HashMap::new()),
                NodeValue::Heading(ref attrs) => (
                    NodeName::Heading,
                    HashMap::from_iter(vec![
                        ("level", AttrValue::U8(attrs.level)),
                        ("setext", AttrValue::Bool(attrs.setext)),
                    ]),
                ),
                NodeValue::ThematicBreak => (NodeName::ThematicBreak, HashMap::new()),
                NodeValue::FootnoteDefinition(ref attrs) => (
                    NodeName::FootnoteDefinition,
                    HashMap::from_iter(vec![
                        ("name", AttrValue::Text(attrs.name.to_owned())),
                        ("total_references", AttrValue::U32(attrs.total_references)),
                    ]),
                ),
                NodeValue::FootnoteReference(ref attrs) => (
                    NodeName::FootnoteReference,
                    HashMap::from_iter(vec![
                        ("name", AttrValue::Text(attrs.name.to_owned())),
                        ("ref_num", AttrValue::U32(attrs.ref_num)),
                        ("ix", AttrValue::U32(attrs.ix)),
                    ]),
                ),
                NodeValue::Table(ref attrs) => {
                    let alignments = attrs
                        .alignments
                        .iter()
                        .map(|ta| match ta {
                            TableAlignment::None => "none".to_string(),
                            TableAlignment::Left => "left".to_string(),
                            TableAlignment::Center => "center".to_string(),
                            TableAlignment::Right => "right".to_string(),
                        })
                        .collect::<Vec<String>>();

                    (
                        NodeName::Table,
                        HashMap::from_iter(vec![
                            ("alignments", AttrValue::List(alignments)),
                            ("num_columns", AttrValue::Usize(attrs.num_columns)),
                            ("num_rows", AttrValue::Usize(attrs.num_rows)),
                            (
                                "num_nonempty_cells",
                                AttrValue::Usize(attrs.num_nonempty_cells),
                            ),
                        ]),
                    )
                }
                NodeValue::TableRow(ref header) => (
                    NodeName::TableRow,
                    HashMap::from_iter(vec![("header", AttrValue::Bool(*header))]),
                ),
                NodeValue::TableCell => (NodeName::TableCell, HashMap::new()),
                NodeValue::TaskItem(ref symbol) => (
                    NodeName::TaskItem,
                    match symbol {
                        Some(symbol) => HashMap::from_iter(vec![
                            ("checked", AttrValue::Bool(true)),
                            ("symbol", AttrValue::Text(symbol.to_string())),
                        ]),
                        None => HashMap::from_iter(vec![("checked", AttrValue::Bool(false))]),
                    },
                ),
                NodeValue::SoftBreak => (NodeName::SoftBreak, HashMap::new()),
                NodeValue::LineBreak => (NodeName::LineBreak, HashMap::new()),
                NodeValue::Code(ref attrs) => (
                    NodeName::Code,
                    HashMap::from_iter(vec![
                        ("num_backticks", AttrValue::Usize(attrs.num_backticks)),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ]),
                ),
                NodeValue::HtmlInline(ref raw_html) => (
                    NodeName::HtmlInline,
                    HashMap::from_iter(vec![("raw_html", AttrValue::Text(raw_html.to_owned()))]),
                ),
                NodeValue::Emph => (NodeName::Emph, HashMap::new()),
                NodeValue::Strong => (NodeName::Strong, HashMap::new()),
                NodeValue::Strikethrough => (NodeName::Strikethrough, HashMap::new()),
                NodeValue::Superscript => (NodeName::Superscript, HashMap::new()),
                NodeValue::Link(ref attrs) => (NodeName::Link, node_link_to_ast(attrs)),
                NodeValue::Image(ref attrs) => (NodeName::Image, node_link_to_ast(attrs)),
                NodeValue::ShortCode(ref attrs) => (
                    NodeName::ShortCode,
                    HashMap::from_iter(vec![
                        ("code", AttrValue::Text(attrs.code.to_owned())),
                        ("emoji", AttrValue::Text(attrs.emoji.to_owned())),
                    ]),
                ),
                NodeValue::Math(ref attrs) => (
                    NodeName::Math,
                    HashMap::from_iter(vec![
                        ("dollar_math", AttrValue::Bool(attrs.dollar_math)),
                        ("display_math", AttrValue::Bool(attrs.display_math)),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ]),
                ),
                NodeValue::MultilineBlockQuote(ref attrs) => (
                    NodeName::MultilineBlockQuote,
                    HashMap::from_iter(vec![
                        ("fence_length", AttrValue::Usize(attrs.fence_length)),
                        ("fence_offset", AttrValue::Usize(attrs.fence_offset)),
                    ]),
                ),
                NodeValue::Escaped => (NodeName::Escaped, HashMap::new()),
                NodeValue::WikiLink(ref attrs) => (
                    NodeName::WikiLink,
                    HashMap::from_iter(vec![("url", AttrValue::Text(attrs.url.to_owned()))]),
                ),
                NodeValue::Underline => (NodeName::Underline, HashMap::new()),
                NodeValue::SpoileredText => (NodeName::SpoileredText, HashMap::new()),
                NodeValue::EscapedTag(ref tag) => (
                    NodeName::EscapedTag,
                    HashMap::from_iter(vec![("tag", AttrValue::Text(tag.to_owned()))]),
                ),
                NodeValue::Text(_) => unreachable!(),
            };

            let children = node.children().map(to_elixir_ast).collect();

            ExNode::Element {
                name,
                attrs,
                children,
            }
        }
    }
}

fn node_list_to_ast<'a>(list: &NodeList) -> HashMap<&'a str, AttrValue> {
    let list_type = match list.list_type {
        ListType::Bullet => "bullet",
        ListType::Ordered => "ordered",
    };

    let delimiter = match list.delimiter {
        ListDelimType::Period => "period",
        ListDelimType::Paren => "paren",
    };

    HashMap::from_iter(vec![
        ("list_type", AttrValue::Text(list_type.to_owned())),
        ("marker_offset", AttrValue::Usize(list.marker_offset)),
        ("padding", AttrValue::Usize(list.padding)),
        ("start", AttrValue::Usize(list.start)),
        ("delimiter", AttrValue::Text(delimiter.to_owned())),
        (
            "bullet_char",
            AttrValue::Text(char_to_string(list.bullet_char).unwrap_or_default()),
        ),
        ("tight", AttrValue::Bool(list.tight)),
    ])
}

fn node_link_to_ast<'a>(link: &NodeLink) -> HashMap<&'a str, AttrValue> {
    HashMap::from_iter(vec![
        ("url", AttrValue::Text(link.url.to_owned())),
        ("title", AttrValue::Text(link.title.to_owned())),
    ])
}

fn char_to_string(c: u8) -> Result<String, &'static str> {
    if c == 0 {
        return Ok("".to_string());
    }

    match String::from_utf8(vec![c]) {
        Ok(s) => Ok(s),
        Err(_) => Err("failed to convert to string"),
    }
}
