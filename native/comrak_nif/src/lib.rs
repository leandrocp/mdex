#[macro_use]
extern crate rustler;

mod inkjet_adapter;
mod themes;
mod types;

use ammonia::clean;
use comrak::{
    markdown_to_html, markdown_to_html_with_plugins, ComrakExtensionOptions, ComrakOptions,
    ComrakParseOptions, ComrakPlugins, ComrakRenderOptions,
};
use inkjet_adapter::InkjetAdapter;
use rustler::{Env, NifResult, Term};
use serde_rustler::to_term;
use types::options::*;

rustler::init!("Elixir.MDEx.Native", [to_html, to_html_with_options]);

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html(md: &str) -> String {
    let inkjet_adapter = InkjetAdapter::new("onedark");
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&inkjet_adapter);
    markdown_to_html_with_plugins(md, &ComrakOptions::default(), &plugins)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html_with_options<'a>(env: Env<'a>, md: &str, options: ExOptions) -> NifResult<Term<'a>> {
    let comrak_options = ComrakOptions {
        extension: ComrakExtensionOptions::from(options.extension),
        parse: ComrakParseOptions::from(options.parse),
        render: ComrakRenderOptions::from(options.render),
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

fn render(env: Env, unsafe_html: String, sanitize: bool) -> NifResult<Term> {
    let html = match sanitize {
        true => clean(&unsafe_html),
        false => unsafe_html,
    };

    to_term(env, html).map_err(|err| err.into())
}
