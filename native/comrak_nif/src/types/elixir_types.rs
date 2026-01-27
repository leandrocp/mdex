use lumis::formatter::{
    html_inline, html_linked, Formatter, HtmlElement, HtmlInlineBuilder, HtmlLinkedBuilder,
    HtmlMultiThemesBuilder, TerminalBuilder,
};
use lumis::{languages::Language, themes};
use rustler::{NifStruct, NifTaggedEnum, NifUnitEnum};
use std::collections::HashMap;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, NifUnitEnum)]
pub enum ExAppearance {
    Light,
    #[default]
    Dark,
}

#[derive(Debug, NifTaggedEnum)]
pub enum ExFormatterOption {
    HtmlInline {
        theme: Option<ThemeOrString>,
        pre_class: Option<String>,
        italic: bool,
        include_highlights: bool,
        highlight_lines: Option<ExHtmlInlineHighlightLines>,
        header: Option<ExHtmlElement>,
    },
    HtmlLinked {
        pre_class: Option<String>,
        highlight_lines: Option<ExHtmlLinkedHighlightLines>,
        header: Option<ExHtmlElement>,
    },
    HtmlMultiThemes {
        themes: HashMap<String, ExTheme>,
        default_theme: Option<String>,
        css_variable_prefix: Option<String>,
        pre_class: Option<String>,
        italic: bool,
        include_highlights: bool,
        highlight_lines: Option<ExHtmlInlineHighlightLines>,
        header: Option<ExHtmlElement>,
    },
    Terminal {
        theme: Option<ThemeOrString>,
    },
}

impl Default for ExFormatterOption {
    fn default() -> Self {
        Self::HtmlInline {
            theme: None,
            pre_class: None,
            italic: false,
            include_highlights: false,
            highlight_lines: None,
            header: None,
        }
    }
}

#[derive(Debug, NifTaggedEnum)]
pub enum ThemeOrString {
    Theme(ExTheme),
    String(String),
}

impl Default for ThemeOrString {
    fn default() -> Self {
        Self::String("onedark".to_string())
    }
}

#[allow(dead_code)]
fn resolve_theme(theme_or_string: ThemeOrString) -> Option<themes::Theme> {
    match theme_or_string {
        ThemeOrString::Theme(theme) => Some(theme.into()),
        ThemeOrString::String(name) => themes::get(&name).ok(),
    }
}

#[allow(dead_code)]
#[inline]
fn convert_line_specs(lines: Vec<ExLineSpec>) -> Vec<std::ops::RangeInclusive<usize>> {
    lines
        .into_iter()
        .map(|line_spec| line_spec.to_range_inclusive())
        .collect()
}

#[allow(dead_code)]
#[inline]
fn convert_inline_style(
    style: ExHtmlInlineHighlightLinesStyle,
) -> html_inline::HighlightLinesStyle {
    match style {
        ExHtmlInlineHighlightLinesStyle::Theme => html_inline::HighlightLinesStyle::Theme,
        ExHtmlInlineHighlightLinesStyle::Style { style } => {
            html_inline::HighlightLinesStyle::Style(style)
        }
    }
}

#[allow(dead_code)]
impl ExFormatterOption {
    pub fn into_formatter(self, language: Language) -> Result<Box<dyn Formatter>, String> {
        match self {
            ExFormatterOption::HtmlInline {
                theme,
                pre_class,
                italic,
                include_highlights,
                highlight_lines,
                header,
            } => {
                let theme = theme.and_then(resolve_theme);

                let highlight_lines = highlight_lines.map(|hl| html_inline::HighlightLines {
                    lines: convert_line_specs(hl.lines),
                    style: hl.style.map(convert_inline_style),
                    class: hl.class,
                });

                let header = header.map(|h| HtmlElement {
                    open_tag: h.open_tag,
                    close_tag: h.close_tag,
                });

                let formatter = HtmlInlineBuilder::new()
                    .lang(language)
                    .theme(theme)
                    .pre_class(pre_class)
                    .italic(italic)
                    .include_highlights(include_highlights)
                    .highlight_lines(highlight_lines)
                    .header(header)
                    .build()
                    .map_err(|e| format!("HtmlInline builder error: {:?}", e))?;

                Ok(Box::new(formatter))
            }
            ExFormatterOption::HtmlLinked {
                pre_class,
                highlight_lines,
                header,
            } => {
                let highlight_lines = highlight_lines.map(|hl| html_linked::HighlightLines {
                    lines: convert_line_specs(hl.lines),
                    class: hl.class,
                });

                let header = header.map(|h| HtmlElement {
                    open_tag: h.open_tag,
                    close_tag: h.close_tag,
                });

                let formatter = HtmlLinkedBuilder::new()
                    .lang(language)
                    .pre_class(pre_class)
                    .highlight_lines(highlight_lines)
                    .header(header)
                    .build()
                    .map_err(|e| format!("HtmlLinked builder error: {:?}", e))?;

                Ok(Box::new(formatter))
            }
            ExFormatterOption::HtmlMultiThemes {
                themes,
                default_theme,
                css_variable_prefix,
                pre_class,
                italic,
                include_highlights,
                highlight_lines,
                header,
            } => {
                let themes_map: HashMap<String, themes::Theme> =
                    themes.into_iter().map(|(k, v)| (k, v.into())).collect();

                let highlight_lines = highlight_lines.map(|hl| html_inline::HighlightLines {
                    lines: convert_line_specs(hl.lines),
                    style: hl.style.map(convert_inline_style),
                    class: hl.class,
                });

                let header = header.map(|h| HtmlElement {
                    open_tag: h.open_tag,
                    close_tag: h.close_tag,
                });

                let mut builder = HtmlMultiThemesBuilder::new();
                builder
                    .lang(language)
                    .themes(themes_map)
                    .css_variable_prefix(css_variable_prefix.as_deref().unwrap_or("--athl"))
                    .pre_class(pre_class)
                    .italic(italic)
                    .include_highlights(include_highlights)
                    .highlight_lines(highlight_lines)
                    .header(header);

                if let Some(dt_str) = default_theme {
                    builder.default_theme(dt_str);
                }

                let formatter = builder
                    .build()
                    .map_err(|e| format!("HtmlMultiThemes builder error: {:?}", e))?;

                Ok(Box::new(formatter))
            }
            ExFormatterOption::Terminal { theme } => {
                let theme = theme.and_then(resolve_theme);

                let formatter = TerminalBuilder::new()
                    .lang(language)
                    .theme(theme)
                    .build()
                    .map_err(|e| format!("Terminal builder error: {:?}", e))?;

                Ok(Box::new(formatter))
            }
        }
    }
}

#[derive(Clone, Debug, Default, NifStruct)]
#[module = "Lumis.Theme"]
pub struct ExTheme {
    pub name: String,
    pub appearance: ExAppearance,
    pub revision: String,
    pub highlights: HashMap<String, ExStyle>,
}

impl From<ExTheme> for themes::Theme {
    fn from(theme: ExTheme) -> Self {
        let appearance = match theme.appearance {
            ExAppearance::Light => themes::Appearance::Light,
            ExAppearance::Dark => themes::Appearance::Dark,
        };
        themes::Theme {
            name: theme.name,
            appearance,
            revision: theme.revision,
            highlights: theme
                .highlights
                .into_iter()
                .map(|(k, v)| {
                    (
                        k,
                        themes::Style {
                            fg: v.fg,
                            bg: v.bg,
                            bold: v.bold,
                            italic: v.italic,
                            text_decoration: v.text_decoration.into(),
                        },
                    )
                })
                .collect(),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, NifUnitEnum)]
pub enum ExUnderlineStyle {
    Solid,
    Wavy,
    Double,
    Dotted,
    Dashed,
}

fn underline_style_to_ex(style: themes::UnderlineStyle) -> Option<ExUnderlineStyle> {
    match style {
        themes::UnderlineStyle::None => None,
        themes::UnderlineStyle::Solid => Some(ExUnderlineStyle::Solid),
        themes::UnderlineStyle::Wavy => Some(ExUnderlineStyle::Wavy),
        themes::UnderlineStyle::Double => Some(ExUnderlineStyle::Double),
        themes::UnderlineStyle::Dotted => Some(ExUnderlineStyle::Dotted),
        themes::UnderlineStyle::Dashed => Some(ExUnderlineStyle::Dashed),
    }
}

fn ex_underline_style_to_theme(style: Option<ExUnderlineStyle>) -> themes::UnderlineStyle {
    match style {
        None => themes::UnderlineStyle::None,
        Some(ExUnderlineStyle::Solid) => themes::UnderlineStyle::Solid,
        Some(ExUnderlineStyle::Wavy) => themes::UnderlineStyle::Wavy,
        Some(ExUnderlineStyle::Double) => themes::UnderlineStyle::Double,
        Some(ExUnderlineStyle::Dotted) => themes::UnderlineStyle::Dotted,
        Some(ExUnderlineStyle::Dashed) => themes::UnderlineStyle::Dashed,
    }
}

#[derive(Clone, Copy, Debug, Default, NifStruct)]
#[module = "Lumis.Theme.TextDecoration"]
pub struct ExTextDecoration {
    pub underline: Option<ExUnderlineStyle>,
    pub strikethrough: bool,
}

impl From<themes::TextDecoration> for ExTextDecoration {
    fn from(td: themes::TextDecoration) -> Self {
        ExTextDecoration {
            underline: underline_style_to_ex(td.underline),
            strikethrough: td.strikethrough,
        }
    }
}

impl From<ExTextDecoration> for themes::TextDecoration {
    fn from(td: ExTextDecoration) -> Self {
        themes::TextDecoration {
            underline: ex_underline_style_to_theme(td.underline),
            strikethrough: td.strikethrough,
        }
    }
}

#[derive(Clone, Debug, Default, NifStruct)]
#[module = "Lumis.Theme.Style"]
pub struct ExStyle {
    pub fg: Option<String>,
    pub bg: Option<String>,
    pub bold: bool,
    pub italic: bool,
    pub text_decoration: ExTextDecoration,
}

#[derive(Clone, Debug, Default, NifStruct)]
#[module = "Lumis.HtmlElement"]
pub struct ExHtmlElement {
    pub open_tag: String,
    pub close_tag: String,
}

#[derive(Clone, Debug, NifTaggedEnum)]
pub enum ExLineSpec {
    Single(usize),
    Range { start: usize, end: usize },
}

#[allow(dead_code)]
impl ExLineSpec {
    fn to_range_inclusive(&self) -> std::ops::RangeInclusive<usize> {
        match self {
            ExLineSpec::Single(line) => *line..=*line,
            ExLineSpec::Range { start, end } => *start..=*end,
        }
    }
}

#[derive(Clone, Debug, Default, NifTaggedEnum)]
pub enum ExHtmlInlineHighlightLinesStyle {
    #[default]
    Theme,
    Style {
        style: String,
    },
}

#[derive(Clone, Debug, Default, NifStruct)]
#[module = "Lumis.HtmlInlineHighlightLines"]
pub struct ExHtmlInlineHighlightLines {
    pub lines: Vec<ExLineSpec>,
    pub style: Option<ExHtmlInlineHighlightLinesStyle>,
    pub class: Option<String>,
}

#[derive(Clone, Debug, Default, NifStruct)]
#[module = "Lumis.HtmlLinkedHighlightLines"]
pub struct ExHtmlLinkedHighlightLines {
    pub lines: Vec<ExLineSpec>,
    pub class: String,
}
