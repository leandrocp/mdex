use autumnus::formatter::{HtmlFormatter, HtmlInline, HtmlLinked};
use autumnus::languages::Language;
use autumnus::themes::Theme;
use autumnus::{themes, FormatterOption};
use comrak::adapters::SyntaxHighlighterAdapter;
use std::collections::HashMap;
use std::io::{self, Write};

#[derive(Debug)]
pub struct AutumnusAdapter<'a> {
    theme: &'a Theme,
    formatter_option: FormatterOption<'a>,
}

impl Default for AutumnusAdapter<'_> {
    fn default() -> Self {
        AutumnusAdapter {
            theme: themes::get("onedark").unwrap(),
            formatter_option: FormatterOption::default(),
        }
    }
}

impl<'a> AutumnusAdapter<'a> {
    pub fn new(theme: &'a str, inline_style: bool) -> Self {
        let theme: &'a Theme = match themes::get(theme) {
            Ok(theme) => theme,
            Err(_) => themes::get("onedark").unwrap(),
        };

        let formatter_option = if inline_style {
            FormatterOption::HtmlInline {
                pre_class: None,
                italic: false,
                include_highlights: false,
            }
        } else {
            FormatterOption::HtmlLinked { pre_class: None }
        };

        Self {
            theme,
            formatter_option,
        }
    }
}

impl SyntaxHighlighterAdapter for AutumnusAdapter<'_> {
    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Option<&str>,
        source: &str,
    ) -> io::Result<()> {
        let lang: Language = Language::guess(lang.unwrap_or(""), source);
        println!("source: {:?}", source);
        Ok(())
    }

    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        println!("pre_attributes: {:?}", attributes);

        match self.formatter_option {
            FormatterOption::HtmlInline { pre_class, .. } => {
                let formatter = HtmlInline::default()
                    .with_theme(Some(self.theme))
                    .with_pre_class(pre_class);

                write!(output, "{}", formatter.pre_tag())
            }
            FormatterOption::HtmlLinked { pre_class } => {
                let formatter = HtmlLinked::default().with_pre_class(pre_class);
                write!(output, "{}", formatter.pre_tag())
            }
            _ => {
                panic!("Formatter not supported");
            }
        }
    }

    fn write_code_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        println!("code_attributes: {:?}", attributes);

        let plaintext = "language-plaintext".to_string();
        let language = attributes.get("class").unwrap_or(&plaintext);
        let split: Vec<&str> = language.split('-').collect();
        let language = split.get(1).unwrap_or(&"plaintext");
        let lang: Language = Language::guess(language, "");

        match self.formatter_option {
            FormatterOption::HtmlInline { pre_class, .. } => {
                let formatter = HtmlInline::default()
                    .with_theme(Some(self.theme))
                    .with_lang(lang);

                write!(output, "{}", formatter.code_tag())
            }
            FormatterOption::HtmlLinked { pre_class } => {
                let formatter = HtmlLinked::default().with_lang(lang);
                write!(output, "{}", formatter.code_tag())
            }
            _ => {
                panic!("Formatter not supported");
            }
        }
    }
}
