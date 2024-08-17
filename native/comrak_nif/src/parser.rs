use crate::types::nodes::{AttrValue, ExNode};
use comrak::nodes::{
    AstNode, ListDelimType, ListType, NodeLink, NodeList, NodeValue, TableAlignment,
};

pub fn to_elixir_ast<'a>(node: &'a AstNode<'a>) -> ExNode {
    let node_data = node.data.borrow();

    match node_data.value {
        NodeValue::Text(ref text) => ExNode::Text(text.to_string()),
        _ => {
            let (name, attrs) = match node_data.value {
                NodeValue::Document => ("document", vec![]),
                NodeValue::FrontMatter(ref content) => (
                    "front_matter",
                    vec![("content", AttrValue::Text(content.to_owned()))],
                ),
                NodeValue::BlockQuote => ("block_quote", vec![]),
                NodeValue::List(ref attrs) => ("list", node_list_to_ast(attrs)),
                NodeValue::Item(ref attrs) => ("item", node_list_to_ast(attrs)),
                NodeValue::DescriptionList => ("description_list", vec![]),
                NodeValue::DescriptionItem(ref attrs) => (
                    "description_item",
                    vec![
                        ("marker_offset", AttrValue::Usize(attrs.marker_offset)),
                        ("padding", AttrValue::Usize(attrs.padding)),
                    ],
                ),
                NodeValue::DescriptionTerm => ("description_term", vec![]),
                NodeValue::DescriptionDetails => ("description_details", vec![]),
                NodeValue::CodeBlock(ref attrs) => (
                    "code_block",
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
                    "html_block",
                    vec![
                        ("block_type", AttrValue::U8(attrs.block_type)),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ],
                ),
                NodeValue::Paragraph => ("paragraph", vec![]),
                NodeValue::Heading(ref attrs) => (
                    "heading",
                    vec![
                        ("level", AttrValue::U8(attrs.level)),
                        ("setext", AttrValue::Bool(attrs.setext)),
                    ],
                ),
                NodeValue::ThematicBreak => ("thematic_break", vec![]),
                NodeValue::FootnoteDefinition(ref attrs) => (
                    "footnote_definition",
                    vec![
                        ("name", AttrValue::Text(attrs.name.to_owned())),
                        ("total_references", AttrValue::U32(attrs.total_references)),
                    ],
                ),
                NodeValue::FootnoteReference(ref attrs) => (
                    "footnote_reference",
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
                        "table",
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
                NodeValue::TableRow(ref header) => {
                    ("table_row", vec![("header", AttrValue::Bool(*header))])
                }
                NodeValue::TableCell => ("table_cell", vec![]),
                NodeValue::TaskItem(ref symbol) => {
                    let symbol = symbol.unwrap_or(' ');
                    (
                        "task_item",
                        vec![("symbol", AttrValue::Text(symbol.to_string()))],
                    )
                }
                NodeValue::SoftBreak => ("soft_break", vec![]),
                NodeValue::LineBreak => ("line_break", vec![]),
                NodeValue::Code(ref attrs) => (
                    "code",
                    vec![
                        ("num_backticks", AttrValue::Usize(attrs.num_backticks)),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ],
                ),
                NodeValue::HtmlInline(ref raw_html) => (
                    "html_inline",
                    vec![("raw_html", AttrValue::Text(raw_html.to_owned()))],
                ),
                NodeValue::Emph => ("emph", vec![]),
                NodeValue::Strong => ("strong", vec![]),
                NodeValue::Strikethrough => ("strikethrough", vec![]),
                NodeValue::Superscript => ("superscript", vec![]),
                NodeValue::Link(ref attrs) => ("link", node_link_to_ast(attrs)),
                NodeValue::Image(ref attrs) => ("image", node_link_to_ast(attrs)),
                NodeValue::ShortCode(ref attrs) => (
                    "short_code",
                    vec![
                        ("code", AttrValue::Text(attrs.code.to_owned())),
                        ("emoji", AttrValue::Text(attrs.emoji.to_owned())),
                    ],
                ),
                NodeValue::Math(ref attrs) => (
                    "math",
                    vec![
                        ("dollar_math", AttrValue::Bool(attrs.dollar_math)),
                        ("display_math", AttrValue::Bool(attrs.display_math)),
                        ("literal", AttrValue::Text(attrs.literal.to_owned())),
                    ],
                ),
                NodeValue::MultilineBlockQuote(ref attrs) => (
                    "multiline_block_quote",
                    vec![
                        ("fence_length", AttrValue::Usize(attrs.fence_length)),
                        ("fence_offset", AttrValue::Usize(attrs.fence_offset)),
                    ],
                ),
                NodeValue::Escaped => ("escaped", vec![]),
                NodeValue::WikiLink(ref attrs) => (
                    "wiki_link",
                    vec![("url", AttrValue::Text(attrs.url.to_owned()))],
                ),
                NodeValue::Underline => ("underline", vec![]),
                NodeValue::SpoileredText => ("spoilered_text", vec![]),
                NodeValue::EscapedTag(ref tag) => (
                    "escaped_tag",
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
