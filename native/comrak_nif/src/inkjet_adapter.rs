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
}

impl<'a> InkjetAdapter<'a> {
    pub fn new(theme: &'a str) -> Self {
        let theme = match themes::theme(theme) {
            Some(theme) => theme,
            None => themes::theme("onedark").unwrap(),
        };

        Self { theme }
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
        let lang = lang.unwrap_or("diff");
        let lang = Language::from_token(lang).unwrap_or(Language::Diff);
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
            let inner_highlights = autumn::inner_highlights(source, event, self.theme);
            write!(output, "{}", inner_highlights)?
        }

        Ok(())
    }

    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        _attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        let pre_tag = autumn::open_pre_tag(self.theme, None);
        writeln!(output, "{}", pre_tag)
    }

    fn write_code_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        if attributes.contains_key("class") {
            // lang does not matter since class will be replaced
            let code_tag =
                autumn::open_code_tag(Language::Diff, Some(attributes["class"].as_str()));
            writeln!(output, "{}", code_tag)
        } else {
            // assume there's no language and fallbacks to plain text
            let code_tag = autumn::open_code_tag(Language::Diff, Some("language-plain-text"));
            writeln!(output, "{}", code_tag)
        }
    }
}
