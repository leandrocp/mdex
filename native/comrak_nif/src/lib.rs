#![allow(dead_code)]
#![allow(unused_variables)]

#[macro_use]
extern crate rustler;

mod inkjet_adapter;
mod types;

use ammonia::clean;
use comrak::nodes::{
    AstNode, ListDelimType, ListType, NodeLink, NodeList, NodeValue, TableAlignment,
};
use comrak::{markdown_to_html_with_plugins, Arena, ComrakPlugins, Options};
use comrak::{ExtensionOptions, ListStyleType, ParseOptions, RenderOptions};
use inkjet_adapter::InkjetAdapter;
use rustler::{Encoder, Env, NifResult, NifUntaggedEnum, Term};
use types::options::*;

rustler::init!(
    "Elixir.MDEx.Native",
    [
        parse_document,
        markdown_to_html,
        markdown_to_html_with_options,
        tree_to_html,
        tree_to_html_with_options
    ]
);

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_html<'a>(env: Env<'a>, md: &str) -> String {
    let inkjet_adapter = InkjetAdapter::default();
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);
    markdown_to_html_with_plugins(md, &Options::default(), &plugins)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_html_with_options<'a>(
    env: Env<'a>,
    md: &str,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    let comrak_options = comrak::Options {
        extension: extension_options_from_ex_options(&options),
        parse: parse_options_from_ex_options(&options),
        render: render_options_from_ex_options(&options),
    };
    match &options.features.syntax_highlight_theme {
        Some(theme) => {
            let inkjet_adapter = InkjetAdapter::new(
                theme,
                options
                    .features
                    .syntax_highlight_inline_style
                    .unwrap_or(true),
            );
            let mut plugins = ComrakPlugins::default();
            plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);
            let unsafe_html = markdown_to_html_with_plugins(md, &comrak_options, &plugins);
            render(env, unsafe_html, options.features.sanitize)
        }
        None => {
            let unsafe_html = comrak::markdown_to_html(md, &comrak_options);
            render(env, unsafe_html, options.features.sanitize)
        }
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn tree_to_html<'a>(env: Env<'a>, tree: Term<'a>) -> NifResult<Term<'a>> {
    println!("tree: {:?}", tree);
    // // FIXME: validate tree[0] is a document
    // let node = tree.first().unwrap();

    // // println!("tree_to_html: {:?}", node);

    // node.format_document(&Options::default())

    todo!()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn tree_to_html_with_options<'a>(
    env: Env<'a>,
    tree: Term<'a>,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    println!("tree: {:?}", tree);

    //     // FIXME: syntax highlighting option
    //     let comrak_options = comrak::Options {
    //         extension: extension_options_from_ex_options(&options),
    //         parse: parse_options_from_ex_options(&options),
    //         render: render_options_from_ex_options(&options),
    //     };
    //     // FIXME: validate tree[0] is a document
    //     let node = tree.first().unwrap();

    //     // println!("tree_to_html_with_options: {:?}", node);

    //     node.format_document(&comrak_options)

    todo!()
}

fn extension_options_from_ex_options(options: &ExOptions) -> ExtensionOptions {
    let mut extension_options = ExtensionOptions::default();

    extension_options.strikethrough = options.extension.strikethrough;
    extension_options.tagfilter = options.extension.tagfilter;
    extension_options.table = options.extension.table;
    extension_options.autolink = options.extension.autolink;
    extension_options.tasklist = options.extension.tasklist;
    extension_options.superscript = options.extension.superscript;
    extension_options
        .header_ids
        .clone_from(&options.extension.header_ids);
    extension_options.footnotes = options.extension.footnotes;
    extension_options.description_lists = options.extension.description_lists;
    extension_options
        .front_matter_delimiter
        .clone_from(&options.extension.front_matter_delimiter);
    extension_options.multiline_block_quotes = options.extension.multiline_block_quotes;
    extension_options.math_dollars = options.extension.math_dollars;
    extension_options.math_code = options.extension.math_code;
    extension_options.shortcodes = options.extension.shortcodes;
    extension_options.wikilinks_title_after_pipe = options.extension.wikilinks_title_after_pipe;
    extension_options.wikilinks_title_before_pipe = options.extension.wikilinks_title_before_pipe;
    extension_options.underline = options.extension.underline;
    extension_options.spoiler = options.extension.spoiler;
    extension_options.greentext = options.extension.greentext;

    extension_options
}

fn parse_options_from_ex_options(options: &ExOptions) -> ParseOptions {
    let mut parse_options = ParseOptions::default();

    parse_options.smart = options.parse.smart;
    parse_options
        .default_info_string
        .clone_from(&options.parse.default_info_string);
    parse_options.relaxed_tasklist_matching = options.parse.relaxed_tasklist_matching;
    parse_options.relaxed_autolinks = options.parse.relaxed_autolinks;

    parse_options
}

fn render_options_from_ex_options(options: &ExOptions) -> RenderOptions {
    let mut render_options = RenderOptions::default();

    render_options.hardbreaks = options.render.hardbreaks;
    render_options.github_pre_lang = options.render.github_pre_lang;
    render_options.full_info_string = options.render.full_info_string;
    render_options.width = options.render.width;
    render_options.unsafe_ = options.render.unsafe_;
    render_options.escape = options.render.escape;
    render_options.list_style = ListStyleType::from(options.render.list_style.clone());
    render_options.sourcepos = options.render.sourcepos;
    render_options.experimental_inline_sourcepos = options.render.experimental_inline_sourcepos;
    render_options.escaped_char_spans = options.render.escaped_char_spans;
    render_options.ignore_setext = options.render.ignore_setext;
    render_options.ignore_empty_links = options.render.ignore_empty_links;
    render_options.gfm_quirks = options.render.gfm_quirks;
    render_options.prefer_fenced = options.render.prefer_fenced;

    render_options
}

fn render(env: Env, unsafe_html: String, sanitize: bool) -> NifResult<Term> {
    let html = match sanitize {
        true => clean(&unsafe_html),
        false => unsafe_html,
    };

    rustler::serde::to_term(env, html).map_err(|err| err.into())
}

#[derive(Debug, Clone, PartialEq, NifUntaggedEnum)]
enum AttrValue {
    U8(u8),
    U32(u32),
    Usize(usize),
    Bool(bool),
    Text(String),
    List(Vec<String>),
}

#[derive(Debug, Clone, PartialEq)]
enum ExNode<'a> {
    Element {
        name: &'a str,
        attrs: Vec<(&'a str, AttrValue)>,
        children: Vec<ExNode<'a>>,
    },
    Text(String),
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

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_document<'a>(env: Env<'a>, md: &str, options: ExOptions) -> NifResult<Term<'a>> {
    let comrak_options = comrak::Options {
        extension: extension_options_from_ex_options(&options),
        parse: parse_options_from_ex_options(&options),
        render: render_options_from_ex_options(&options),
    };
    let arena = Arena::new();
    let root = comrak::parse_document(&arena, md, &comrak_options);
    let ex_ast = to_elixir_ast(root);
    Ok(vec![ex_ast].encode(env))
}

fn to_elixir_ast<'a>(node: &'a AstNode<'a>) -> ExNode {
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
