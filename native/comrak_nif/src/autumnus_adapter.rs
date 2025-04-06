use autumnus::formatter::{Formatter, HtmlFormatter, HtmlInline, HtmlLinked};
use autumnus::languages::Language;
use autumnus::themes;
use autumnus::themes::Theme;
use comrak::adapters::SyntaxHighlighterAdapter;
use std::collections::HashMap;
use std::io::{self, Write};
use std::sync::RwLock;

#[derive(Debug)]
pub enum FormatterType<'a> {
    Inline(HtmlInline<'a>),
    Linked(HtmlLinked<'a>),
}

#[derive(Debug)]
pub struct AutumnusAdapter<'a> {
    theme: &'a Theme,
    formatter: RwLock<FormatterType<'a>>,
}

impl Default for AutumnusAdapter<'_> {
    fn default() -> Self {
        AutumnusAdapter {
            theme: themes::get("onedark").unwrap(),
            formatter: RwLock::new(FormatterType::Inline(HtmlInline::default())),
        }
    }
}

impl<'a> AutumnusAdapter<'a> {
    pub fn new(theme: &'a str, inline_style: bool) -> Self {
        let theme: &'a Theme = match themes::get(theme) {
            Ok(theme) => theme,
            Err(_) => themes::get("onedark").unwrap(),
        };

        let formatter = if inline_style {
            FormatterType::Inline(HtmlInline::default().with_theme(Some(theme)))
        } else {
            FormatterType::Linked(HtmlLinked::default())
        };

        Self {
            theme,
            formatter: RwLock::new(formatter),
        }
    }
}

impl SyntaxHighlighterAdapter for AutumnusAdapter<'_> {
    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        println!("pre_attributes: {:?}", attributes);

        let mut formatter = self.formatter.write().unwrap();

        match &mut *formatter {
            FormatterType::Inline(formatter) => {
                let formatter = formatter.clone();
                write!(output, "{}", formatter.pre_tag())
            }
            FormatterType::Linked(formatter) => {
                let formatter = formatter.clone();
                write!(output, "{}", formatter.pre_tag())
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

        let mut formatter = self.formatter.write().unwrap();
        match &mut *formatter {
            FormatterType::Inline(formatter) => {
                let mut formatter = formatter.clone();
                formatter = formatter.with_lang(lang);
                write!(output, "{}", formatter.code_tag())
            }
            FormatterType::Linked(formatter) => {
                let mut formatter = formatter.clone();
                formatter = formatter.with_lang(lang);
                write!(output, "{}", formatter.code_tag())
            }
        }
    }

    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        _lang: Option<&str>,
        source: &str,
    ) -> io::Result<()> {
        let mut formatter = self.formatter.write().unwrap();
        match &mut *formatter {
            FormatterType::Inline(formatter) => {
                let mut formatter = formatter.clone();
                formatter = formatter.with_source(source);
                write!(output, "{}", formatter.highlights())
            }
            FormatterType::Linked(formatter) => {
                let mut formatter = formatter.clone();
                formatter = formatter.with_source(source);
                write!(output, "{}", formatter.highlights())
            }
        }
    }
}
