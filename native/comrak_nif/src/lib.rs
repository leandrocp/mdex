#![allow(dead_code)]
#![allow(unused_variables)]

#[macro_use]
extern crate rustler;

mod autumnus_adapter;
mod types;

use autumnus_adapter::AutumnusAdapter;
use comrak::html::{ChildRendering, Context};
use comrak::{create_formatter, nodes::NodeValue};
use comrak::{Anchorizer, Arena, ComrakPlugins, Options};
use lol_html::html_content::ContentType;
use lol_html::{rewrite_str, text, RewriteStrSettings};
use rustler::{Encoder, Env, NifResult, Term};
use std::io::{self, Write};
use types::{atoms::ok, document::*, options::*};

rustler::init!("Elixir.MDEx.Native");

create_formatter!(HTMLFormatter, {
    NodeValue::Text(ref literal) => |context, node, entering| {
        if entering {
            write_context(context, literal.as_bytes())?;
        }
        return Ok(ChildRendering::HTML);
    },
});

pub fn write_context<T>(context: &mut Context<T>, buffer: &[u8]) -> io::Result<()> {
    if context.options.render.escape {
        context.escape(buffer)
    } else {
        context.write_all(buffer)
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_document<'a>(env: Env<'a>, md: &str, options: ExOptions) -> NifResult<Term<'a>> {
    let comrak_options = comrak::Options {
        extension: options.extension.into(),
        parse: options.parse.into(),
        render: options.render.into(),
    };
    let arena = Arena::new();
    let root = comrak::parse_document(&arena, md, &comrak_options);
    let ex_document = comrak_ast_to_ex_document(root);
    Ok((ok(), ex_document).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_html_with_options<'a>(
    env: Env<'a>,
    md: &str,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    let comrak_options = comrak::Options {
        extension: options.extension.into(),
        parse: options.parse.into(),
        render: options.render.into(),
    };
    let arena = Arena::new();
    let root = comrak::parse_document(&arena, md, &comrak_options);
    let mut plugins = ComrakPlugins::default();
    let do_syntax_highlight = options.syntax_highlight.is_some();
    let autumnus_adapter = AutumnusAdapter::new(
        options
            .syntax_highlight
            .unwrap_or_default()
            .formatter
            .into(),
    );

    if do_syntax_highlight {
        plugins.render.codefence_syntax_highlighter = Some(&autumnus_adapter);
    }

    let mut buffer = vec![];

    HTMLFormatter::format_document_with_plugins(root, &comrak_options, &mut buffer, &plugins)
        .unwrap();
    let unsafe_html = String::from_utf8(buffer).unwrap();
    let html = do_safe_html(unsafe_html, &options.sanitize, false, true);
    Ok((ok(), html).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_xml_with_options<'a>(
    env: Env<'a>,
    md: &str,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    let comrak_options = comrak::Options {
        extension: options.extension.into(),
        parse: options.parse.into(),
        render: options.render.into(),
    };
    let arena = Arena::new();
    let root = comrak::parse_document(&arena, md, &comrak_options);
    let mut buffer = vec![];
    let mut plugins = ComrakPlugins::default();
    let do_syntax_highlight = options.syntax_highlight.is_some();
    let autumnus_adapter = AutumnusAdapter::new(
        options
            .syntax_highlight
            .unwrap_or_default()
            .formatter
            .into(),
    );

    if do_syntax_highlight {
        plugins.render.codefence_syntax_highlighter = Some(&autumnus_adapter);
    }

    comrak::format_xml_with_plugins(root, &comrak_options, &mut buffer, &plugins).unwrap();
    let xml = String::from_utf8(buffer).unwrap();
    Ok((ok(), xml).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_commonmark(env: Env<'_>, ex_document: ExDocument) -> NifResult<Term<'_>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);
    let mut buffer = vec![];
    let plugins = ComrakPlugins::default();
    comrak::format_commonmark_with_plugins(comrak_ast, &Options::default(), &mut buffer, &plugins)
        .unwrap();
    let commonmark = String::from_utf8(buffer).unwrap();
    Ok((ok(), commonmark).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_commonmark_with_options<'a>(
    env: Env<'a>,
    ex_document: ExDocument,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);
    let comrak_options = comrak::Options {
        extension: options.extension.into(),
        parse: options.parse.into(),
        render: options.render.into(),
    };
    let mut buffer = vec![];
    let mut plugins = ComrakPlugins::default();
    let do_syntax_highlight = options.syntax_highlight.is_some();
    let autumnus_adapter = AutumnusAdapter::new(
        options
            .syntax_highlight
            .unwrap_or_default()
            .formatter
            .into(),
    );

    if do_syntax_highlight {
        plugins.render.codefence_syntax_highlighter = Some(&autumnus_adapter);
    }

    comrak::format_commonmark_with_plugins(comrak_ast, &comrak_options, &mut buffer, &plugins)
        .unwrap();
    let document = String::from_utf8(buffer).unwrap();
    Ok((ok(), document).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_html(env: Env<'_>, ex_document: ExDocument) -> NifResult<Term<'_>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);
    let mut buffer = vec![];
    let options = Options::default();
    let plugins = ComrakPlugins::default();
    comrak::format_html_with_plugins(comrak_ast, &options, &mut buffer, &plugins).unwrap();
    let unsafe_html = String::from_utf8(buffer).unwrap();
    let html = do_safe_html(unsafe_html, &None, false, true);
    Ok((ok(), html).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_html_with_options<'a>(
    env: Env<'a>,
    ex_document: ExDocument,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);
    let comrak_options = comrak::Options {
        extension: options.extension.into(),
        parse: options.parse.into(),
        render: options.render.into(),
    };
    let mut buffer = vec![];
    let mut plugins = ComrakPlugins::default();
    let do_syntax_highlight = options.syntax_highlight.is_some();
    let autumnus_adapter = AutumnusAdapter::new(
        options
            .syntax_highlight
            .unwrap_or_default()
            .formatter
            .into(),
    );

    if do_syntax_highlight {
        plugins.render.codefence_syntax_highlighter = Some(&autumnus_adapter);
    }

    comrak::format_html_with_plugins(comrak_ast, &comrak_options, &mut buffer, &plugins).unwrap();
    let unsafe_html = String::from_utf8(buffer).unwrap();
    let html = do_safe_html(unsafe_html, &options.sanitize, false, true);
    Ok((ok(), html).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_xml(env: Env<'_>, ex_document: ExDocument) -> NifResult<Term<'_>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);
    let mut buffer = vec![];
    let plugins = ComrakPlugins::default();
    comrak::format_xml_with_plugins(comrak_ast, &Options::default(), &mut buffer, &plugins)
        .unwrap();
    let xml = String::from_utf8(buffer).unwrap();
    Ok((ok(), xml).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_xml_with_options<'a>(
    env: Env<'a>,
    ex_document: ExDocument,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);
    let comrak_options = comrak::Options {
        extension: options.extension.into(),
        parse: options.parse.into(),
        render: options.render.into(),
    };
    let mut buffer = vec![];
    let mut plugins = ComrakPlugins::default();
    let do_syntax_highlight = options.syntax_highlight.is_some();
    let autumnus_adapter = AutumnusAdapter::new(
        options
            .syntax_highlight
            .unwrap_or_default()
            .formatter
            .into(),
    );

    if do_syntax_highlight {
        plugins.render.codefence_syntax_highlighter = Some(&autumnus_adapter);
    }

    comrak::format_xml_with_plugins(comrak_ast, &comrak_options, &mut buffer, &plugins).unwrap();
    let xml = String::from_utf8(buffer).unwrap();
    Ok((ok(), xml).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn safe_html(
    env: Env<'_>,
    unsafe_html: String,
    sanitize: Option<ExSanitizeOption>,
    escape_content: bool,
    escape_curly_braces_in_code: bool,
) -> NifResult<Term<'_>> {
    Ok(do_safe_html(
        unsafe_html,
        &sanitize,
        escape_content,
        escape_curly_braces_in_code,
    )
    .encode(env))
}

// https://github.com/p-jackson/entities/blob/1d166204433c2ee7931251a5494f94c7e35be9d6/src/entities.rs
fn do_safe_html(
    unsafe_html: String,
    sanitize: &Option<ExSanitizeOption>,
    escape_content: bool,
    escape_curly_braces_in_code: bool,
) -> String {
    let html = match sanitize {
        None => unsafe_html,
        Some(sanitize_option) => sanitize_option.clean(&unsafe_html),
    };

    let html = match escape_curly_braces_in_code {
        true => rewrite_str(
            &html,
            RewriteStrSettings {
                element_content_handlers: vec![text!("code", |chunk| {
                    chunk.replace(
                        &chunk
                            .as_str()
                            .replace('{', "&lbrace;")
                            .replace('}', "&rbrace;"),
                        ContentType::Html,
                    );

                    Ok(())
                })],
                ..RewriteStrSettings::new()
            },
        )
        .unwrap(),
        false => html,
    };

    let html = match escape_content {
        true => v_htmlescape::escape(&html).to_string(),
        false => html,
    };

    // TODO: not so clean solution to undo double escaping, could be better
    html.replace("&amp;lbrace;", "&lbrace;")
        .replace("&amp;rbrace;", "&rbrace;")
}


#[rustler::nif(schedule = "DirtyCpu")]
pub fn text_to_anchor(env: Env<'_>, text: String) -> NifResult<Term<'_>> {
    let mut anchorizer = Anchorizer::new();
    let anchor = anchorizer.anchorize(text);
    Ok((ok(), anchor).encode(env))
}
