use autumnus::formatter::HtmlFormatterBuilder;
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
        let html_formatter = HtmlFormatterBuilder::new()
            .with_formatter(self.formatter)
            .build();

        html_formatter.open_pre_tag(output)?;

        Ok(())
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

        let html_formatter = HtmlFormatterBuilder::new()
            .with_formatter(self.formatter)
            .with_lang(lang)
            .build();

        html_formatter.open_code_tag(output)?;

        Ok(())
    }

    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Option<&str>,
        source: &str,
    ) -> io::Result<()> {
        let lang: Language = Language::guess(lang.unwrap_or("plaintext"), source);

        let html_formatter = HtmlFormatterBuilder::new()
            .with_formatter(self.formatter)
            .with_lang(lang)
            .with_source(source)
            .build();

        html_formatter.highlights(output)?;

        Ok(())
    }
}
