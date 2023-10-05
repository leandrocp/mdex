pub mod themes;
pub use crate::themes::Theme;

use inkjet::Language;
use tree_sitter_highlight::{HighlightEvent, Highlighter};

pub fn highlight_source_code(
    source: &str,
    lang: Language,
    theme: &Theme,
    pre_class: Option<&str>,
    code_class: Option<&str>,
) -> String {
    let mut output = String::new();
    let mut highlighter = Highlighter::new();
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
        // TODO: fallback to plain text
        .expect("expected to generate the syntax highlight events");

    output.push_str(
        format!(
            "{}\n{}\n",
            open_pre_tag(theme, pre_class),
            open_code_tag(lang, code_class)
        )
        .as_str(),
    );

    for event in highlights {
        // TODO: fallback to plain text
        let event = event.expect("expected a highlight event");
        let highlight = inner_highlights(source, event, theme);
        output.push_str(highlight.as_str())
    }

    output.push_str(format!("\n{}{}\n", close_code_tag(), close_pre_tag()).as_str());

    output
}

pub fn open_tags(
    lang: Language,
    theme: &Theme,
    pre_class: Option<&str>,
    code_class: Option<&str>,
) -> String {
    format!(
        "{}\n{}",
        open_pre_tag(theme, pre_class),
        open_code_tag(lang, code_class)
    )
}

pub fn close_tags() -> String {
    String::from("\n</code></pre>")
}

pub fn open_pre_tag(theme: &Theme, class: Option<&str>) -> String {
    let class = class.unwrap_or("autumn highlight");
    let (_class, background_style) = theme.get_scope("background");
    let (_class, text_style) = theme.get_scope("text");

    format!(
        "<pre class=\"{}\" style=\"{} {}\">",
        class, background_style, text_style
    )
}

pub fn close_pre_tag() -> String {
    String::from("</pre>")
}

pub fn open_code_tag(lang: Language, class: Option<&str>) -> String {
    let lang = format!("{}-{}", "language", format!("{:?}", lang).to_lowercase());
    let class = class.unwrap_or_else(|| &lang);

    format!("<code class=\"{}\" translate=\"no\">", class)
}

pub fn close_code_tag() -> String {
    String::from("</code>")
}

pub fn inner_highlights(source: &str, event: HighlightEvent, theme: &Theme) -> String {
    let mut output = String::new();

    match event {
        HighlightEvent::Source { start, end } => {
            let span = source
                .get(start..end)
                // TODO: fallback to plain text
                .expect("source bounds should be in bounds!");
            let span = v_htmlescape::escape(span).to_string();
            output.push_str(span.as_str())
        }
        HighlightEvent::HighlightStart(idx) => {
            let scope = inkjet::constants::HIGHLIGHT_NAMES[idx.0];
            let (class, style) = theme.get_scope(scope);
            let element = format!("<span class=\"{}\" style=\"{}\">", class, style);
            output.push_str(element.as_str())
        }
        HighlightEvent::HighlightEnd => output.push_str("</span>"),
    }

    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_highlight_source_code() {
        let theme = themes::theme("onedark").unwrap();
        let output = highlight_source_code("mod themes;", Language::Rust, theme, None, None);

        assert_eq!(
            output,
            "<pre class=\"autumn highlight\" style=\"background-color: #282C34; color: #ABB2BF;\">\n<code class=\"language-rust\" translate=\"no\">\n<span class=\"keyword control import\" style=\"color: #E06C75;\">mod</span> <span class=\"namespace\" style=\"color: #61AFEF;\">themes</span><span class=\"\" style=\"color: #ABB2BF;\">;</span>\n</code></pre>\n"
        );
    }

    #[test]
    fn test_highlight_source_code_with_pre_class() {
        let theme = themes::theme("onedark").unwrap();
        let output = highlight_source_code(
            "mod themes;",
            Language::Rust,
            theme,
            Some("pre_class"),
            None,
        );

        assert_eq!(
            output,
            "<pre class=\"pre_class\" style=\"background-color: #282C34; color: #ABB2BF;\">\n<code class=\"language-rust\" translate=\"no\">\n<span class=\"keyword control import\" style=\"color: #E06C75;\">mod</span> <span class=\"namespace\" style=\"color: #61AFEF;\">themes</span><span class=\"\" style=\"color: #ABB2BF;\">;</span>\n</code></pre>\n"
        );
    }

    #[test]
    fn test_highlight_source_code_with_code_class() {
        let theme = themes::theme("onedark").unwrap();
        let output = highlight_source_code(
            "mod themes;",
            Language::Rust,
            theme,
            None,
            Some("code_class"),
        );

        assert_eq!(
            output,
            "<pre class=\"autumn highlight\" style=\"background-color: #282C34; color: #ABB2BF;\">\n<code class=\"code_class\" translate=\"no\">\n<span class=\"keyword control import\" style=\"color: #E06C75;\">mod</span> <span class=\"namespace\" style=\"color: #61AFEF;\">themes</span><span class=\"\" style=\"color: #ABB2BF;\">;</span>\n</code></pre>\n"
        );
    }
}
