use autumnus::formatter::{HtmlInlineBuilder, HtmlLinkedBuilder, TerminalBuilder};
use autumnus::languages::Language;
use autumnus::FormatterOption;
use comrak::adapters::SyntaxHighlighterAdapter;
use std::collections::HashMap;
use std::io::{self, Write};
use std::sync::Mutex;

#[derive(Default)]
pub struct AutumnusAdapter<'a> {
    formatter: FormatterOption<'a>,
    language: Mutex<Option<Language>>,
}

impl<'a> AutumnusAdapter<'a> {
    pub fn new(formatter: FormatterOption<'a>) -> Self {
        Self {
            formatter,
            language: Mutex::new(None),
        }
    }
}

impl SyntaxHighlighterAdapter for AutumnusAdapter<'_> {
    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        if let Some(lang) = attributes.get("lang") {
            let language = Language::guess(lang, "");
            *self.language.lock().unwrap() = Some(language);
        }

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
        let mut language_lock = self.language.lock().unwrap();

        let lang = if let Some(stored_lang) = *language_lock {
            stored_lang
        } else {
            let determined_lang = if let Some(lang_attr) = attributes.get("lang") {
                Language::guess(lang_attr, "")
            } else if let Some(class_attr) = attributes.get("class") {
                let language = class_attr.strip_prefix("language-").unwrap_or("plaintext");
                Language::guess(language, "")
            } else {
                Language::guess("plaintext", "")
            };

            *language_lock = Some(determined_lang);
            determined_lang
        };

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
        let lang: Language = if let Some(stored_lang) = *self.language.lock().unwrap() {
            stored_lang
        } else {
            Language::guess(lang.unwrap_or("plaintext"), source)
        };

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_autumnus_adapter_with_foo_field() {
        let formatter = FormatterOption::HtmlInline {
            theme: None,
            pre_class: None,
            italic: false,
            include_highlights: false,
            highlight_lines: None,
            header: None,
        };

        let adapter = AutumnusAdapter::new(formatter);

        // Test that adapter can be created with the foo field
        assert!(adapter.foo.lock().unwrap().is_none());

        // Test write_pre_tag mutates foo field
        let mut output = Vec::new();
        let attributes = HashMap::new();
        adapter.write_pre_tag(&mut output, attributes).unwrap();
        assert_eq!(*adapter.foo.lock().unwrap(), Some("pre_tag".to_string()));

        // Test write_code_tag mutates foo field
        let mut output = Vec::new();
        let mut attributes = HashMap::new();
        attributes.insert("class".to_string(), "language-rust".to_string());
        adapter.write_code_tag(&mut output, attributes).unwrap();
        assert_eq!(*adapter.foo.lock().unwrap(), Some("code_tag".to_string()));
    }
}
