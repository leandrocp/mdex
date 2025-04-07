use autumnus::formatter::{Formatter, HtmlFormatter, HtmlInline, HtmlLinked};
use autumnus::languages::Language;
use autumnus::themes;
use autumnus::themes::Theme;
use comrak::adapters::SyntaxHighlighterAdapter;
use std::collections::HashMap;
use std::io::{self, Write};

#[derive(Debug)]
pub struct AutumnusAdapter<'a> {
    source: &'a str,
    lang: Language,
    theme: Option<&'a Theme>,
    inline_style: bool,
}

impl Default for AutumnusAdapter<'_> {
    fn default() -> Self {
        AutumnusAdapter {
            source: "",
            lang: Language::PlainText,
            theme: themes::get("onedark").ok(),
            inline_style: true,
        }
    }
}

impl<'a> AutumnusAdapter<'a> {
    pub fn new(theme: &'a str, inline_style: bool) -> Self {
        let theme: &'a Theme = match themes::get(theme) {
            Ok(theme) => theme,
            Err(_) => themes::get("onedark").unwrap(),
        };

        Self {
            source: "",
            lang: Language::PlainText,
            theme: Some(theme),
            inline_style,
        }
    }
}

impl SyntaxHighlighterAdapter for AutumnusAdapter<'_> {
    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        if self.inline_style {
            let formatter = HtmlInline::default().with_theme(self.theme);
            write!(output, "{}", formatter.pre_tag())
        } else {
            let formatter = HtmlLinked::default();
            write!(output, "{}", formatter.pre_tag())
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
        let lang: Language = Language::guess(language, self.source);

        if self.inline_style {
            let formatter = HtmlInline::default().with_theme(self.theme).with_lang(lang);
            write!(output, "{}", formatter.code_tag())
        } else {
            let formatter = HtmlLinked::default().with_lang(lang);
            write!(output, "{}", formatter.code_tag())
        }
    }

    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Option<&str>,
        source: &str,
    ) -> io::Result<()> {
        let lang: Language = Language::guess(lang.unwrap_or("plaintext"), source);
        if self.inline_style {
            let formatter = HtmlInline::default()
                .with_theme(self.theme)
                .with_lang(lang)
                .with_source(source);

            write!(output, "{}", formatter.highlights())
        } else {
            let formatter = HtmlLinked::default().with_lang(lang).with_source(source);

            write!(output, "{}", formatter.highlights())
        }
    }
}
