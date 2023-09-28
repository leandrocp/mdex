use crate::themes;
use crate::themes::Theme;
use comrak::adapters::SyntaxHighlighterAdapter;
use inkjet::Language;
use std::collections::HashMap;
use std::io::{self, Write};
use tree_sitter_highlight::{HighlightEvent, Highlighter};

#[derive(Debug)]
pub struct InkjetAdapter<'a> {
    theme: &'a Theme,
}

impl<'a> InkjetAdapter<'a> {
    pub fn new(theme: &'a str) -> Self {
        let theme = match themes::theme(theme) {
            Some(theme) => theme,
            None => themes::theme("onedark").unwrap(),
        };

        Self { theme }
    }

    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Language,
        code: &str,
    ) -> io::Result<()> {
        let mut highlighter = Highlighter::new();
        let config = lang.config();

        let highlights = highlighter
            .highlight(config, code.as_bytes(), None, |_| None)
            .unwrap();

        for event in highlights {
            match event.unwrap() {
                HighlightEvent::Source { start, end } => {
                    let span = code
                        .get(start..end)
                        .expect("Source bounds should be in bounds!");
                    let span = v_htmlescape::escape(span).to_string();
                    write!(output, "{}", span)?
                }
                HighlightEvent::HighlightStart(idx) => {
                    let scope = inkjet::constants::HIGHLIGHT_NAMES[idx.0];
                    let (class, style) = self.theme.get_scope(scope);
                    write!(output, "<span class=\"{}\" style=\"{}\">", class, style)?
                }
                HighlightEvent::HighlightEnd => write!(output, "</span>")?,
            }
        }

        Ok(())
    }

    fn write_plain_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Language,
        code: &str,
    ) -> io::Result<()> {
        let mut highlighter = Highlighter::new();
        let config = lang.config();

        let highlights = highlighter
            .highlight(config, code.as_bytes(), None, |_| None)
            .unwrap();

        for event in highlights {
            match event.unwrap() {
                HighlightEvent::Source { start, end } => {
                    let span = code
                        .get(start..end)
                        .expect("Source bounds should be in bounds!");
                    let span = v_htmlescape::escape(span).to_string();
                    write!(output, "{}", span)?
                }
                HighlightEvent::HighlightStart(_idx) => write!(output, "<span>")?,
                HighlightEvent::HighlightEnd => write!(output, "</span>")?,
            }
        }

        Ok(())
    }
}

impl<'a> SyntaxHighlighterAdapter for InkjetAdapter<'a> {
    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Option<&str>,
        code: &str,
    ) -> io::Result<()> {
        let lang = lang.unwrap_or("plain");

        match Language::from_token(lang) {
            Some(lang_config) => self.write_highlighted(output, lang_config, code)?,
            None => self.write_plain_highlighted(output, Language::Diff, code)?,
        };

        Ok(())
    }

    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        _attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        let (_class, background_style) = self.theme.get_scope("background");
        let (_class, text_style) = self.theme.get_scope("text");

        writeln!(
            output,
            "<pre class=\"autumn highlight\" style=\"{} {}\">",
            background_style, text_style
        )
    }

    fn write_code_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        if attributes.contains_key("class") {
            write!(output, "<code class=\"{}\">", attributes["class"])
        } else {
            write!(output, "<code>")
        }
    }
}
