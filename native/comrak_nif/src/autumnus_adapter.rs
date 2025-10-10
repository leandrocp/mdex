use anyhow::{Context, Result};
use autumnus::formatter::html_inline::{
    HighlightLines as HtmlInlineHighlightLines, HighlightLinesStyle,
};
use autumnus::formatter::html_linked::HighlightLines as HtmlLinkedHighlightLines;
use autumnus::formatter::{
    Formatter, HtmlFormatter, HtmlInlineBuilder, HtmlLinkedBuilder, TerminalBuilder,
};
use autumnus::languages::Language;
use autumnus::FormatterOption;
use comrak::adapters::SyntaxHighlighterAdapter;
use std::collections::HashMap;
use std::fmt::Write;
use std::io;
use std::sync::Mutex;

struct FmtToIoAdapter<'a, W: Write + ?Sized>(&'a mut W);

impl<'a, W: Write + ?Sized> io::Write for FmtToIoAdapter<'a, W> {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        let s =
            std::str::from_utf8(buf).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
        self.0
            .write_str(s)
            .map_err(|_| io::Error::other("write error"))?;
        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

pub struct AutumnusAdapter<'a> {
    formatter: FormatterOption<'a>,
    stored_attrs: Mutex<Option<HashMap<String, String>>>,
    stored_lang: Mutex<Option<Language>>,
}

impl Default for AutumnusAdapter<'_> {
    fn default() -> Self {
        Self {
            formatter: FormatterOption::HtmlInline {
                theme: None,
                pre_class: None,
                italic: false,
                include_highlights: false,
                highlight_lines: None,
                header: None,
            },
            stored_attrs: Mutex::new(None),
            stored_lang: Mutex::new(None),
        }
    }
}

impl<'a> AutumnusAdapter<'a> {
    pub fn new(formatter: FormatterOption<'a>) -> Self {
        Self {
            formatter,
            stored_attrs: Mutex::new(None),
            stored_lang: Mutex::new(None),
        }
    }

    fn parse_custom_attributes(info_string: &str) -> Option<HashMap<String, String>> {
        let tokens = shlex::split(info_string)?;
        if tokens.is_empty() {
            return None;
        }

        let mut attributes = HashMap::with_capacity(tokens.len());
        for token in tokens {
            if let Some((key, value)) = token.split_once('=') {
                attributes.insert(key.trim().to_string(), value.to_string());
            } else {
                // Handle standalone flags (e.g., "include_highlights" without "=true")
                attributes.insert(token.trim().to_string(), "true".to_string());
            }
        }

        if attributes.is_empty() {
            None
        } else {
            Some(attributes)
        }
    }

    fn parse_highlight_lines(&self, lines_str: &str) -> Vec<std::ops::RangeInclusive<usize>> {
        lines_str
            .split(',')
            .filter_map(|part| {
                let part = part.trim();
                if let Some((start, end)) = part.split_once('-') {
                    match (start.trim().parse::<usize>(), end.trim().parse::<usize>()) {
                        (Ok(start_num), Ok(end_num)) => Some(start_num..=end_num),
                        _ => None,
                    }
                } else {
                    part.parse::<usize>().ok().map(|n| n..=n)
                }
            })
            .collect()
    }

    fn resolve_theme(
        attrs: &HashMap<String, String>,
    ) -> Result<Option<&'static autumnus::themes::Theme>> {
        match attrs.get("theme") {
            Some(theme_name) => autumnus::themes::get(theme_name)
                .map(Some)
                .with_context(|| format!("Invalid theme: {theme_name}")),
            None => Ok(None),
        }
    }

    fn configure_html_inline_builder(
        &self,
        base_config: &FormatterOption<'a>,
        lang: Option<Language>,
        source: Option<&'a str>,
        custom_attrs: Option<&'a HashMap<String, String>>,
    ) -> Result<HtmlInlineBuilder<'a>, std::fmt::Error> {
        let mut builder = HtmlInlineBuilder::default();

        let custom_theme = custom_attrs.and_then(|attrs| Self::resolve_theme(attrs).ok().flatten());

        if let FormatterOption::HtmlInline {
            theme,
            pre_class,
            italic,
            include_highlights,
            highlight_lines,
            header,
        } = base_config
        {
            builder.italic(*italic);
            builder.include_highlights(*include_highlights);

            if let Some(theme) = custom_theme.or(*theme) {
                builder.theme(Some(theme));
            }

            if let Some(pre_class) = pre_class {
                builder.pre_class(Some(pre_class));
            }

            if let Some(highlight_lines) = highlight_lines {
                builder.highlight_lines(Some(highlight_lines.clone()));
            }

            if let Some(header) = header {
                builder.header(Some(header.clone()));
            }
        }

        if let Some(attrs) = custom_attrs {
            if let Some(pre_class) = attrs.get("pre_class") {
                builder.pre_class(Some(pre_class));
            }

            if let Some(include_highlights_str) = attrs.get("include_highlights") {
                if include_highlights_str == "true" {
                    builder.include_highlights(true);
                }
            }

            if let Some(highlight_lines_str) = attrs.get("highlight_lines") {
                let lines = self.parse_highlight_lines(highlight_lines_str);
                let style = match attrs.get("highlight_lines_style") {
                    Some(style) if style == "theme" => Some(HighlightLinesStyle::Theme),
                    Some(custom_style) => Some(HighlightLinesStyle::Style(custom_style.clone())),
                    None => Some(HighlightLinesStyle::Theme),
                };
                let class = attrs.get("highlight_lines_class").cloned();

                let highlight_lines = HtmlInlineHighlightLines {
                    lines,
                    style,
                    class,
                };
                builder.highlight_lines(Some(highlight_lines));
            }
        }

        if let Some(lang) = lang {
            builder.lang(lang);
        }

        if let Some(source) = source {
            builder.source(source);
        }

        Ok(builder)
    }

    fn configure_html_linked_builder(
        &self,
        base_config: &FormatterOption<'a>,
        lang: Option<Language>,
        source: Option<&'a str>,
        custom_attrs: Option<&'a HashMap<String, String>>,
    ) -> Result<HtmlLinkedBuilder<'a>, std::fmt::Error> {
        let mut builder = HtmlLinkedBuilder::default();

        if let FormatterOption::HtmlLinked {
            pre_class,
            highlight_lines,
            header,
        } = base_config
        {
            if let Some(pre_class) = pre_class {
                builder.pre_class(Some(pre_class));
            }

            if let Some(highlight_lines) = highlight_lines {
                builder.highlight_lines(Some(highlight_lines.clone()));
            }

            if let Some(header) = header {
                builder.header(Some(header.clone()));
            }
        }

        if let Some(attrs) = custom_attrs {
            if let Some(pre_class) = attrs.get("pre_class") {
                builder.pre_class(Some(pre_class));
            }

            if let Some(highlight_lines_str) = attrs.get("highlight_lines") {
                let lines = self.parse_highlight_lines(highlight_lines_str);
                let mut highlight_lines = HtmlLinkedHighlightLines {
                    lines,
                    ..Default::default()
                };

                if let Some(class_str) = attrs.get("highlight_lines_class") {
                    highlight_lines.class = class_str.clone();
                }
                builder.highlight_lines(Some(highlight_lines));
            }
        }

        if let Some(lang) = lang {
            builder.lang(lang);
        }

        if let Some(source) = source {
            builder.source(source);
        }

        Ok(builder)
    }

    fn configure_terminal_builder(
        &self,
        base_config: &FormatterOption<'a>,
        lang: Option<Language>,
        source: Option<&'a str>,
        custom_attrs: Option<&'a HashMap<String, String>>,
    ) -> Result<TerminalBuilder<'a>, std::fmt::Error> {
        let mut builder = TerminalBuilder::default();

        let custom_theme = custom_attrs.and_then(|attrs| Self::resolve_theme(attrs).ok().flatten());

        if let FormatterOption::Terminal { theme } = base_config {
            if let Some(theme) = custom_theme.or(*theme) {
                builder.theme(Some(theme));
            }
        }

        if let Some(lang) = lang {
            builder.lang(lang);
        }

        if let Some(source) = source {
            builder.source(source);
        }

        Ok(builder)
    }

    fn get_custom_attrs(attributes: &HashMap<String, String>) -> Option<HashMap<String, String>> {
        attributes
            .get("data-meta")
            .and_then(|info| Self::parse_custom_attributes(info))
    }

    fn get_language(attributes: &HashMap<String, String>) -> Language {
        if let Some(lang) = attributes.get("lang") {
            Language::guess(lang, "")
        } else if let Some(class) = attributes.get("class") {
            let language = class.strip_prefix("language-").unwrap_or("plaintext");
            Language::guess(language, "")
        } else {
            Language::guess("plaintext", "")
        }
    }
}

impl SyntaxHighlighterAdapter for AutumnusAdapter<'_> {
    fn write_pre_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> std::fmt::Result {
        let custom_attrs = Self::get_custom_attrs(&attributes);
        let lang = attributes.get("lang").map(|l| Language::guess(l, ""));

        if let Some(attrs) = &custom_attrs {
            *self.stored_attrs.lock().unwrap() = Some(attrs.clone());
        }
        if let Some(language) = lang {
            *self.stored_lang.lock().unwrap() = Some(language);
        }

        match &self.formatter {
            FormatterOption::HtmlInline { .. } => {
                let builder = self.configure_html_inline_builder(
                    &self.formatter,
                    lang,
                    None,
                    custom_attrs.as_ref(),
                )?;
                let formatter = builder.build().map_err(|_| std::fmt::Error)?;
                let mut adapter = FmtToIoAdapter(output);
                formatter
                    .open_pre_tag(&mut adapter)
                    .map_err(|_| std::fmt::Error)
            }
            FormatterOption::HtmlLinked { .. } => {
                let builder = self.configure_html_linked_builder(
                    &self.formatter,
                    lang,
                    None,
                    custom_attrs.as_ref(),
                )?;
                let formatter = builder.build().map_err(|_| std::fmt::Error)?;
                let mut adapter = FmtToIoAdapter(output);
                formatter
                    .open_pre_tag(&mut adapter)
                    .map_err(|_| std::fmt::Error)
            }
            FormatterOption::Terminal { .. } => Ok(()),
        }
    }

    fn write_code_tag(
        &self,
        output: &mut dyn Write,
        attributes: HashMap<String, String>,
    ) -> std::fmt::Result {
        let custom_attrs = Self::get_custom_attrs(&attributes);
        let lang = Self::get_language(&attributes);

        if let Some(attrs) = &custom_attrs {
            *self.stored_attrs.lock().unwrap() = Some(attrs.clone());
        }
        if !attributes.is_empty() {
            *self.stored_lang.lock().unwrap() = Some(lang);
        }

        let stored_attrs = self.stored_attrs.lock().unwrap().clone();
        let stored_lang = *self.stored_lang.lock().unwrap();

        let effective_lang = stored_lang.or(Some(lang));

        match &self.formatter {
            FormatterOption::HtmlInline { .. } => {
                let builder = self.configure_html_inline_builder(
                    &self.formatter,
                    effective_lang,
                    None,
                    stored_attrs.as_ref(),
                )?;
                let formatter = builder.build().map_err(|_| std::fmt::Error)?;
                let mut adapter = FmtToIoAdapter(output);
                formatter
                    .open_code_tag(&mut adapter)
                    .map_err(|_| std::fmt::Error)
            }
            FormatterOption::HtmlLinked { .. } => {
                let builder = self.configure_html_linked_builder(
                    &self.formatter,
                    effective_lang,
                    None,
                    stored_attrs.as_ref(),
                )?;
                let formatter = builder.build().map_err(|_| std::fmt::Error)?;
                let mut adapter = FmtToIoAdapter(output);
                formatter
                    .open_code_tag(&mut adapter)
                    .map_err(|_| std::fmt::Error)
            }
            FormatterOption::Terminal { .. } => Ok(()),
        }
    }

    fn write_highlighted(
        &self,
        output: &mut dyn Write,
        lang: Option<&str>,
        source: &str,
    ) -> std::fmt::Result {
        let stored_attrs = self.stored_attrs.lock().unwrap().clone();
        let stored_lang = *self.stored_lang.lock().unwrap();

        let language = if let Some(stored_lang) = stored_lang {
            stored_lang
        } else if let Some(lang_str) = lang {
            Language::guess(lang_str, source)
        } else {
            Language::guess("plaintext", source)
        };

        match &self.formatter {
            FormatterOption::HtmlInline { .. } => {
                let builder = self.configure_html_inline_builder(
                    &self.formatter,
                    Some(language),
                    Some(source),
                    stored_attrs.as_ref(),
                )?;
                let formatter = builder.build().map_err(|_| std::fmt::Error)?;
                let mut adapter = FmtToIoAdapter(output);
                formatter
                    .highlights(&mut adapter)
                    .map_err(|_| std::fmt::Error)
            }
            FormatterOption::HtmlLinked { .. } => {
                let builder = self.configure_html_linked_builder(
                    &self.formatter,
                    Some(language),
                    Some(source),
                    stored_attrs.as_ref(),
                )?;
                let formatter = builder.build().map_err(|_| std::fmt::Error)?;
                let mut adapter = FmtToIoAdapter(output);
                formatter
                    .highlights(&mut adapter)
                    .map_err(|_| std::fmt::Error)
            }
            FormatterOption::Terminal { .. } => {
                let builder = self.configure_terminal_builder(
                    &self.formatter,
                    Some(language),
                    Some(source),
                    stored_attrs.as_ref(),
                )?;
                let formatter = builder.build().map_err(|_| std::fmt::Error)?;
                let mut adapter = FmtToIoAdapter(output);
                formatter
                    .highlights(&mut adapter)
                    .map_err(|_| std::fmt::Error)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    #[cfg(test)]
    use pretty_assertions::assert_str_eq;

    use super::*;
    use autumnus::formatter::html_inline::{
        HighlightLines as HtmlInlineHighlightLines, HighlightLinesStyle,
    };
    use autumnus::formatter::html_linked::HighlightLines as HtmlLinkedHighlightLines;
    use autumnus::formatter::HtmlElement;
    use autumnus::{themes, FormatterOption};
    use comrak::{format_html_with_plugins, parse_document, Arena, ComrakPlugins, Options};

    fn run_test(markdown: &str, formatter: FormatterOption<'static>, options: Options) -> String {
        let arena = Arena::new();
        let root = parse_document(&arena, markdown, &options);
        let adapter = AutumnusAdapter::new(formatter);

        let plugins = ComrakPlugins {
            render: comrak::RenderPlugins {
                codefence_syntax_highlighter: Some(&adapter),
                ..Default::default()
            },
        };

        let mut html = String::new();
        format_html_with_plugins(root, &options, &mut html, &plugins)
            .expect("Failed to format HTML with plugins");

        html
    }

    fn default_options() -> Options<'static> {
        Options::default()
    }

    #[test]
    fn test_default_formatter_option() {
        let markdown = r#"
```rust
fn main() {
    let message = "Hello, world!";
}
```
"#;

        let theme = themes::get("nord").expect("Theme not found");
        let formatter = FormatterOption::default();
        let output = run_test(markdown, FormatterOption::default(), Options::default());

        let expected = r#"<pre class="athl"><code class="language-rust" translate="no" tabindex="0"><div class="line" data-line="1"><span >fn</span> <span >main</span><span >(</span><span >)</span> <span >&lbrace;</span>
</div><div class="line" data-line="2">    <span >let</span> <span >message</span> <span >=</span> <span >&quot;Hello, world!&quot;</span><span >;</span>
</div><div class="line" data-line="3"><span >&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }

    #[test]
    fn test_html_inline_no_attrs() {
        let markdown = r#"
```rust
fn main() {
    let message = "Hello, world!";
}
```
"#;

        let formatter = FormatterOption::HtmlInline {
            theme: None,
            pre_class: None,
            italic: false,
            include_highlights: false,
            highlight_lines: None,
            header: None,
        };

        let output = run_test(markdown, formatter, Options::default());

        let expected = r#"<pre class="athl"><code class="language-rust" translate="no" tabindex="0"><div class="line" data-line="1"><span >fn</span> <span >main</span><span >(</span><span >)</span> <span >&lbrace;</span>
</div><div class="line" data-line="2">    <span >let</span> <span >message</span> <span >=</span> <span >&quot;Hello, world!&quot;</span><span >;</span>
</div><div class="line" data-line="3"><span >&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }

    #[test]
    fn test_html_inline_all_attrs() {
        let markdown = r#"
```rust
fn main() {
    let a = 1;
    let b = 2;
    let sum = a + b;
}
```
"#;

        let theme = themes::get("nord").expect("Theme not found");
        let highlight_lines = HtmlInlineHighlightLines {
            lines: vec![1..=1, 3..=4],
            style: Some(HighlightLinesStyle::Theme),
            class: None,
        };
        let header = HtmlElement {
            open_tag: "<div class=\"code-header\">Rust Code</div>".to_string(),
            close_tag: "</div>".to_string(),
        };

        let formatter = FormatterOption::HtmlInline {
            theme: Some(theme),
            pre_class: Some("custom-pre-class"),
            italic: true,
            include_highlights: true,
            highlight_lines: Some(highlight_lines),
            header: Some(header),
        };

        let output = run_test(markdown, formatter, Options::default());

        let expected = r#"<pre class="athl custom-pre-class" style="color: #d8dee9; background-color: #2e3440;"><code class="language-rust" translate="no" tabindex="0"><div class="line" style="background-color: #3b4252;" data-line="1"><span data-highlight="keyword.function" style="color: #88c0d0; font-style: italic;">fn</span> <span data-highlight="function" style="color: #88c0d0; font-style: italic;">main</span><span data-highlight="punctuation.bracket" style="color: #88c0d0;">(</span><span data-highlight="punctuation.bracket" style="color: #88c0d0;">)</span> <span data-highlight="punctuation.bracket" style="color: #88c0d0;">&lbrace;</span>
</div><div class="line" data-line="2">    <span data-highlight="keyword" style="color: #81a1c1; font-style: italic;">let</span> <span data-highlight="variable" style="color: #d8dee9; font-weight: bold;">a</span> <span data-highlight="operator" style="color: #81a1c1;">=</span> <span data-highlight="number" style="color: #b48ead;">1</span><span data-highlight="punctuation.delimiter" style="color: #88c0d0;">;</span>
</div><div class="line" style="background-color: #3b4252;" data-line="3">    <span data-highlight="keyword" style="color: #81a1c1; font-style: italic;">let</span> <span data-highlight="variable" style="color: #d8dee9; font-weight: bold;">b</span> <span data-highlight="operator" style="color: #81a1c1;">=</span> <span data-highlight="number" style="color: #b48ead;">2</span><span data-highlight="punctuation.delimiter" style="color: #88c0d0;">;</span>
</div><div class="line" style="background-color: #3b4252;" data-line="4">    <span data-highlight="keyword" style="color: #81a1c1; font-style: italic;">let</span> <span data-highlight="variable" style="color: #d8dee9; font-weight: bold;">sum</span> <span data-highlight="operator" style="color: #81a1c1;">=</span> <span data-highlight="variable" style="color: #d8dee9; font-weight: bold;">a</span> <span data-highlight="operator" style="color: #81a1c1;">+</span> <span data-highlight="variable" style="color: #d8dee9; font-weight: bold;">b</span><span data-highlight="punctuation.delimiter" style="color: #88c0d0;">;</span>
</div><div class="line" data-line="5"><span data-highlight="punctuation.bracket" style="color: #88c0d0;">&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }

    #[test]
    fn test_html_inline_decorators() {
        let markdown = r#"
```rust pre_class="my-custom-pre extra-class" theme=github_light include_highlights highlight_lines="1,3-5" highlight_lines_style="background-color: #ffffcc; border-left: 3px solid #ff0000" highlight_lines_class="custom-highlight-class"
fn main() {
    let x = 1;
    let y = 2;
    let z = 3;
    let message = "Hello, world!";
}
```
"#;

        let nord_theme = themes::get("nord").expect("Nord theme not found");
        let formatter = FormatterOption::HtmlInline {
            theme: Some(nord_theme),
            pre_class: Some("default-pre-class"),
            italic: true,
            include_highlights: false,
            highlight_lines: Some(HtmlInlineHighlightLines {
                lines: vec![2..=2],
                style: Some(HighlightLinesStyle::Theme),
                class: Some("default-highlight".to_string()),
            }),
            header: Some(HtmlElement {
                open_tag: "<div class=\"header\">Header</div>".to_string(),
                close_tag: "</div>".to_string(),
            }),
        };

        let mut options = Options::default();
        options.render.github_pre_lang = true;
        options.render.full_info_string = true;

        let output = run_test(markdown, formatter, options);

        let expected = r#"<pre class="athl my-custom-pre extra-class" style="color: #1f2328; background-color: #ffffff;"><code class="language-rust" translate="no" tabindex="0"><div class="line custom-highlight-class" style="background-color: #ffffcc; border-left: 3px solid #ff0000" data-line="1"><span data-highlight="keyword.function" style="color: #cf222e;">fn</span> <span data-highlight="function" style="color: #6639ba;">main</span><span data-highlight="punctuation.bracket" style="color: #1f2328;">(</span><span data-highlight="punctuation.bracket" style="color: #1f2328;">)</span> <span data-highlight="punctuation.bracket" style="color: #1f2328;">&lbrace;</span>
</div><div class="line" data-line="2">    <span data-highlight="keyword" style="color: #cf222e;">let</span> <span data-highlight="variable" style="color: #1f2328;">x</span> <span data-highlight="operator" style="color: #0550ae;">=</span> <span data-highlight="number" style="color: #0550ae;">1</span><span data-highlight="punctuation.delimiter" style="color: #1f2328;">;</span>
</div><div class="line custom-highlight-class" style="background-color: #ffffcc; border-left: 3px solid #ff0000" data-line="3">    <span data-highlight="keyword" style="color: #cf222e;">let</span> <span data-highlight="variable" style="color: #1f2328;">y</span> <span data-highlight="operator" style="color: #0550ae;">=</span> <span data-highlight="number" style="color: #0550ae;">2</span><span data-highlight="punctuation.delimiter" style="color: #1f2328;">;</span>
</div><div class="line custom-highlight-class" style="background-color: #ffffcc; border-left: 3px solid #ff0000" data-line="4">    <span data-highlight="keyword" style="color: #cf222e;">let</span> <span data-highlight="variable" style="color: #1f2328;">z</span> <span data-highlight="operator" style="color: #0550ae;">=</span> <span data-highlight="number" style="color: #0550ae;">3</span><span data-highlight="punctuation.delimiter" style="color: #1f2328;">;</span>
</div><div class="line custom-highlight-class" style="background-color: #ffffcc; border-left: 3px solid #ff0000" data-line="5">    <span data-highlight="keyword" style="color: #cf222e;">let</span> <span data-highlight="variable" style="color: #1f2328;">message</span> <span data-highlight="operator" style="color: #0550ae;">=</span> <span data-highlight="string" style="color: #0a3069;">&quot;Hello, world!&quot;</span><span data-highlight="punctuation.delimiter" style="color: #1f2328;">;</span>
</div><div class="line" data-line="6"><span data-highlight="punctuation.bracket" style="color: #1f2328;">&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }

    #[test]
    fn test_html_inline_decorators_without_github_pre_lang() {
        let markdown = r#"
```rust pre_class="custom-class" highlight_lines="1,3" theme=github_light
fn main() {
    let x = 1;
    let message = "Hello, world!";
}
```
"#;

        let nord_theme = themes::get("nord").expect("Nord theme not found");
        let formatter = FormatterOption::HtmlInline {
            theme: Some(nord_theme),
            pre_class: Some("default-class"),
            italic: false,
            include_highlights: true,
            highlight_lines: None,
            header: None,
        };

        let mut options = Options::default();
        options.render.github_pre_lang = false;
        options.render.full_info_string = true;

        let output = run_test(markdown, formatter, options);

        let expected = r#"<pre class="athl default-class" style="color: #d8dee9; background-color: #2e3440;"><code class="language-rust" translate="no" tabindex="0"><div class="line" style="background-color: #e7eaf0;" data-line="1"><span data-highlight="keyword.function" style="color: #cf222e;">fn</span> <span data-highlight="function" style="color: #6639ba;">main</span><span data-highlight="punctuation.bracket" style="color: #1f2328;">(</span><span data-highlight="punctuation.bracket" style="color: #1f2328;">)</span> <span data-highlight="punctuation.bracket" style="color: #1f2328;">&lbrace;</span>
</div><div class="line" data-line="2">    <span data-highlight="keyword" style="color: #cf222e;">let</span> <span data-highlight="variable" style="color: #1f2328;">x</span> <span data-highlight="operator" style="color: #0550ae;">=</span> <span data-highlight="number" style="color: #0550ae;">1</span><span data-highlight="punctuation.delimiter" style="color: #1f2328;">;</span>
</div><div class="line" style="background-color: #e7eaf0;" data-line="3">    <span data-highlight="keyword" style="color: #cf222e;">let</span> <span data-highlight="variable" style="color: #1f2328;">message</span> <span data-highlight="operator" style="color: #0550ae;">=</span> <span data-highlight="string" style="color: #0a3069;">&quot;Hello, world!&quot;</span><span data-highlight="punctuation.delimiter" style="color: #1f2328;">;</span>
</div><div class="line" data-line="4"><span data-highlight="punctuation.bracket" style="color: #1f2328;">&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }

    #[test]
    fn test_html_linked_no_attrs() {
        let markdown = r#"
```rust
fn main() {
    let message = "Hello, world!";
}
```
"#;

        let formatter = FormatterOption::HtmlLinked {
            pre_class: None,
            highlight_lines: None,
            header: None,
        };

        let output = run_test(markdown, formatter, Options::default());

        let expected = r#"<pre class="athl"><code class="language-rust" translate="no" tabindex="0"><div class="line" data-line="1"><span class="keyword-function">fn</span> <span class="function">main</span><span class="punctuation-bracket">(</span><span class="punctuation-bracket">)</span> <span class="punctuation-bracket">&lbrace;</span>
</div><div class="line" data-line="2">    <span class="keyword">let</span> <span class="variable">message</span> <span class="operator">=</span> <span class="string">&quot;Hello, world!&quot;</span><span class="punctuation-delimiter">;</span>
</div><div class="line" data-line="3"><span class="punctuation-bracket">&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }

    #[test]
    fn test_html_linked_all_attrs() {
        let markdown = r#"
```rust
fn main() {
    let a = 1;
    let b = 2;
    let sum = a + b;
}
```
"#;

        let highlight_lines = HtmlLinkedHighlightLines {
            lines: vec![1..=1, 3..=4],
            class: "highlighted-line".to_string(),
        };
        let header = HtmlElement {
            open_tag: "<div class=\"linked-header\">Linked Code</div>".to_string(),
            close_tag: "</div>".to_string(),
        };

        let formatter = FormatterOption::HtmlLinked {
            pre_class: Some("custom-linked-class"),
            highlight_lines: Some(highlight_lines),
            header: Some(header),
        };

        let output = run_test(markdown, formatter, Options::default());

        let expected = r#"<pre class="athl custom-linked-class"><code class="language-rust" translate="no" tabindex="0"><div class="line highlighted-line" data-line="1"><span class="keyword-function">fn</span> <span class="function">main</span><span class="punctuation-bracket">(</span><span class="punctuation-bracket">)</span> <span class="punctuation-bracket">&lbrace;</span>
</div><div class="line" data-line="2">    <span class="keyword">let</span> <span class="variable">a</span> <span class="operator">=</span> <span class="number">1</span><span class="punctuation-delimiter">;</span>
</div><div class="line highlighted-line" data-line="3">    <span class="keyword">let</span> <span class="variable">b</span> <span class="operator">=</span> <span class="number">2</span><span class="punctuation-delimiter">;</span>
</div><div class="line highlighted-line" data-line="4">    <span class="keyword">let</span> <span class="variable">sum</span> <span class="operator">=</span> <span class="variable">a</span> <span class="operator">+</span> <span class="variable">b</span><span class="punctuation-delimiter">;</span>
</div><div class="line" data-line="5"><span class="punctuation-bracket">&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }

    #[test]
    fn test_html_linked_decorators() {
        let markdown = r#"
```rust pre_class="custom-linked-pre extra-linked" highlight_lines="1-2,4-5" highlight_lines_class="my-custom-highlight-line"
fn main() {
    let x = 1;
    let y = 2;
    let z = 3;
    let message = "Hello, world!";
}
```
"#;

        let formatter = FormatterOption::HtmlLinked {
            pre_class: Some("default-linked-pre"),
            highlight_lines: Some(HtmlLinkedHighlightLines {
                lines: vec![3..=3],
                class: "default-highlight-line".to_string(),
            }),
            header: Some(HtmlElement {
                open_tag: "<div class=\"linked-header\">Linked Header</div>".to_string(),
                close_tag: "</div>".to_string(),
            }),
        };

        let mut options = Options::default();
        options.render.github_pre_lang = true;
        options.render.full_info_string = true;

        let output = run_test(markdown, formatter, options);

        let expected = r#"<pre class="athl custom-linked-pre extra-linked"><code class="language-rust" translate="no" tabindex="0"><div class="line my-custom-highlight-line" data-line="1"><span class="keyword-function">fn</span> <span class="function">main</span><span class="punctuation-bracket">(</span><span class="punctuation-bracket">)</span> <span class="punctuation-bracket">&lbrace;</span>
</div><div class="line my-custom-highlight-line" data-line="2">    <span class="keyword">let</span> <span class="variable">x</span> <span class="operator">=</span> <span class="number">1</span><span class="punctuation-delimiter">;</span>
</div><div class="line" data-line="3">    <span class="keyword">let</span> <span class="variable">y</span> <span class="operator">=</span> <span class="number">2</span><span class="punctuation-delimiter">;</span>
</div><div class="line my-custom-highlight-line" data-line="4">    <span class="keyword">let</span> <span class="variable">z</span> <span class="operator">=</span> <span class="number">3</span><span class="punctuation-delimiter">;</span>
</div><div class="line my-custom-highlight-line" data-line="5">    <span class="keyword">let</span> <span class="variable">message</span> <span class="operator">=</span> <span class="string">&quot;Hello, world!&quot;</span><span class="punctuation-delimiter">;</span>
</div><div class="line" data-line="6"><span class="punctuation-bracket">&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }

    #[test]
    fn test_decorator_include_highlights_with_value() {
        let markdown = r#"
```rust include_highlights=true
fn main() {
    let message = "Hello, world!";
}
```
"#;

        let theme = themes::get("nord").expect("Theme not found");
        let formatter = FormatterOption::HtmlInline {
            theme: Some(theme),
            pre_class: None,
            italic: false,
            include_highlights: false,
            highlight_lines: None,
            header: None,
        };

        let mut options = Options::default();
        options.render.github_pre_lang = true;
        options.render.full_info_string = true;

        let output = run_test(markdown, formatter, options);

        let expected = r#"<pre class="athl" style="color: #d8dee9; background-color: #2e3440;"><code class="language-rust" translate="no" tabindex="0"><div class="line" data-line="1"><span data-highlight="keyword.function" style="color: #88c0d0;">fn</span> <span data-highlight="function" style="color: #88c0d0;">main</span><span data-highlight="punctuation.bracket" style="color: #88c0d0;">(</span><span data-highlight="punctuation.bracket" style="color: #88c0d0;">)</span> <span data-highlight="punctuation.bracket" style="color: #88c0d0;">&lbrace;</span>
</div><div class="line" data-line="2">    <span data-highlight="keyword" style="color: #81a1c1;">let</span> <span data-highlight="variable" style="color: #d8dee9; font-weight: bold;">message</span> <span data-highlight="operator" style="color: #81a1c1;">=</span> <span data-highlight="string" style="color: #a3be8c;">&quot;Hello, world!&quot;</span><span data-highlight="punctuation.delimiter" style="color: #88c0d0;">;</span>
</div><div class="line" data-line="3"><span data-highlight="punctuation.bracket" style="color: #88c0d0;">&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }

    #[test]
    fn test_decorator_include_highlights_standalone() {
        let markdown = r#"
```rust include_highlights
fn main() {
    let message = "Hello, world!";
}
```
"#;

        let theme = themes::get("nord").expect("Theme not found");
        let formatter = FormatterOption::HtmlInline {
            theme: Some(theme),
            pre_class: None,
            italic: false,
            include_highlights: false,
            highlight_lines: None,
            header: None,
        };

        let mut options = Options::default();
        options.render.github_pre_lang = true;
        options.render.full_info_string = true;

        let output = run_test(markdown, formatter, options);

        let expected = r#"<pre class="athl" style="color: #d8dee9; background-color: #2e3440;"><code class="language-rust" translate="no" tabindex="0"><div class="line" data-line="1"><span data-highlight="keyword.function" style="color: #88c0d0;">fn</span> <span data-highlight="function" style="color: #88c0d0;">main</span><span data-highlight="punctuation.bracket" style="color: #88c0d0;">(</span><span data-highlight="punctuation.bracket" style="color: #88c0d0;">)</span> <span data-highlight="punctuation.bracket" style="color: #88c0d0;">&lbrace;</span>
</div><div class="line" data-line="2">    <span data-highlight="keyword" style="color: #81a1c1;">let</span> <span data-highlight="variable" style="color: #d8dee9; font-weight: bold;">message</span> <span data-highlight="operator" style="color: #81a1c1;">=</span> <span data-highlight="string" style="color: #a3be8c;">&quot;Hello, world!&quot;</span><span data-highlight="punctuation.delimiter" style="color: #88c0d0;">;</span>
</div><div class="line" data-line="3"><span data-highlight="punctuation.bracket" style="color: #88c0d0;">&rbrace;</span>
</div></code></pre>"#;

        assert_str_eq!(output.trim(), expected.trim());
    }
}
