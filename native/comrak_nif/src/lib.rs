#[macro_use]
extern crate rustler;

use std::collections::BTreeMap;

use ammonia::clean;
use comrak::{
    markdown_to_html, markdown_to_html_with_plugins, plugins::syntect::SyntectAdapter,
    plugins::syntect::SyntectAdapterBuilder, ComrakOptions, ComrakPlugins,
};
use rustler::{Env, NifResult, Term};
use serde_rustler::to_term;
use syntect::highlighting::ThemeSet;
use syntect_assets::assets::HighlightingAssets;

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
#[module = "MDEx.FeaturesOptions"]
pub struct FeaturesOptions {
    pub sanitize: bool,
    pub syntax_highlight_theme: Option<String>,
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.Options"]
pub struct Options {
    pub extension: ExtensionOptions,
    pub parse: ParseOptions,
    pub render: RenderOptions,
    pub features: FeaturesOptions,
}

#[rustler::nif(schedule = "DirtyCpu")]
fn to_html(md: &str) -> String {
    let syntec_adapter = SyntectAdapter::new("InspiredGitHub");
    let mut plugins = ComrakPlugins::default();
    plugins.render.codefence_syntax_highlighter = Some(&syntec_adapter);
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
            let mut plugins = ComrakPlugins::default();
            let adapter = build_syntect_adapter(theme);
            plugins.render.codefence_syntax_highlighter = Some(&adapter);
            let unsafe_html = markdown_to_html_with_plugins(md, &comrak_options, &plugins);
            render(env, unsafe_html, options.features.sanitize)
        }
        None => {
            let unsafe_html = markdown_to_html(md, &comrak_options);
            render(env, unsafe_html, options.features.sanitize)
        }
    }
}

fn build_syntect_adapter(theme: String) -> SyntectAdapter {
    let assets = HighlightingAssets::from_binary();
    let syntax_set = assets.get_syntax_set().unwrap();

    let mut theme_set = ThemeSet::new();
    let mut themes = BTreeMap::new();

    for theme_name in assets.themes() {
        let theme = assets.get_theme(theme_name);
        themes.insert(String::from(theme_name), theme.clone());
    }
    theme_set.themes = themes.clone();

    let builder = SyntectAdapterBuilder::new();

    builder
        .syntax_set(syntax_set.clone())
        .theme_set(theme_set)
        .theme(theme.as_str())
        .build()
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
