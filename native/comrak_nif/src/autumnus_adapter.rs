use autumnus::themes;
use autumnus::themes::Theme;
use comrak::adapters::SyntaxHighlighterAdapter;
use std::collections::HashMap;
use std::io::{self, Write};

#[derive(Debug)]
pub struct AutumnusAdapter<'a> {
    theme: &'a Theme,
    inline_style: bool,
}

impl Default for AutumnusAdapter<'_> {
    fn default() -> Self {
        AutumnusAdapter {
            theme: themes::get("onedark").unwrap(),
            inline_style: true,
        }
    }
}

impl<'a> AutumnusAdapter<'a> {
    pub fn new(theme: &'a str, inline_style: bool) -> Self {
        let theme = match themes::get(theme) {
            Ok(theme) => theme,
            Err(_) => themes::get("onedark").unwrap(),
        };

        Self {
            theme,
            inline_style,
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
        Ok(())
    }

    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        _attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        write!(output, "{}", "")
    }

    fn write_code_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        write!(output, "{}", "")
    }
}
