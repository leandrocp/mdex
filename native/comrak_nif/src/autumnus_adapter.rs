use autumnus::formatter::{HtmlInlineBuilder, HtmlLinkedBuilder, TerminalBuilder};
use autumnus::languages::Language;
use autumnus::FormatterOption;
use comrak::adapters::SyntaxHighlighterAdapter;
use std::collections::HashMap;
use std::io::{self, Write};

#[derive(Default)]
pub struct AutumnusAdapter<'a> {
    formatter: FormatterOption<'a>,
}

impl<'a> AutumnusAdapter<'a> {
    pub fn new(formatter: FormatterOption<'a>) -> Self {
        Self { formatter }
    }
}

impl SyntaxHighlighterAdapter for AutumnusAdapter<'_> {
    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        _attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        match &self.formatter {
            FormatterOption::HtmlInline {
                theme,
                pre_class,
                italic,
                include_highlights,
                highlight_lines,
                header,
            } => {
                let mut formatter = HtmlInlineBuilder::new()
                    .italic(*italic)
                    .include_highlights(*include_highlights);

                if let Some(theme) = theme {
                    formatter = formatter.theme(theme);
                }

                if let Some(pre_class) = pre_class {
                    formatter = formatter.pre_class(pre_class);
                }

                if let Some(highlight_lines) = highlight_lines {
                    formatter = formatter.highlight_lines(highlight_lines.clone());
                }

                if let Some(header) = header {
                    formatter = formatter.header(header.clone());
                }

                formatter.build().open_pre_tag(output)
            }
            FormatterOption::HtmlLinked {
                pre_class,
                highlight_lines,
                header,
            } => {
                let mut formatter = HtmlLinkedBuilder::new();

                if let Some(pre_class) = pre_class {
                    formatter = formatter.pre_class(pre_class);
                }

                if let Some(highlight_lines) = highlight_lines {
                    formatter = formatter.highlight_lines(highlight_lines.clone());
                }

                if let Some(header) = header {
                    formatter = formatter.header(header.clone());
                }

                formatter.build().open_pre_tag(output)
            }
            FormatterOption::Terminal { .. } => Ok(()),
        }
    }

    fn write_code_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        let plaintext = "language-plaintext".to_string();
        let language = attributes.get("class").unwrap_or(&plaintext);
        let split: Vec<&str> = language.split('-').collect();
        let language = split.get(1).unwrap_or(&"plaintext");
        let lang: Language = Language::guess(language, "");

        match &self.formatter {
            FormatterOption::HtmlInline {
                theme,
                pre_class,
                italic,
                include_highlights,
                highlight_lines,
                header,
            } => {
                let mut formatter = HtmlInlineBuilder::new()
                    .italic(*italic)
                    .include_highlights(*include_highlights)
                    .lang(lang);

                if let Some(theme) = theme {
                    formatter = formatter.theme(theme);
                }

                if let Some(pre_class) = pre_class {
                    formatter = formatter.pre_class(pre_class);
                }

                if let Some(highlight_lines) = highlight_lines {
                    formatter = formatter.highlight_lines(highlight_lines.clone());
                }

                if let Some(header) = header {
                    formatter = formatter.header(header.clone());
                }

                formatter.build().open_code_tag(output)
            }
            FormatterOption::HtmlLinked {
                pre_class,
                highlight_lines,
                header,
            } => {
                let mut formatter = HtmlLinkedBuilder::new().lang(lang);

                if let Some(pre_class) = pre_class {
                    formatter = formatter.pre_class(pre_class);
                }

                if let Some(highlight_lines) = highlight_lines {
                    formatter = formatter.highlight_lines(highlight_lines.clone());
                }

                if let Some(header) = header {
                    formatter = formatter.header(header.clone());
                }

                formatter.build().open_code_tag(output)
            }
            FormatterOption::Terminal { .. } => Ok(()),
        }
    }

    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Option<&str>,
        source: &str,
    ) -> io::Result<()> {
        let lang: Language = Language::guess(lang.unwrap_or("plaintext"), source);

        match &self.formatter {
            FormatterOption::HtmlInline {
                theme,
                pre_class,
                italic,
                include_highlights,
                highlight_lines,
                header,
            } => {
                let mut formatter = HtmlInlineBuilder::new()
                    .italic(*italic)
                    .include_highlights(*include_highlights)
                    .lang(lang)
                    .source(source);

                if let Some(theme) = theme {
                    formatter = formatter.theme(theme);
                }

                if let Some(pre_class) = pre_class {
                    formatter = formatter.pre_class(pre_class);
                }

                if let Some(highlight_lines) = highlight_lines {
                    formatter = formatter.highlight_lines(highlight_lines.clone());
                }

                if let Some(header) = header {
                    formatter = formatter.header(header.clone());
                }

                formatter.build().highlights(output)
            }
            FormatterOption::HtmlLinked {
                pre_class,
                highlight_lines,
                header,
            } => {
                let mut formatter = HtmlLinkedBuilder::new().lang(lang).source(source);

                if let Some(pre_class) = pre_class {
                    formatter = formatter.pre_class(pre_class);
                }

                if let Some(highlight_lines) = highlight_lines {
                    formatter = formatter.highlight_lines(highlight_lines.clone());
                }

                if let Some(header) = header {
                    formatter = formatter.header(header.clone());
                }

                formatter.build().highlights(output)
            }
            FormatterOption::Terminal { theme } => {
                let mut formatter = TerminalBuilder::new().lang(lang).source(source);

                if let Some(theme) = theme {
                    formatter = formatter.theme(theme);
                }

                formatter.build().highlights(output)
            }
        }
    }
}
