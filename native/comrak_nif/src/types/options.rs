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
}

#[derive(Debug, NifStruct)]
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

pub fn parse_options_from_ex_options(options: &ExOptions) -> ParseOptions {
    let mut parse_options = ParseOptions::default();

    parse_options.smart = options.parse.smart;
    parse_options
        .default_info_string
        .clone_from(&options.parse.default_info_string);
    parse_options.relaxed_tasklist_matching = options.parse.relaxed_tasklist_matching;
    parse_options.relaxed_autolinks = options.parse.relaxed_autolinks;

    parse_options
}

pub fn render_options_from_ex_options(options: &ExOptions) -> RenderOptions {
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
