use crate::types::nodes::{AttrValue, ExNode, NodeName};
use comrak::nodes::{
    AstNode, ListDelimType, ListType, NodeLink, NodeList, NodeValue, TableAlignment,
};
use rustler::{Encoder, Env, Term};

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
            } => {
                let mut attr_list = Vec::new();

                for (key, value) in attrs {
                    let attr_value = match value {
                        AttrValue::U8(v) => (key, v.encode(env)),
                        AttrValue::U32(v) => (key, v.encode(env)),
                        AttrValue::Usize(v) => (key, v.encode(env)),
                        AttrValue::Bool(v) => (key, v.encode(env)),
                        AttrValue::Text(v) => (key, v.encode(env)),
                        AttrValue::List(v) => (key, v.encode(env)),
                    };

                    attr_list.push(attr_value);
                }

                (name, attr_list, children).encode(env)
            }
        }
    }
}

pub fn to_elixir_ast<'a>(node: &'a AstNode<'a>) -> ExNode {
    let node_data = node.data.borrow();

    match node_data.value {
        NodeValue::Text(ref text) => ExNode::Text(text.to_string()),
        _ => {
            let (name, attrs) = match node_data.value {
                NodeValue::Document => (NodeName::Document, vec![]),
                NodeValue::FrontMatter(ref content) => (
                    NodeName::FrontMatter,
                    vec![("content", AttrValue::Text(content.to_owned()))],
                ),
                NodeValue::BlockQuote => (NodeName::BlockQuote, vec![]),
                NodeValue::List(ref attrs) => (NodeName::List, node_list_to_ast(attrs)),
                NodeValue::Item(ref attrs) => (NodeName::Item, node_list_to_ast(attrs)),
                NodeValue::DescriptionList => (NodeName::DescriptionList, vec![]),
                NodeValue::DescriptionItem(ref attrs) => (
                    NodeName::DescriptionItem,
                    vec![
                        ("marker_offset", AttrValue::Usize(attrs.marker_offset)),
                        ("padding", AttrValue::Usize(attrs.padding)),
                    ],
                ),
                NodeValue::DescriptionTerm => (NodeName::DescriptionTerm, vec![]),
                NodeValue::DescriptionDetails => (NodeName::DescriptionDetails, vec![]),
                NodeValue::CodeBlock(ref attrs) => (
                    NodeName::CodeBlock,
                    vec![
                        ("fenced", AttrValue::Bool(attrs.fenced)),
                        (
                            "fence_char",
                            AttrValue::Text(char_to_string(attrs.fence_char).unwrap_or_default()),
                        ),
                        ("fence_length", AttrValue::Usize(attrs.fence_length)),
                        ("fence_offset", AttrValue::Usize(attrs.fence_offset)),
                        ("info", AttrValue::Text(attrs.info.to_owned())),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ],
                ),
                NodeValue::HtmlBlock(ref attrs) => (
                    NodeName::HtmlBlock,
                    vec![
                        ("block_type", AttrValue::U8(attrs.block_type)),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ],
                ),
                NodeValue::Paragraph => (NodeName::Paragraph, vec![]),
                NodeValue::Heading(ref attrs) => (
                    NodeName::Heading,
                    vec![
                        ("level", AttrValue::U8(attrs.level)),
                        ("setext", AttrValue::Bool(attrs.setext)),
                    ],
                ),
                NodeValue::ThematicBreak => (NodeName::ThematicBreak, vec![]),
                NodeValue::FootnoteDefinition(ref attrs) => (
                    NodeName::FootnoteDefinition,
                    vec![
                        ("name", AttrValue::Text(attrs.name.to_owned())),
                        ("total_references", AttrValue::U32(attrs.total_references)),
                    ],
                ),
                NodeValue::FootnoteReference(ref attrs) => (
                    NodeName::FootnoteReference,
                    vec![
                        ("name", AttrValue::Text(attrs.name.to_owned())),
                        ("ref_num", AttrValue::U32(attrs.ref_num)),
                        ("ix", AttrValue::U32(attrs.ix)),
                    ],
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
                        vec![
                            ("alignments", AttrValue::List(alignments)),
                            ("num_columns", AttrValue::Usize(attrs.num_columns)),
                            ("num_rows", AttrValue::Usize(attrs.num_rows)),
                            (
                                "num_nonempty_cells",
                                AttrValue::Usize(attrs.num_nonempty_cells),
                            ),
                        ],
                    )
                }
                NodeValue::TableRow(ref header) => (
                    NodeName::TableRow,
                    vec![("header", AttrValue::Bool(*header))],
                ),
                NodeValue::TableCell => (NodeName::TableCell, vec![]),
                NodeValue::TaskItem(ref symbol) => (
                    NodeName::TaskItem,
                    match symbol {
                        Some(symbol) => vec![
                            ("checked", AttrValue::Bool(true)),
                            ("symbol", AttrValue::Text(symbol.to_string())),
                        ],
                        None => vec![("checked", AttrValue::Bool(false))],
                    },
                ),
                NodeValue::SoftBreak => (NodeName::SoftBreak, vec![]),
                NodeValue::LineBreak => (NodeName::LineBreak, vec![]),
                NodeValue::Code(ref attrs) => (
                    NodeName::Code,
                    vec![
                        ("num_backticks", AttrValue::Usize(attrs.num_backticks)),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ],
                ),
                NodeValue::HtmlInline(ref raw_html) => (
                    NodeName::HtmlInline,
                    vec![("raw_html", AttrValue::Text(raw_html.to_owned()))],
                ),
                NodeValue::Emph => (NodeName::Emph, vec![]),
                NodeValue::Strong => (NodeName::Strong, vec![]),
                NodeValue::Strikethrough => (NodeName::Strikethrough, vec![]),
                NodeValue::Superscript => (NodeName::Superscript, vec![]),
                NodeValue::Link(ref attrs) => (NodeName::Link, node_link_to_ast(attrs)),
                NodeValue::Image(ref attrs) => (NodeName::Image, node_link_to_ast(attrs)),
                NodeValue::ShortCode(ref attrs) => (
                    NodeName::ShortCode,
                    vec![
                        ("code", AttrValue::Text(attrs.code.to_owned())),
                        ("emoji", AttrValue::Text(attrs.emoji.to_owned())),
                    ],
                ),
                NodeValue::Math(ref attrs) => (
                    NodeName::Math,
                    vec![
                        ("dollar_math", AttrValue::Bool(attrs.dollar_math)),
                        ("display_math", AttrValue::Bool(attrs.display_math)),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ],
                ),
                NodeValue::MultilineBlockQuote(ref attrs) => (
                    NodeName::MultilineBlockQuote,
                    vec![
                        ("fence_length", AttrValue::Usize(attrs.fence_length)),
                        ("fence_offset", AttrValue::Usize(attrs.fence_offset)),
                    ],
                ),
                NodeValue::Escaped => (NodeName::Escaped, vec![]),
                NodeValue::WikiLink(ref attrs) => (
                    NodeName::WikiLink,
                    vec![("url", AttrValue::Text(attrs.url.to_owned()))],
                ),
                NodeValue::Underline => (NodeName::Underline, vec![]),
                NodeValue::SpoileredText => (NodeName::SpoileredText, vec![]),
                NodeValue::EscapedTag(ref tag) => (
                    NodeName::EscapedTag,
                    vec![("tag", AttrValue::Text(tag.to_owned()))],
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

fn node_list_to_ast<'a>(list: &NodeList) -> Vec<(&'a str, AttrValue)> {
    let list_type = match list.list_type {
        ListType::Bullet => "bullet",
        ListType::Ordered => "ordered",
    };

    let delimiter = match list.delimiter {
        ListDelimType::Period => "period",
        ListDelimType::Paren => "paren",
    };

    vec![
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
    ]
}

fn node_link_to_ast<'a>(link: &NodeLink) -> Vec<(&'a str, AttrValue)> {
    vec![
        ("url", AttrValue::Text(link.url.to_owned())),
        ("title", AttrValue::Text(link.title.to_owned())),
    ]
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
