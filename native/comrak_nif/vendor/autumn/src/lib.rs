pub mod themes;
pub use crate::themes::Theme;

use inkjet::Language;
use tree_sitter_highlight::{HighlightEvent, Highlighter};

pub fn highlight_source_code(
    source: &str,
    lang: Language,
    theme: &Theme,
    pre_class: Option<&str>,
    inline_style: bool,
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
        .expect("expected to generate the syntax highlight events");

    output.push_str(
        format!(
            "{}{}",
            open_pre_tag(theme, pre_class, inline_style),
            open_code_tag(lang)
        )
        .as_str(),
    );

    for event in highlights {
        let event = event.expect("expected a highlight event");
        let highlight = inner_highlights(source, event, theme, inline_style);
        output.push_str(highlight.as_str())
    }

    output.push_str(format!("{}{}", close_code_tag(), close_pre_tag()).as_str());

    output
}

pub fn open_tags(
    lang: Language,
    theme: &Theme,
    pre_class: Option<&str>,
    inline_style: bool,
) -> String {
    format!(
        "{}{}",
        open_pre_tag(theme, pre_class, inline_style),
        open_code_tag(lang)
    )
}

pub fn close_tags() -> String {
    String::from("</code></pre>")
}

pub fn open_pre_tag(theme: &Theme, class: Option<&str>, inline_style: bool) -> String {
    let class = match class {
        Some(class) => format!("autumn-hl {}", class),
        None => "autumn-hl".to_string(),
    };

    if inline_style {
        let background_style = theme.get_global_style("background");
        let foreground_style = theme.get_global_style("foreground");

        format!(
            "<pre class=\"{}\" style=\"{} {}\">",
            class, background_style, foreground_style
        )
    } else {
        format!("<pre class=\"{}\">", class)
    }
}

pub fn close_pre_tag() -> String {
    String::from("</pre>")
}

pub fn open_code_tag(lang: Language) -> String {
    let class = format!("language-{}", format!("{:?}", lang).to_lowercase());
    format!("<code class=\"{}\" translate=\"no\">", class)
}

pub fn close_code_tag() -> String {
    String::from("</code>")
}

pub fn inner_highlights(
    source: &str,
    event: HighlightEvent,
    theme: &Theme,
    inline_style: bool,
) -> String {
    let mut output = String::new();

    match event {
        HighlightEvent::Source { start, end } => {
            let span = source
                .get(start..end)
                .expect("source bounds should be in bounds!");
            let span = v_htmlescape::escape(span)
                .to_string()
                .replace('{', "&lbrace;")
                .replace('}', "&rbrace;");
            output.push_str(&span);
        }
        HighlightEvent::HighlightStart(idx) => {
            let scope = inkjet::constants::HIGHLIGHT_NAMES[idx.0];
            let class = themes::HIGHLIGHT_CLASS_NAMES[idx.0];

            if inline_style {
                let style = theme.get_style(scope);
                let element = format!("<span class=\"{}\" style=\"{}\">", class, style);
                output.push_str(element.as_str())
            } else {
                let element = format!("<span class=\"{}\">", class);
                output.push_str(element.as_str())
            }
        }
        HighlightEvent::HighlightEnd => output.push_str("</span>"),
    }

    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_highlight_source_code_with_defaults() {
        let theme = themes::theme("onedark").unwrap();
        let output = highlight_source_code("mod themes;", Language::Rust, theme, None, true);

        assert_eq!(
            output,
            "<pre class=\"autumn-hl\" style=\"background-color: #282C34; color: #ABB2BF;\"><code class=\"language-rust\" translate=\"no\"><span class=\"ahl-keyword ahl-control ahl-import\" style=\"color: #E06C75;\">mod</span> <span class=\"ahl-namespace\" style=\"color: #61AFEF;\">themes</span><span class=\"ahl-punctuation ahl-delimiter\" style=\"color: #ABB2BF;\">;</span></code></pre>"
        );
    }

    #[test]
    fn test_highlight_source_code_without_inline_style() {
        let theme = themes::theme("onedark").unwrap();
        let output = highlight_source_code("mod themes;", Language::Rust, theme, None, false);

        assert_eq!(
            output,
            "<pre class=\"autumn-hl\"><code class=\"language-rust\" translate=\"no\"><span class=\"ahl-keyword ahl-control ahl-import\">mod</span> <span class=\"ahl-namespace\">themes</span><span class=\"ahl-punctuation ahl-delimiter\">;</span></code></pre>"
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
            true,
        );

        assert_eq!(
            output,
            "<pre class=\"autumn-hl pre_class\" style=\"background-color: #282C34; color: #ABB2BF;\"><code class=\"language-rust\" translate=\"no\"><span class=\"ahl-keyword ahl-control ahl-import\" style=\"color: #E06C75;\">mod</span> <span class=\"ahl-namespace\" style=\"color: #61AFEF;\">themes</span><span class=\"ahl-punctuation ahl-delimiter\" style=\"color: #ABB2BF;\">;</span></code></pre>"
        );
    }

    #[test]
    fn test_escape_curly_braces_in_code_block() {
        let theme = themes::theme("onedark").unwrap();
        let output = highlight_source_code(
            "```\n{:my_var, MyApp.Mod}\n```",
            Language::Elixir,
            theme,
            None,
            true,
        );

        assert_eq!(output, "<pre class=\"autumn-hl\" style=\"background-color: #282C34; color: #ABB2BF;\"><code class=\"language-elixir\" translate=\"no\">```\n<span class=\"ahl-punctuation ahl-bracket\" style=\"color: #ABB2BF;\">&lbrace;</span><span class=\"ahl-string ahl-special ahl-symbol\" style=\"color: #98C379;\">:my_var</span><span class=\"ahl-punctuation ahl-delimiter\" style=\"color: #ABB2BF;\">,</span> <span class=\"ahl-namespace\" style=\"color: #61AFEF;\">MyApp.Mod</span><span class=\"ahl-punctuation ahl-bracket\" style=\"color: #ABB2BF;\">&rbrace;</span>\n```</code></pre>");
    }

    #[test]
    fn test_escape_curly_braces_in_inline_code() {
        let theme = themes::theme("onedark").unwrap();
        let output = highlight_source_code(
            "`{:my_var, MyApp.Mod}`",
            Language::Elixir,
            theme,
            None,
            true,
        );

        assert_eq!(output, "<pre class=\"autumn-hl\" style=\"background-color: #282C34; color: #ABB2BF;\"><code class=\"language-elixir\" translate=\"no\">`<span class=\"ahl-punctuation ahl-bracket\" style=\"color: #ABB2BF;\">&lbrace;</span><span class=\"ahl-string ahl-special ahl-symbol\" style=\"color: #98C379;\">:my_var</span><span class=\"ahl-punctuation ahl-delimiter\" style=\"color: #ABB2BF;\">,</span> <span class=\"ahl-namespace\" style=\"color: #61AFEF;\">MyApp.Mod</span><span class=\"ahl-punctuation ahl-bracket\" style=\"color: #ABB2BF;\">&rbrace;</span>`</code></pre>");
    }
}
