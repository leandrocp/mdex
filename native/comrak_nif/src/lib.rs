#[macro_use]
extern crate rustler;

mod inkjet_adapter;
mod themes;
mod types;

use ammonia::clean;
use comrak::{markdown_to_html, markdown_to_html_with_plugins, ComrakOptions, ComrakPlugins};
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
fn to_html_with_options<'a>(env: Env<'a>, md: &str, options: Options) -> NifResult<Term<'a>> {
    let comrak_options = ComrakOptions {
        extension: comrak::ComrakExtensionOptions {
            strikethrough: options.extension.strikethrough,
            tagfilter: options.extension.tagfilter,
            table: options.extension.table,
            autolink: options.extension.autolink,
            tasklist: options.extension.tasklist,
            superscript: options.extension.superscript,
            header_ids: options.extension.header_ids,
            footnotes: options.extension.footnotes,
            description_lists: options.extension.description_lists,
            front_matter_delimiter: options.extension.front_matter_delimiter,
        },
        parse: comrak::ComrakParseOptions {
            smart: options.parse.smart,
            default_info_string: options.parse.default_info_string,
            relaxed_tasklist_matching: options.parse.relaxed_tasklist_matching,
        },
        render: comrak::ComrakRenderOptions {
            hardbreaks: options.render.hardbreaks,
            github_pre_lang: options.render.github_pre_lang,
            full_info_string: options.render.full_info_string,
            width: options.render.width,
            unsafe_: options.render.unsafe_,
            escape: options.render.escape,
            list_style: list_style(options.render.list_style),
            sourcepos: options.render.sourcepos,
        },
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

fn list_style(list_style: ListStyleType) -> comrak::ListStyleType {
    match list_style {
        ListStyleType::Dash => comrak::ListStyleType::Dash,
        ListStyleType::Plus => comrak::ListStyleType::Plus,
        ListStyleType::Star => comrak::ListStyleType::Star,
    }
}
