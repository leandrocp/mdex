#[derive(Debug, NifStruct)]
#[module = "MDEx.Types.ExtensionOptions"]
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
#[module = "MDEx.Types.ParseOptions"]
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
#[module = "MDEx.Types.RenderOptions"]
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
#[module = "MDEx.Types.FeaturesOptions"]
pub struct FeaturesOptions {
    pub sanitize: bool,
    pub syntax_highlight_theme: Option<String>,
}

#[derive(Debug, NifStruct)]
#[module = "MDEx.Types.Options"]
pub struct Options {
    pub extension: ExtensionOptions,
    pub parse: ParseOptions,
    pub render: RenderOptions,
    pub features: FeaturesOptions,
}
