use rustler::NifUntaggedEnum;
use std::{collections::HashMap, str::FromStr};

#[derive(Debug, Clone, PartialEq, NifUntaggedEnum)]
pub enum AttrValue {
    U8(u8),
    U32(u32),
    Usize(usize),
    Bool(bool),
    Text(String),
    List(Vec<String>),
}

#[derive(Debug, Clone)]
pub enum NodeName {
    Document,
    FrontMatter,
    BlockQuote,
    List,
    Item,
    DescriptionList,
    DescriptionItem,
    DescriptionTerm,
    DescriptionDetails,
    CodeBlock,
    HtmlBlock,
    Paragraph,
    Heading,
    ThematicBreak,
    FootnoteDefinition,
    Table,
    TableRow,
    TableCell,
    TaskItem,
    SoftBreak,
    LineBreak,
    Code,
    HtmlInline,
    Emph,
    Strong,
    Strikethrough,
    Superscript,
    Link,
    Image,
    FootnoteReference,
    ShortCode,
    Math,
    MultilineBlockQuote,
    Escaped,
    WikiLink,
    Underline,
    SpoileredText,
    EscapedTag,
}

impl FromStr for NodeName {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "document" => Ok(NodeName::Document),
            "front_matter" => Ok(NodeName::FrontMatter),
            "block_quote" => Ok(NodeName::BlockQuote),
            "list" => Ok(NodeName::List),
            "item" => Ok(NodeName::Item),
            "description_list" => Ok(NodeName::DescriptionList),
            "description_item" => Ok(NodeName::DescriptionItem),
            "description_term" => Ok(NodeName::DescriptionTerm),
            "description_details" => Ok(NodeName::DescriptionDetails),
            "code_block" => Ok(NodeName::CodeBlock),
            "html_block" => Ok(NodeName::HtmlBlock),
            "paragraph" => Ok(NodeName::Paragraph),
            "heading" => Ok(NodeName::Heading),
            "thematic_break" => Ok(NodeName::ThematicBreak),
            "footnote_definition" => Ok(NodeName::FootnoteDefinition),
            "table" => Ok(NodeName::Table),
            "table_row" => Ok(NodeName::TableRow),
            "table_cell" => Ok(NodeName::TableCell),
            "task_item" => Ok(NodeName::TaskItem),
            "soft_break" => Ok(NodeName::SoftBreak),
            "line_break" => Ok(NodeName::LineBreak),
            "code" => Ok(NodeName::Code),
            "html_inline" => Ok(NodeName::HtmlInline),
            "emph" => Ok(NodeName::Emph),
            "strong" => Ok(NodeName::Strong),
            "strikethrough" => Ok(NodeName::Strikethrough),
            "superscript" => Ok(NodeName::Superscript),
            "link" => Ok(NodeName::Link),
            "image" => Ok(NodeName::Image),
            "footnote_reference" => Ok(NodeName::FootnoteReference),
            "short_code" => Ok(NodeName::ShortCode),
            "math" => Ok(NodeName::Math),
            "multiline_block_quote" => Ok(NodeName::MultilineBlockQuote),
            "escaped" => Ok(NodeName::Escaped),
            "wiki_link" => Ok(NodeName::WikiLink),
            "underline" => Ok(NodeName::Underline),
            "spoilered_text" => Ok(NodeName::SpoileredText),
            "escaped_tag" => Ok(NodeName::EscapedTag),
            _ => Err(()),
        }
    }
}

#[derive(Debug, Clone)]
pub enum ExNode<'a> {
    Element {
        name: NodeName,
        attrs: HashMap<&'a str, AttrValue>,
        children: Vec<ExNode<'a>>,
    },
    Text(String),
}
