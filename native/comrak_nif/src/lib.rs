#![allow(dead_code)]
#![allow(unused_variables)]

#[macro_use]
extern crate rustler;

mod decoder;
mod encoder;
mod inkjet_adapter;
mod types;

use ammonia::clean;
use comrak::{format_commonmark, markdown_to_html_with_plugins, Arena, ComrakPlugins, Options};
use encoder::to_elixir_ast;
use inkjet_adapter::InkjetAdapter;
use rustler::{Encoder, Env, NifResult, Term};
use types::{nodes::ExNode, options::*};

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

fn render(env: Env, unsafe_html: String, sanitize: bool) -> NifResult<Term> {
    let html = match sanitize {
        true => clean(&unsafe_html),
        false => unsafe_html,
    };

    rustler::serde::to_term(env, html).map_err(|err| err.into())
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
    todo!()
    // let comrak_options = comrak::Options {
    //     extension: extension_options_from_ex_options(&options),
    //     parse: parse_options_from_ex_options(&options),
    //     render: render_options_from_ex_options(&options),
    // };

    // println!("tree: {:?}", tree);

    // let ex_node: ExNode = tree.decode()?;
    // println!("ex_node: {:?}", ex_node);

    // let arena = Arena::new();
    // let comrak_ast = convert_ex_node_to_comrak(&arena, &ex_node);
    // println!("comrak_ast: {:?}", comrak_ast);

    // let mut buffer = vec![];
    // format_commonmark(comrak_ast, &comrak_options, &mut buffer).unwrap();
    // let out = String::from_utf8(buffer).unwrap();
    // println!("out: {:?}", out);

    // let unsafe_html = comrak::markdown_to_html(out.as_str(), &comrak_options);
    // render(env, unsafe_html, options.features.sanitize)

    // let node = to_astnode(tree);
    // println!("astnode: {:?}", node);

    // let d = tree.decode();

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
}
