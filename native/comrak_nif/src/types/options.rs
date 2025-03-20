use comrak::{ExtensionOptions, ListStyleType, ParseOptions, RenderOptions};

#[derive(Debug, NifMap)]
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
    pub alerts: bool,
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

impl From<ExExtensionOptions> for ExtensionOptions<'_> {
    fn from(options: ExExtensionOptions) -> Self {
        ExtensionOptions {
            strikethrough: options.strikethrough,
            tagfilter: options.tagfilter,
            table: options.table,
            autolink: options.autolink,
            tasklist: options.tasklist,
            superscript: options.superscript,
            header_ids: options.header_ids,
            footnotes: options.footnotes,
            description_lists: options.description_lists,
            front_matter_delimiter: options.front_matter_delimiter,
            multiline_block_quotes: options.multiline_block_quotes,
            alerts: options.alerts,
            math_dollars: options.math_dollars,
            math_code: options.math_code,
            shortcodes: options.shortcodes,
            wikilinks_title_after_pipe: options.wikilinks_title_after_pipe,
            wikilinks_title_before_pipe: options.wikilinks_title_before_pipe,
            underline: options.underline,
            subscript: options.subscript,
            spoiler: options.spoiler,
            greentext: options.greentext,
            image_url_rewriter: None,
            link_url_rewriter: None,
        }
    }
}

#[derive(Debug, NifMap)]
pub struct ExParseOptions {
    pub smart: bool,
    pub default_info_string: Option<String>,
    pub relaxed_tasklist_matching: bool,
    pub relaxed_autolinks: bool,
}

impl From<ExParseOptions> for ParseOptions<'_> {
    fn from(options: ExParseOptions) -> Self {
        ParseOptions {
            smart: options.smart,
            default_info_string: options.default_info_string,
            relaxed_tasklist_matching: options.relaxed_tasklist_matching,
            relaxed_autolinks: options.relaxed_autolinks,
            broken_link_callback: None,
        }
    }
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

#[derive(Debug, NifMap)]
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
    pub experimental_minimize_commonmark: bool,
}

impl From<ExRenderOptions> for RenderOptions {
    fn from(options: ExRenderOptions) -> Self {
        RenderOptions {
            hardbreaks: options.hardbreaks,
            github_pre_lang: options.github_pre_lang,
            full_info_string: options.full_info_string,
            width: options.width,
            unsafe_: options.unsafe_,
            escape: options.escape,
            list_style: ListStyleType::from(options.list_style),
            sourcepos: options.sourcepos,
            experimental_inline_sourcepos: options.experimental_inline_sourcepos,
            escaped_char_spans: options.escaped_char_spans,
            ignore_setext: options.ignore_setext,
            ignore_empty_links: options.ignore_empty_links,
            gfm_quirks: options.gfm_quirks,
            prefer_fenced: options.prefer_fenced,
            figure_with_caption: options.figure_with_caption,
            tasklist_classes: options.tasklist_classes,
            ol_width: options.ol_width,
            experimental_minimize_commonmark: options.experimental_minimize_commonmark,
        }
    }
}

#[derive(Debug, NifMap, Default)]
pub struct ExFeaturesOptions {
    pub sanitize: bool,
    pub syntax_highlight_theme: Option<String>,
    pub syntax_highlight_inline_style: Option<bool>,
}

#[derive(Debug, NifMap)]
pub struct ExOptions {
    pub extension: ExExtensionOptions,
    pub parse: ExParseOptions,
    pub render: ExRenderOptions,
    pub features: ExFeaturesOptions,
}
