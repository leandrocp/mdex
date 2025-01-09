use comrak::{ExtensionOptions, ListStyleType, ParseOptions, RenderOptions};

#[derive(Debug, NifStruct)]
#[module = "MDEx.Types.ExtensionOptions"]
pub struct ExExtensionOptions {
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
    pub multiline_block_quotes: bool,
    pub math_dollars: bool,
    pub math_code: bool,
    pub shortcodes: bool,
    pub wikilinks_title_after_pipe: bool,
    pub wikilinks_title_before_pipe: bool,
    pub underline: bool,
    pub subscript: bool,
    pub spoiler: bool,
    pub greentext: bool,
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.Types.ParseOptions"]
pub struct ExParseOptions {
    pub smart: bool,
    pub default_info_string: Option<String>,
    pub relaxed_tasklist_matching: bool,
    pub relaxed_autolinks: bool,
}

#[derive(Clone, Debug, NifUnitEnum)]
pub enum ExListStyleType {
    Dash,
    Plus,
    Star,
}

impl From<ExListStyleType> for ListStyleType {
    fn from(list_style_type: ExListStyleType) -> Self {
        match list_style_type {
            ExListStyleType::Dash => ListStyleType::Dash,
            ExListStyleType::Plus => ListStyleType::Plus,
            ExListStyleType::Star => ListStyleType::Star,
        }
    }
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.Types.RenderOptions"]
pub struct ExRenderOptions {
    pub hardbreaks: bool,
    pub github_pre_lang: bool,
    pub full_info_string: bool,
    pub width: usize,
    pub unsafe_: bool,
    pub escape: bool,
    pub list_style: ExListStyleType,
    pub sourcepos: bool,
    pub experimental_inline_sourcepos: bool,
    pub escaped_char_spans: bool,
    pub ignore_setext: bool,
    pub ignore_empty_links: bool,
    pub gfm_quirks: bool,
    pub prefer_fenced: bool,
    pub figure_with_caption: bool,
    pub tasklist_classes: bool,
    pub ol_width: usize,
}

#[derive(Debug, NifStruct, Default)]
#[module = "MDEx.Types.FeaturesOptions"]
pub struct ExFeaturesOptions {
    pub sanitize: bool,
    pub syntax_highlight_theme: Option<String>,
    pub syntax_highlight_inline_style: Option<bool>,
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.Types.Options"]
pub struct ExOptions {
    pub extension: ExExtensionOptions,
    pub parse: ExParseOptions,
    pub render: ExRenderOptions,
    pub features: ExFeaturesOptions,
}

pub fn extension_options_from_ex_options(options: &ExOptions) -> ExtensionOptions {
    ExtensionOptions::<'_> {
        strikethrough: options.extension.strikethrough,
        tagfilter: options.extension.tagfilter,
        table: options.extension.table,
        autolink: options.extension.autolink,
        tasklist: options.extension.tasklist,
        superscript: options.extension.superscript,
        header_ids: options.extension.header_ids.clone(),
        footnotes: options.extension.footnotes,
        description_lists: options.extension.description_lists,
        front_matter_delimiter: options.extension.front_matter_delimiter.clone(),
        multiline_block_quotes: options.extension.multiline_block_quotes,
        math_dollars: options.extension.math_dollars,
        math_code: options.extension.math_code,
        shortcodes: options.extension.shortcodes,
        wikilinks_title_after_pipe: options.extension.wikilinks_title_after_pipe,
        wikilinks_title_before_pipe: options.extension.wikilinks_title_before_pipe,
        underline: options.extension.underline,
        subscript: options.extension.subscript,
        spoiler: options.extension.spoiler,
        greentext: options.extension.greentext,
        ..Default::default()
    }
}

pub fn parse_options_from_ex_options(options: &ExOptions) -> ParseOptions {
    ParseOptions::<'_> {
        smart: options.parse.smart,
        default_info_string: options.parse.default_info_string.clone(),
        relaxed_tasklist_matching: options.parse.relaxed_tasklist_matching,
        relaxed_autolinks: options.parse.relaxed_autolinks,
        ..Default::default()
    }
}

pub fn render_options_from_ex_options(options: &ExOptions) -> RenderOptions {
    RenderOptions {
        hardbreaks: options.render.hardbreaks,
        github_pre_lang: options.render.github_pre_lang,
        full_info_string: options.render.full_info_string,
        width: options.render.width,
        unsafe_: options.render.unsafe_,
        escape: options.render.escape,
        list_style: ListStyleType::from(options.render.list_style.clone()),
        sourcepos: options.render.sourcepos,
        experimental_inline_sourcepos: options.render.experimental_inline_sourcepos,
        escaped_char_spans: options.render.escaped_char_spans,
        ignore_setext: options.render.ignore_setext,
        ignore_empty_links: options.render.ignore_empty_links,
        gfm_quirks: options.render.gfm_quirks,
        prefer_fenced: options.render.prefer_fenced,
        figure_with_caption: options.render.figure_with_caption,
        tasklist_classes: options.render.tasklist_classes,
        ol_width: options.render.ol_width,
    }
}
