use comrak::{ComrakExtensionOptions, ComrakParseOptions, ComrakRenderOptions, ListStyleType};

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
}

impl From<ExExtensionOptions> for ComrakExtensionOptions {
    fn from(options: ExExtensionOptions) -> Self {
        ComrakExtensionOptions {
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
        }
    }
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.Types.ParseOptions"]
pub struct ExParseOptions {
    pub smart: bool,
    pub default_info_string: Option<String>,
    pub relaxed_tasklist_matching: bool,
}

impl From<ExParseOptions> for ComrakParseOptions {
    fn from(options: ExParseOptions) -> Self {
        ComrakParseOptions {
            smart: options.smart,
            default_info_string: options.default_info_string,
            relaxed_tasklist_matching: options.relaxed_tasklist_matching,
        }
    }
}

#[derive(Debug, NifUnitEnum)]
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
}

impl From<ExRenderOptions> for ComrakRenderOptions {
    fn from(options: ExRenderOptions) -> Self {
        ComrakRenderOptions {
            hardbreaks: options.hardbreaks,
            github_pre_lang: options.github_pre_lang,
            full_info_string: options.full_info_string,
            width: options.width,
            unsafe_: options.unsafe_,
            escape: options.escape,
            list_style: ListStyleType::from(options.list_style),
            sourcepos: options.sourcepos,
        }
    }
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
