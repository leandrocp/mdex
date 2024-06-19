use comrak::ListStyleType;

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
    pub escaped_char_spans: bool,
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.Types.FeaturesOptions"]
pub struct ExFeaturesOptions {
    pub sanitize: bool,
    pub syntax_highlight_theme: Option<String>,
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.Types.Options"]
pub struct ExOptions {
    pub extension: ExExtensionOptions,
    pub parse: ExParseOptions,
    pub render: ExRenderOptions,
    pub features: ExFeaturesOptions,
}
