use autumnus::themes::Theme;
use autumnus::{themes, FormatterOption};
use comrak::adapters::SyntaxHighlighterAdapter;
use std::collections::HashMap;
use std::io::{self, Write};

#[derive(Debug)]
pub struct AutumnusAdapter<'a> {
    theme: Option<&'a Theme>,
    formatter: FormatterOption,
}

impl Default for AutumnusAdapter<'_> {
    fn default() -> Self {
        let theme = themes::get("onedark").ok();

        AutumnusAdapter {
            theme,
            formatter: FormatterOption::default(),
        }
    }
}

impl<'a> AutumnusAdapter<'a> {
    pub fn new(theme: Option<&'a Theme>, formatter: FormatterOption) -> Self {
        Self { theme, formatter }
    }
}

pub struct AutumnusAdapterBuilder {
    theme: Option<String>,
    inline: bool,
}

impl Default for AutumnusAdapterBuilder {
    fn default() -> Self {
        Self {
            theme: None,
            inline: true,
        }
    }
}

impl AutumnusAdapterBuilder {
    pub fn new() -> Self {
        Default::default()
    }

    pub fn theme(mut self, theme: Option<String>) -> Self {
        self.theme = theme;
        self
    }

    pub fn inline(mut self, inline: Option<bool>) -> Self {
        match inline {
            Some(inline) => self.inline = inline,
            None => self.inline = true,
        }
        self
    }

    pub fn build(self) -> AutumnusAdapter<'static> {
        let theme = match self.theme {
            Some(theme) => themes::get(&theme).ok(),
            None => None,
        };

        // TODO: attributes
        let formatter = match self.inline {
            true => FormatterOption::HtmlInline {
                pre_class: None,
                italic: false,
                include_highlights: false,
            },
            false => FormatterOption::HtmlLinked { pre_class: None },
        };

        AutumnusAdapter { theme, formatter }
    }
}

impl SyntaxHighlighterAdapter for AutumnusAdapter<'_> {
    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Option<&str>,
        code: &str,
    ) -> io::Result<()> {
        println!("lang: {:?}", lang);
        println!("code: {:?}", code);

        Ok(())
    }

    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        println!("attributes: {:?}", attributes);
        Ok(())
    }

    fn write_code_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> io::Result<()> {
        println!("attributes: {:?}", attributes);
        Ok(())
    }
}
