#[macro_use]
extern crate rustler;

use ammonia::clean;
use comrak::markdown_to_html;
use rustler::{Env, NifResult, Term};
use serde_rustler::to_term;

rustler::init!("Elixir.MDEx.Native", [to_html, to_html_with_options]);

#[derive(Debug, NifStruct)]
#[module = "MDEx.ExtensionOptions"]
pub struct ExtensionOptions {
    pub strikethrough: bool,
    pub tagfilter: bool,
    pub table: bool,
    pub autolink: bool,
    pub tasklist: bool,
    pub superscript: bool,
    pub header_ids: Option<String>,
    pub footnotes: bool,
    pub description_lists: bool,
    pub front_matter_delimiter: Option<String>,
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.ParseOptions"]
pub struct ParseOptions {
    pub smart: bool,
    pub default_info_string: Option<String>,
    pub relaxed_tasklist_matching: bool,
}

#[derive(Debug, NifUnitEnum)]
pub enum ListStyleType {
    Dash,
    Plus,
    Star,
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.RenderOptions"]
pub struct RenderOptions {
    pub hardbreaks: bool,
    pub github_pre_lang: bool,
    pub full_info_string: bool,
    pub width: usize,
    pub unsafe_: bool,
    pub escape: bool,
    pub list_style: ListStyleType,
    pub sourcepos: bool,
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.Options"]
pub struct Options {
    pub extension: ExtensionOptions,
    pub parse: ParseOptions,
    pub render: RenderOptions,
    pub sanitize: bool,
}

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html(md: &str) -> String {
    markdown_to_html(md, &comrak::ComrakOptions::default())
}

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html_with_options<'a>(env: Env<'a>, md: &str, options: Options) -> NifResult<Term<'a>> {
    let comrak_options = comrak::ComrakOptions {
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

    let unsafe_html = markdown_to_html(md, &comrak_options);

    if options.sanitize {
        let safe_html = clean(&unsafe_html);
        to_term(env, safe_html).map_err(|err| err.into())
    } else {
        to_term(env, unsafe_html).map_err(|err| err.into())
    }
}

fn list_style(list_style: ListStyleType) -> comrak::ListStyleType {
    match list_style {
        ListStyleType::Dash => comrak::ListStyleType::Dash,
        ListStyleType::Plus => comrak::ListStyleType::Plus,
        ListStyleType::Star => comrak::ListStyleType::Star,
    }
}
