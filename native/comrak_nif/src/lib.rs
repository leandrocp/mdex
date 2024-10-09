#![allow(dead_code)]
#![allow(unused_variables)]

#[macro_use]
extern crate rustler;

mod decoder;
mod encoder;
mod inkjet_adapter;
mod types;

use comrak::{markdown_to_html_with_plugins, Arena, ComrakPlugins, Options};
use decoder::ex_node_to_comrak_ast;
use encoder::to_elixir_ast;
use inkjet_adapter::InkjetAdapter;
use rustler::{Decoder, Encoder, Env, NifResult, Term};
use types::{atoms::ok, options::*};

rustler::init!(
    "Elixir.MDEx.Native",
    [
        parse_document,
        markdown_to_html,
        markdown_to_html_with_options,
        ast_to_html,
        ast_to_html_with_options,
        ast_to_commonmark,
        ast_to_commonmark_with_options
    ]
);

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_html<'a>(env: Env<'a>, md: &str) -> NifResult<Term<'a>> {
    let inkjet_adapter = InkjetAdapter::default();
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);
    let html = markdown_to_html_with_plugins(md, &Options::default(), &plugins);
    Ok((ok(), html).encode(env))
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
            maybe_sanitize(env, unsafe_html, options.features.sanitize)
        }
        None => {
            let unsafe_html = comrak::markdown_to_html(md, &comrak_options);
            maybe_sanitize(env, unsafe_html, options.features.sanitize)
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
    Ok((ok(), vec![ex_ast]).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn ast_to_html<'a>(env: Env<'a>, ast: Term<'a>) -> NifResult<Term<'a>> {
    let ex_node = types::nodes::ExNode::decode(ast)?;

    let arena = Arena::new();
    let comrak_ast = ex_node_to_comrak_ast(&arena, &ex_node);

    // FIXME: error handling format_html and from_utf8

    let inkjet_adapter = InkjetAdapter::default();
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);

    let mut buffer = vec![];
    comrak::format_html_with_plugins(comrak_ast, &Options::default(), &mut buffer, &plugins)
        .unwrap();
    let html = String::from_utf8(buffer).unwrap();

    Ok((ok(), html).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn ast_to_html_with_options<'a>(
    env: Env<'a>,
    ast: Term<'a>,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    let ex_node = types::nodes::ExNode::decode(ast)?;
    let arena = Arena::new();
    let comrak_ast = ex_node_to_comrak_ast(&arena, &ex_node);

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

            let mut buffer = vec![];
            comrak::format_html_with_plugins(comrak_ast, &comrak_options, &mut buffer, &plugins)
                .unwrap();
            let unsafe_html = String::from_utf8(buffer).unwrap();

            maybe_sanitize(env, unsafe_html, options.features.sanitize)
        }
        None => {
            let mut buffer = vec![];
            comrak::format_html(comrak_ast, &comrak_options, &mut buffer).unwrap();
            let unsafe_html = String::from_utf8(buffer).unwrap();

            maybe_sanitize(env, unsafe_html, options.features.sanitize)
        }
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn ast_to_commonmark<'a>(env: Env<'a>, ast: Term<'a>) -> NifResult<Term<'a>> {
    let ex_node = types::nodes::ExNode::decode(ast)?;

    let arena = Arena::new();
    let comrak_ast = ex_node_to_comrak_ast(&arena, &ex_node);

    // FIXME: error handling format_html and from_utf8

    let inkjet_adapter = InkjetAdapter::default();
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);

    let mut buffer = vec![];
    comrak::format_commonmark_with_plugins(comrak_ast, &Options::default(), &mut buffer, &plugins)
        .unwrap();
    let html = String::from_utf8(buffer).unwrap();

    Ok((ok(), html).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn ast_to_commonmark_with_options<'a>(
    env: Env<'a>,
    ast: Term<'a>,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    let ex_node = types::nodes::ExNode::decode(ast)?;
    let arena = Arena::new();
    let comrak_ast = ex_node_to_comrak_ast(&arena, &ex_node);

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

            let mut buffer = vec![];
            comrak::format_commonmark_with_plugins(
                comrak_ast,
                &comrak_options,
                &mut buffer,
                &plugins,
            )
            .unwrap();
            let unsafe_html = String::from_utf8(buffer).unwrap();

            maybe_sanitize(env, unsafe_html, options.features.sanitize)
        }
        None => {
            let mut buffer = vec![];
            comrak::format_commonmark(comrak_ast, &comrak_options, &mut buffer).unwrap();
            let unsafe_html = String::from_utf8(buffer).unwrap();

            maybe_sanitize(env, unsafe_html, options.features.sanitize)
        }
    }
}

fn maybe_sanitize(env: Env, unsafe_html: String, sanitize: bool) -> NifResult<Term> {
    let html = match sanitize {
        true => ammonia::clean(&unsafe_html),
        false => unsafe_html,
    };

    Ok((ok(), html).encode(env))
}
