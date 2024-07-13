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
use types::options::*;

rustler::init!("Elixir.MDEx.Native", [to_html, to_html_with_options]);

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html(md: &str) -> String {
    let inkjet_adapter = InkjetAdapter::default();
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
