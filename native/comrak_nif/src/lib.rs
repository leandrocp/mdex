#![allow(dead_code)]
#![allow(unused_variables)]

#[macro_use]
extern crate rustler;

mod inkjet_adapter;
mod types;

use std::cell::RefCell;

use ammonia::clean;
use comrak::{
    markdown_to_html, markdown_to_html_with_plugins,
    nodes::{Ast, AstNode, LineColumn, NodeHeading, NodeValue},
    Arena, ComrakPlugins, ExtensionOptions, ListStyleType, Options, ParseOptions, RenderOptions,
};
use inkjet_adapter::InkjetAdapter;
use rustler::{Env, NifResult, Term};
use serde::{Deserialize, Serialize};
use types::options::*;

rustler::init!(
    "Elixir.MDEx.Native",
    [parse_document, to_html, to_html_with_options]
);

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html(md: &str) -> String {
    let inkjet_adapter = InkjetAdapter::new("onedark");
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);
    markdown_to_html_with_plugins(md, &Options::default(), &plugins)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html_with_options<'a>(env: Env<'a>, md: &str, options: ExOptions) -> NifResult<Term<'a>> {
    let comrak_options = comrak::Options {
        extension: extension_options_from_ex_options(&options),
        parse: parse_options_from_ex_options(&options),
        render: render_options_from_ex_options(&options),
    };
    match options.features.syntax_highlight_theme {
        Some(theme) => {
            let inkjet_adapter = InkjetAdapter::new(&theme);
            let mut plugins = ComrakPlugins::default();
            plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);
            let unsafe_html = markdown_to_html_with_plugins(md, &comrak_options, &plugins);
            render(env, unsafe_html, options.features.sanitize)
        }
        None => {
            let unsafe_html = markdown_to_html(md, &comrak_options);
            render(env, unsafe_html, options.features.sanitize)
        }
    }
}

fn extension_options_from_ex_options(options: &ExOptions) -> ExtensionOptions {
    let mut extension_options = ExtensionOptions::default();

    extension_options.strikethrough = options.extension.strikethrough;
    extension_options.tagfilter = options.extension.tagfilter;
    extension_options.table = options.extension.table;
    extension_options.autolink = options.extension.autolink;
    extension_options.tasklist = options.extension.tasklist;
    extension_options.superscript = options.extension.superscript;
    extension_options.header_ids = options.extension.header_ids.clone();
    extension_options.footnotes = options.extension.footnotes;
    extension_options.description_lists = options.extension.description_lists;
    extension_options.front_matter_delimiter = options.extension.front_matter_delimiter.clone();

    extension_options
}

fn parse_options_from_ex_options(options: &ExOptions) -> ParseOptions {
    let mut parse_options = ParseOptions::default();

    parse_options.smart = options.parse.smart;
    parse_options.default_info_string = options.parse.default_info_string.clone();
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

    render_options
}

fn render(env: Env, unsafe_html: String, sanitize: bool) -> NifResult<Term> {
    let html = match sanitize {
        true => clean(&unsafe_html),
        false => unsafe_html,
    };

    rustler::serde::to_term(env, html).map_err(|err| err.into())
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ExNode {
    Document(Vec<ExAttr>, Vec<ExNode>),
    Heading(Vec<ExAttr>, Vec<ExNode>),
    Paragraph(Vec<ExAttr>, Vec<ExNode>),
    Emph(Vec<ExAttr>, Vec<ExNode>),
    SoftBreak(Vec<ExAttr>, Vec<ExNode>),
    #[serde(untagged)]
    Text(String),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ExAttr {
    Level(u8),
}

impl ExNode {
    pub fn parse_document(md: &str) -> ExNode {
        let arena = Arena::new();
        let root = comrak::parse_document(&arena, md, &comrak::ComrakOptions::default());
        Self::parse_node(root)
    }

    fn parse_node<'a>(node: &'a AstNode<'a>) -> Self {
        let children = node
            .children()
            .map(|child| Self::parse_node(child))
            .collect::<Vec<_>>();

        match &node.data.borrow().value {
            NodeValue::Document => ExNode::Document(vec![], children),
            NodeValue::Heading(ref heading) => ExNode::Heading(vec![ExAttr::Level(1)], children),
            NodeValue::Paragraph => ExNode::Paragraph(vec![], children),
            NodeValue::SoftBreak => ExNode::SoftBreak(vec![], children),
            NodeValue::Emph => ExNode::Emph(vec![], children),
            NodeValue::Text(ref text) => ExNode::Text(text.clone()),
            _ => todo!(),
        }
    }

    pub fn format_document(&self) -> String {
        let arena = Arena::new();

        if let ExNode::Document(attrs, children) = self {
            let mut output = vec![];
            let ast_node =
                self.to_ast_nodee(&arena, ExNode::Document(attrs.to_vec(), children.to_vec()));

            println!("ast_node: {:?}", ast_node);

            comrak::html::format_document(ast_node, &Options::default(), &mut output).unwrap();
            String::from_utf8(output).unwrap()
        } else {
            // TODO: return Result
            panic!("Expected `document` node in AST")
        }
    }

    fn ast<'a>(&self, arena: &'a Arena<AstNode<'a>>, node_value: NodeValue) -> &AstNode<'a> {
        arena.alloc(AstNode::new(RefCell::new(Ast::new(
            node_value,
            LineColumn { line: 0, column: 0 },
        ))))
    }

    fn to_ast_nodee<'a>(
        &'a self,
        arena: &'a Arena<AstNode<'a>>,
        exnode: ExNode,
    ) -> &'a AstNode<'a> {
        let build = |node_value: NodeValue, children: Vec<ExNode>| {
            let parent = self.ast(arena, node_value);

            for child in children {
                let ast_child = self.to_ast_nodee(&arena, child);
                parent.append(ast_child);
            }

            parent
        };

        match exnode {
            ExNode::Document(_attrs, children) => build(NodeValue::Document, children),
            ExNode::Heading(_attrs, children) => build(
                NodeValue::Heading(NodeHeading {
                    level: 1,
                    setext: false,
                }),
                children,
            ),
            ExNode::Paragraph(_attrs, children) => build(NodeValue::Paragraph, children),
            ExNode::Text(text) => build(NodeValue::Text(text.to_owned()), vec![]),
            _ => todo!(),
        }
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_document<'a>(env: Env<'a>, md: &str) -> NifResult<Term<'a>> {
    rustler::serde::to_term(env, ExNode::parse_document(md)).map_err(|err| err.into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_document() {
        let parsed = ExNode::Document(
            vec![],
            vec![
                ExNode::Heading(
                    vec![ExAttr::Level(1)],
                    vec![ExNode::Text("header".to_string())],
                ),
                ExNode::Paragraph(
                    vec![],
                    vec![ExNode::Emph(
                        vec![],
                        vec![ExNode::Text("hello".to_string())],
                    )],
                ),
            ],
        );

        assert_eq!(ExNode::parse_document("# header\n*hello*"), parsed);
    }

    #[test]
    fn format_document_from_exnode() {
        let exnode = ExNode::parse_document("# header");
        let astnode = exnode.format_document();
        println!("{:?}", astnode);
    }
}
