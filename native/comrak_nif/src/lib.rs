#[macro_use]
extern crate rustler;

mod inkjet_adapter;
mod types;

use ammonia::clean;
use comrak::{
    markdown_to_html, markdown_to_html_with_plugins, ComrakPlugins, ExtensionOptions,
    ListStyleType, Options, ParseOptions, RenderOptions,
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

    to_term(env, html).map_err(|err| err.into())
}
