use autumn::themes;
use autumn::themes::Theme;
use comrak::adapters::SyntaxHighlighterAdapter;
use inkjet::Language;
use std::collections::HashMap;
use std::io::{self, Write};
use tree_sitter_highlight::Highlighter;

#[derive(Debug)]
pub struct InkjetAdapter<'a> {
    theme: &'a Theme,
    inline_style: bool,
}

impl<'a> Default for InkjetAdapter<'a> {
    fn default() -> Self {
        let default_theme = themes::theme("onedark").unwrap();

        InkjetAdapter {
            theme: default_theme,
            inline_style: true,
        }
    }
}

impl<'a> InkjetAdapter<'a> {
    pub fn new(theme: &'a str, inline_style: bool) -> Self {
        let theme = match themes::theme(theme) {
            Some(theme) => theme,
            None => themes::theme("onedark").unwrap(),
        };

        Self {
            theme,
            inline_style,
        }
    }
}

impl<'a> SyntaxHighlighterAdapter for InkjetAdapter<'a> {
    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Option<&str>,
        source: &str,
    ) -> io::Result<()> {
        let mut highlighter = Highlighter::new();
        let lang = lang.unwrap_or("plaintext");
        let lang = Language::from_token(lang).unwrap_or(Language::Plaintext);
        let config = lang.config();

        let highlights = highlighter
            .highlight(
                config,
                source.as_bytes(),
                None,
                |token| match Language::from_token(token) {
                    Some(lang) => Some(lang.config()),
                    None => None,
                },
            )
            .expect("expected to generate the syntax highlight events");

        for event in highlights {
            let event = event.expect("expected a highlight event");
            let inner_highlights =
                autumn::inner_highlights(source, event, self.theme, self.inline_style);
            write!(output, "{}", inner_highlights)?
        }

        Ok(())
    }

    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        _attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        let pre_tag = autumn::open_pre_tag(self.theme, None, self.inline_style);
        write!(output, "{}", pre_tag)
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
        let language = Language::from_token(language).unwrap_or(Language::Plaintext);
        let code_tag = autumn::open_code_tag(language);
        write!(output, "{}", code_tag)
    }
}
