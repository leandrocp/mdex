#![allow(dead_code)]
#![allow(unused_variables)]

#[macro_use]
extern crate rustler;

mod encoder;
mod inkjet_adapter;
mod types;

use comrak::{markdown_to_html_with_plugins, Arena, ComrakPlugins, Options};
use inkjet_adapter::InkjetAdapter;
use rustler::{Encoder, Env, NifResult, Term};
use types::{atoms::ok, document::*, options::*};

rustler::init!(
    "Elixir.MDEx.Native",
    [
        parse_document,
        markdown_to_html,
        markdown_to_html_with_options,
        markdown_to_xml,
        markdown_to_xml_with_options,
        document_to_commonmark,
        document_to_commonmark_with_options,
        document_to_html,
        document_to_html_with_options,
        document_to_xml,
        document_to_xml_with_options,
    ]
);

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_document<'a>(env: Env<'a>, md: &str, options: ExOptions) -> NifResult<Term<'a>> {
    let comrak_options = comrak::Options {
        extension: extension_options_from_ex_options(&options),
        parse: parse_options_from_ex_options(&options),
        render: render_options_from_ex_options(&options),
    };
    let arena = Arena::new();
    let root = comrak::parse_document(&arena, md, &comrak_options);
    let ex_document = comrak_ast_to_ex_document(root);
    Ok((ok(), ex_document).encode(env))
}

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
fn markdown_to_xml<'a>(env: Env<'a>, md: &str) -> NifResult<Term<'a>> {
    let inkjet_adapter = InkjetAdapter::default();
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);
    let arena = Arena::new();
    let root = comrak::parse_document(&arena, md, &Options::default());
    let mut buffer = vec![];
    comrak::format_xml_with_plugins(root, &Options::default(), &mut buffer, &plugins).unwrap();
    let xml = String::from_utf8(buffer).unwrap();
    Ok((ok(), xml).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn markdown_to_xml_with_options<'a>(
    env: Env<'a>,
    md: &str,
    options: ExOptions,
) -> NifResult<Term<'a>> {
    let comrak_options = comrak::Options {
        extension: extension_options_from_ex_options(&options),
        parse: parse_options_from_ex_options(&options),
        render: render_options_from_ex_options(&options),
    };

    let arena = Arena::new();
    let root = comrak::parse_document(&arena, md, &comrak_options);
    let mut buffer = vec![];

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
            comrak::format_xml_with_plugins(root, &comrak_options, &mut buffer, &plugins).unwrap();
            let xml = String::from_utf8(buffer).unwrap();
            Ok((ok(), xml).encode(env))
        }
        None => {
            comrak::format_xml_with_plugins(
                root,
                &comrak_options,
                &mut buffer,
                &ComrakPlugins::default(),
            )
            .unwrap();
            let xml = String::from_utf8(buffer).unwrap();
            Ok((ok(), xml).encode(env))
        }
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_commonmark(env: Env<'_>, ex_document: ExDocument) -> NifResult<Term<'_>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);

    let inkjet_adapter = InkjetAdapter::default();
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);

    let mut buffer = vec![];
    comrak::format_commonmark_with_plugins(comrak_ast, &Options::default(), &mut buffer, &plugins)
        .unwrap();
    let commonmark = String::from_utf8(buffer).unwrap();

    Ok((ok(), commonmark).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_commonmark_with_options(
    env: Env<'_>,
    ex_document: ExDocument,
    options: ExOptions,
) -> NifResult<Term<'_>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);

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

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_html(env: Env<'_>, ex_document: ExDocument) -> NifResult<Term<'_>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);

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
fn document_to_html_with_options(
    env: Env<'_>,
    ex_document: ExDocument,
    options: ExOptions,
) -> NifResult<Term<'_>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);

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
            comrak::format_commonmark(comrak_ast, &comrak_options, &mut buffer).unwrap();
            let unsafe_html = String::from_utf8(buffer).unwrap();

            maybe_sanitize(env, unsafe_html, options.features.sanitize)
        }
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_xml(env: Env<'_>, ex_document: ExDocument) -> NifResult<Term<'_>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);

    let inkjet_adapter = InkjetAdapter::default();
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);

    let mut buffer = vec![];
    comrak::format_xml_with_plugins(comrak_ast, &Options::default(), &mut buffer, &plugins)
        .unwrap();
    let xml = String::from_utf8(buffer).unwrap();
    Ok((ok(), xml).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn document_to_xml_with_options(
    env: Env<'_>,
    ex_document: ExDocument,
    options: ExOptions,
) -> NifResult<Term<'_>> {
    let arena = Arena::new();
    let ex_node = NewNode::Document(ex_document);
    let comrak_ast = ex_document_to_comrak_ast(&arena, ex_node);

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
            comrak::format_xml_with_plugins(comrak_ast, &comrak_options, &mut buffer, &plugins)
                .unwrap();
            let xml = String::from_utf8(buffer).unwrap();
            Ok((ok(), xml).encode(env))
        }
        None => {
            let mut buffer = vec![];
            comrak::format_xml_with_plugins(
                comrak_ast,
                &comrak_options,
                &mut buffer,
                &ComrakPlugins::default(),
            )
            .unwrap();
            let xml = String::from_utf8(buffer).unwrap();
            Ok((ok(), xml).encode(env))
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
