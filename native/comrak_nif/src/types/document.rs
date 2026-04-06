use comrak::nodes::{
    AstNode, HeexNode, LineColumn, NodeHeexBlock, NodeTaskItem, NodeValue, Sourcepos,
};
use typed_arena::Arena as TypedArena;

mod atoms {
    rustler::atoms! {
        bullet,
        ordered,
        period,
        paren,
        none,
        left,
        center,
        right
    }
}

#[derive(Clone, Debug, Default, NifStruct, PartialEq)]
#[module = "MDEx.Sourcepos"]
pub struct ExSourcepos {
    pub start: (usize, usize),
    pub end: (usize, usize),
}

fn sourcepos_to_ex(sp: &Sourcepos) -> ExSourcepos {
    ExSourcepos {
        start: (sp.start.line, sp.start.column),
        end: (sp.end.line, sp.end.column),
    }
}

fn ex_to_sourcepos(ex: &ExSourcepos) -> Sourcepos {
    Sourcepos {
        start: LineColumn {
            line: ex.start.0,
            column: ex.start.1,
        },
        end: LineColumn {
            line: ex.end.0,
            column: ex.end.1,
        },
    }
}

// https://docs.rs/comrak/latest/comrak/nodes/enum.NodeValue.html
#[derive(Clone, Debug, NifUntaggedEnum, PartialEq)]
pub enum NewNode {
    Document(ExDocument),
    FrontMatter(ExFrontMatter),
    BlockQuote(ExBlockQuote),
    List(ExList),
    ListItem(ExListItem),
    DescriptionList(ExDescriptionList),
    DescriptionItem(ExDescriptionItem),
    DescriptionTerm(ExDescriptionTerm),
    DescriptionDetails(ExDescriptionDetails),
    CodeBlock(ExCodeBlock),
    HtmlBlock(ExHtmlBlock),
    Paragraph(ExParagraph),
    Heading(ExHeading),
    ThematicBreak(ExThematicBreak),
    FootnoteDefinition(ExFootnoteDefinition),
    FootnoteReference(ExFootnoteReference),
    Table(ExTable),
    TableRow(ExTableRow),
    TableCell(ExTableCell),
    Text(ExText),
    TaskItem(ExTaskItem),
    SoftBreak(ExSoftBreak),
    LineBreak(ExLineBreak),
    Code(ExCode),
    HtmlInline(ExHtmlInline),
    Raw(ExRaw),
    Emph(ExEmph),
    Strong(ExStrong),
    Strikethrough(ExStrikethrough),
    Highlight(ExHighlight),
    Insert(ExInsert),
    Superscript(ExSuperscript),
    Link(ExLink),
    Image(ExImage),
    ShortCode(ExShortCode),
    Math(ExMath),
    MultilineBlockQuote(ExMultilineBlockQuote),
    Escaped(ExEscaped),
    WikiLink(ExWikiLink),
    Underline(ExUnderline),
    Subscript(ExSubscript),
    SpoileredText(ExSpoileredText),
    Subtext(ExSubtext),
    EscapedTag(ExEscapedTag),
    Alert(ExAlert),
    HeexBlock(ExHeexBlock),
    HeexInline(ExHeexInline),
    BlockDirective(ExBlockDirective),
}

impl From<NewNode> for NodeValue {
    fn from(node: NewNode) -> Self {
        match node {
            NewNode::Document(n) => n.into(),
            NewNode::FrontMatter(n) => n.into(),
            NewNode::BlockQuote(n) => n.into(),
            NewNode::List(n) => n.into(),
            NewNode::ListItem(n) => n.into(),
            NewNode::DescriptionList(n) => n.into(),
            NewNode::DescriptionItem(n) => n.into(),
            NewNode::DescriptionTerm(n) => n.into(),
            NewNode::DescriptionDetails(n) => n.into(),
            NewNode::CodeBlock(n) => n.into(),
            NewNode::HtmlBlock(n) => n.into(),
            NewNode::Paragraph(n) => n.into(),
            NewNode::Heading(n) => n.into(),
            NewNode::ThematicBreak(n) => n.into(),
            NewNode::FootnoteDefinition(n) => n.into(),
            NewNode::FootnoteReference(n) => n.into(),
            NewNode::Table(n) => n.into(),
            NewNode::TableRow(n) => n.into(),
            NewNode::TableCell(n) => n.into(),
            NewNode::Text(n) => n.into(),
            NewNode::TaskItem(n) => n.into(),
            NewNode::SoftBreak(n) => n.into(),
            NewNode::LineBreak(n) => n.into(),
            NewNode::Code(n) => n.into(),
            NewNode::HtmlInline(n) => n.into(),
            NewNode::Raw(n) => n.into(),
            NewNode::Emph(n) => n.into(),
            NewNode::Strong(n) => n.into(),
            NewNode::Strikethrough(n) => n.into(),
            NewNode::Highlight(n) => n.into(),
            NewNode::Insert(n) => n.into(),
            NewNode::Superscript(n) => n.into(),
            NewNode::Link(n) => n.into(),
            NewNode::Image(n) => n.into(),
            NewNode::ShortCode(n) => n.into(),
            NewNode::Math(n) => n.into(),
            NewNode::MultilineBlockQuote(n) => n.into(),
            NewNode::Escaped(n) => n.into(),
            NewNode::WikiLink(n) => n.into(),
            NewNode::Underline(n) => n.into(),
            NewNode::Subscript(n) => n.into(),
            NewNode::SpoileredText(n) => n.into(),
            NewNode::Subtext(n) => n.into(),
            NewNode::EscapedTag(n) => n.into(),
            NewNode::Alert(n) => n.into(),
            NewNode::HeexBlock(n) => n.into(),
            NewNode::HeexInline(n) => n.into(),
            NewNode::BlockDirective(n) => n.into(),
        }
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Document"]
pub struct ExDocument {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExDocument> for NodeValue {
    fn from(_node: ExDocument) -> Self {
        NodeValue::Document
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.FrontMatter"]
pub struct ExFrontMatter {
    pub literal: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExFrontMatter> for NodeValue {
    fn from(node: ExFrontMatter) -> Self {
        NodeValue::FrontMatter(node.literal)
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.BlockQuote"]
pub struct ExBlockQuote {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExBlockQuote> for NodeValue {
    fn from(_node: ExBlockQuote) -> Self {
        NodeValue::BlockQuote
    }
}

#[derive(Clone, Debug, NifUnitEnum, PartialEq)]
pub enum ExListType {
    Bullet,
    Ordered,
}

#[derive(Clone, Debug, NifUnitEnum, PartialEq)]
pub enum ExListDelimType {
    Period,
    Paren,
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.List"]
pub struct ExList {
    pub nodes: Vec<NewNode>,
    pub list_type: ExListType,
    pub marker_offset: usize,
    pub padding: usize,
    pub start: usize,
    pub delimiter: ExListDelimType,
    pub bullet_char: String,
    pub tight: bool,
    pub is_task_list: bool,
    pub sourcepos: ExSourcepos,
}

impl From<ExList> for NodeValue {
    fn from(node: ExList) -> Self {
        NodeValue::List(comrak::nodes::NodeList {
            list_type: match node.list_type {
                ExListType::Bullet => comrak::nodes::ListType::Bullet,
                ExListType::Ordered => comrak::nodes::ListType::Ordered,
            },
            marker_offset: node.marker_offset,
            padding: node.padding,
            start: node.start,
            delimiter: match node.delimiter {
                ExListDelimType::Period => comrak::nodes::ListDelimType::Period,
                ExListDelimType::Paren => comrak::nodes::ListDelimType::Paren,
            },
            bullet_char: string_to_char(node.bullet_char),
            tight: node.tight,
            is_task_list: node.is_task_list,
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.ListItem"]
pub struct ExListItem {
    pub nodes: Vec<NewNode>,
    pub list_type: ExListType,
    pub marker_offset: usize,
    pub padding: usize,
    pub start: usize,
    pub delimiter: ExListDelimType,
    pub bullet_char: String,
    pub tight: bool,
    pub is_task_list: bool,
    pub sourcepos: ExSourcepos,
}

impl From<ExListItem> for NodeValue {
    fn from(node: ExListItem) -> Self {
        NodeValue::Item(comrak::nodes::NodeList {
            list_type: match node.list_type {
                ExListType::Bullet => comrak::nodes::ListType::Bullet,
                ExListType::Ordered => comrak::nodes::ListType::Ordered,
            },
            marker_offset: node.marker_offset,
            padding: node.padding,
            start: node.start,
            delimiter: match node.delimiter {
                ExListDelimType::Period => comrak::nodes::ListDelimType::Period,
                ExListDelimType::Paren => comrak::nodes::ListDelimType::Paren,
            },
            bullet_char: string_to_char(node.bullet_char),
            tight: node.tight,
            is_task_list: node.is_task_list,
        })
    }
}
#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.DescriptionList"]
pub struct ExDescriptionList {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExDescriptionList> for NodeValue {
    fn from(_node: ExDescriptionList) -> Self {
        NodeValue::DescriptionList
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.DescriptionItem"]
pub struct ExDescriptionItem {
    pub nodes: Vec<NewNode>,
    pub marker_offset: usize,
    pub padding: usize,
    pub tight: bool,
    pub sourcepos: ExSourcepos,
}

impl From<ExDescriptionItem> for NodeValue {
    fn from(node: ExDescriptionItem) -> Self {
        NodeValue::DescriptionItem(comrak::nodes::NodeDescriptionItem {
            marker_offset: node.marker_offset,
            padding: node.padding,
            tight: node.tight,
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.DescriptionTerm"]
pub struct ExDescriptionTerm {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExDescriptionTerm> for NodeValue {
    fn from(_node: ExDescriptionTerm) -> Self {
        NodeValue::DescriptionTerm
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.DescriptionDetails"]
pub struct ExDescriptionDetails {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExDescriptionDetails> for NodeValue {
    fn from(_node: ExDescriptionDetails) -> Self {
        NodeValue::DescriptionDetails
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.CodeBlock"]
pub struct ExCodeBlock {
    pub nodes: Vec<NewNode>,
    pub fenced: bool,
    pub fence_char: String,
    pub fence_length: usize,
    pub fence_offset: usize,
    pub info: String,
    pub literal: String,
    pub closed: bool,
    pub sourcepos: ExSourcepos,
}

impl From<ExCodeBlock> for NodeValue {
    fn from(node: ExCodeBlock) -> Self {
        NodeValue::CodeBlock(Box::new(comrak::nodes::NodeCodeBlock {
            fenced: node.fenced,
            fence_char: string_to_char(node.fence_char),
            fence_length: node.fence_length,
            fence_offset: node.fence_offset,
            info: node.info,
            literal: node.literal,
            closed: node.closed,
        }))
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.HtmlBlock"]
pub struct ExHtmlBlock {
    pub nodes: Vec<NewNode>,
    pub block_type: u8,
    pub literal: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExHtmlBlock> for NodeValue {
    fn from(node: ExHtmlBlock) -> Self {
        NodeValue::HtmlBlock(comrak::nodes::NodeHtmlBlock {
            block_type: node.block_type,
            literal: node.literal,
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Paragraph"]
pub struct ExParagraph {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExParagraph> for NodeValue {
    fn from(_node: ExParagraph) -> Self {
        NodeValue::Paragraph
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Heading"]
pub struct ExHeading {
    pub nodes: Vec<NewNode>,
    pub level: u8,
    pub setext: bool,
    pub closed: bool,
    pub sourcepos: ExSourcepos,
}

impl From<ExHeading> for NodeValue {
    fn from(node: ExHeading) -> Self {
        NodeValue::Heading(comrak::nodes::NodeHeading {
            level: node.level,
            setext: node.setext,
            closed: node.closed,
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.ThematicBreak"]
pub struct ExThematicBreak {
    pub sourcepos: ExSourcepos,
}

impl From<ExThematicBreak> for NodeValue {
    fn from(_node: ExThematicBreak) -> Self {
        NodeValue::ThematicBreak
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.FootnoteDefinition"]
pub struct ExFootnoteDefinition {
    pub nodes: Vec<NewNode>,
    pub name: String,
    pub total_references: u32,
    pub sourcepos: ExSourcepos,
}

impl From<ExFootnoteDefinition> for NodeValue {
    fn from(node: ExFootnoteDefinition) -> Self {
        NodeValue::FootnoteDefinition(comrak::nodes::NodeFootnoteDefinition {
            name: node.name.to_string(),
            total_references: node.total_references,
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.FootnoteReference"]
pub struct ExFootnoteReference {
    pub name: String,
    pub ref_num: u32,
    pub ix: u32,
    pub texts: Vec<(String, usize)>,
    pub sourcepos: ExSourcepos,
}

impl From<ExFootnoteReference> for NodeValue {
    fn from(node: ExFootnoteReference) -> Self {
        NodeValue::FootnoteReference(Box::new(comrak::nodes::NodeFootnoteReference {
            name: node.name.to_string(),
            ref_num: node.ref_num,
            ix: node.ix,
            texts: node.texts,
        }))
    }
}

#[derive(Clone, Debug, NifUnitEnum, PartialEq)]
pub enum ExTableAlignment {
    None,
    Left,
    Center,
    Right,
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Table"]
pub struct ExTable {
    pub nodes: Vec<NewNode>,
    pub alignments: Vec<ExTableAlignment>,
    pub num_columns: usize,
    pub num_rows: usize,
    pub num_nonempty_cells: usize,
    pub sourcepos: ExSourcepos,
}

impl From<ExTable> for NodeValue {
    fn from(node: ExTable) -> Self {
        NodeValue::Table(Box::new(comrak::nodes::NodeTable {
            alignments: node
                .alignments
                .into_iter()
                .map(|a| match a {
                    ExTableAlignment::None => comrak::nodes::TableAlignment::None,
                    ExTableAlignment::Left => comrak::nodes::TableAlignment::Left,
                    ExTableAlignment::Center => comrak::nodes::TableAlignment::Center,
                    ExTableAlignment::Right => comrak::nodes::TableAlignment::Right,
                })
                .collect(),
            num_columns: node.num_columns,
            num_rows: node.num_rows,
            num_nonempty_cells: node.num_nonempty_cells,
        }))
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.TableRow"]
pub struct ExTableRow {
    pub nodes: Vec<NewNode>,
    pub header: bool,
    pub sourcepos: ExSourcepos,
}

impl From<ExTableRow> for NodeValue {
    fn from(node: ExTableRow) -> Self {
        NodeValue::TableRow(node.header)
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.TableCell"]
pub struct ExTableCell {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExTableCell> for NodeValue {
    fn from(_node: ExTableCell) -> Self {
        NodeValue::TableCell
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Text"]
pub struct ExText {
    pub literal: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExText> for NodeValue {
    fn from(node: ExText) -> Self {
        NodeValue::Text(node.literal.into())
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.TaskItem"]
pub struct ExTaskItem {
    pub nodes: Vec<NewNode>,
    pub checked: bool,
    pub marker: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExTaskItem> for NodeValue {
    fn from(node: ExTaskItem) -> Self {
        NodeValue::TaskItem(NodeTaskItem {
            symbol: node.marker.chars().next(),
            symbol_sourcepos: Sourcepos {
                start: LineColumn::default(),
                end: LineColumn::default(),
            },
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.SoftBreak"]
pub struct ExSoftBreak {
    pub sourcepos: ExSourcepos,
}

impl From<ExSoftBreak> for NodeValue {
    fn from(_node: ExSoftBreak) -> Self {
        NodeValue::SoftBreak
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.LineBreak"]
pub struct ExLineBreak {
    pub sourcepos: ExSourcepos,
}

impl From<ExLineBreak> for NodeValue {
    fn from(_node: ExLineBreak) -> Self {
        NodeValue::LineBreak
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Code"]
pub struct ExCode {
    pub num_backticks: usize,
    pub literal: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExCode> for NodeValue {
    fn from(node: ExCode) -> Self {
        NodeValue::Code(comrak::nodes::NodeCode {
            num_backticks: node.num_backticks,
            literal: node.literal,
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.HtmlInline"]
pub struct ExHtmlInline {
    pub literal: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExHtmlInline> for NodeValue {
    fn from(node: ExHtmlInline) -> Self {
        NodeValue::HtmlInline(node.literal.to_string())
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.HeexBlock"]
pub struct ExHeexBlock {
    pub nodes: Vec<NewNode>,
    pub literal: String,
    pub node: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExHeexBlock> for NodeValue {
    fn from(node: ExHeexBlock) -> Self {
        let heex_node = match node.node.as_str() {
            "directive" => HeexNode::Directive,
            "comment" => HeexNode::Comment,
            "multiline_comment" => HeexNode::MultilineComment,
            "expression" => HeexNode::Expression,
            tag => HeexNode::Tag(tag.to_string()),
        };
        NodeValue::HeexBlock(Box::new(NodeHeexBlock {
            literal: node.literal,
            node: heex_node,
        }))
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.HeexInline"]
pub struct ExHeexInline {
    pub literal: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExHeexInline> for NodeValue {
    fn from(node: ExHeexInline) -> Self {
        NodeValue::HeexInline(node.literal)
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Raw"]
pub struct ExRaw {
    pub literal: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExRaw> for NodeValue {
    fn from(node: ExRaw) -> Self {
        NodeValue::Raw(node.literal.to_string())
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Emph"]
pub struct ExEmph {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExEmph> for NodeValue {
    fn from(_node: ExEmph) -> Self {
        NodeValue::Emph
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Strong"]
pub struct ExStrong {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExStrong> for NodeValue {
    fn from(_node: ExStrong) -> Self {
        NodeValue::Strong
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Strikethrough"]
pub struct ExStrikethrough {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExStrikethrough> for NodeValue {
    fn from(_node: ExStrikethrough) -> Self {
        NodeValue::Strikethrough
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Highlight"]
pub struct ExHighlight {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExHighlight> for NodeValue {
    fn from(_node: ExHighlight) -> Self {
        NodeValue::Highlight
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Insert"]
pub struct ExInsert {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExInsert> for NodeValue {
    fn from(_node: ExInsert) -> Self {
        NodeValue::Insert
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Superscript"]
pub struct ExSuperscript {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExSuperscript> for NodeValue {
    fn from(_node: ExSuperscript) -> Self {
        NodeValue::Superscript
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Link"]
pub struct ExLink {
    pub nodes: Vec<NewNode>,
    pub url: String,
    pub title: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExLink> for NodeValue {
    fn from(node: ExLink) -> Self {
        NodeValue::Link(Box::new(comrak::nodes::NodeLink {
            url: node.url,
            title: node.title,
        }))
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Image"]
pub struct ExImage {
    pub nodes: Vec<NewNode>,
    pub url: String,
    pub title: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExImage> for NodeValue {
    fn from(node: ExImage) -> Self {
        NodeValue::Image(Box::new(comrak::nodes::NodeLink {
            url: node.url,
            title: node.title,
        }))
    }
}
#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.ShortCode"]
pub struct ExShortCode {
    pub code: String,
    pub emoji: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExShortCode> for NodeValue {
    fn from(node: ExShortCode) -> Self {
        NodeValue::ShortCode(Box::new(comrak::nodes::NodeShortCode {
            code: node.code.to_string(),
            emoji: node.emoji.to_string(),
        }))
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Math"]
pub struct ExMath {
    pub dollar_math: bool,
    pub display_math: bool,
    pub literal: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExMath> for NodeValue {
    fn from(node: ExMath) -> Self {
        NodeValue::Math(comrak::nodes::NodeMath {
            dollar_math: node.dollar_math,
            display_math: node.display_math,
            literal: node.literal,
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.MultilineBlockQuote"]
pub struct ExMultilineBlockQuote {
    pub nodes: Vec<NewNode>,
    pub fence_length: usize,
    pub fence_offset: usize,
    pub sourcepos: ExSourcepos,
}

impl From<ExMultilineBlockQuote> for NodeValue {
    fn from(node: ExMultilineBlockQuote) -> Self {
        NodeValue::MultilineBlockQuote(comrak::nodes::NodeMultilineBlockQuote {
            fence_length: node.fence_length,
            fence_offset: node.fence_offset,
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Escaped"]
pub struct ExEscaped {
    pub sourcepos: ExSourcepos,
}

impl From<ExEscaped> for NodeValue {
    fn from(_node: ExEscaped) -> Self {
        NodeValue::Escaped
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.WikiLink"]
pub struct ExWikiLink {
    pub nodes: Vec<NewNode>,
    pub url: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExWikiLink> for NodeValue {
    fn from(node: ExWikiLink) -> Self {
        NodeValue::WikiLink(comrak::nodes::NodeWikiLink {
            url: node.url.to_string(),
        })
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Underline"]
pub struct ExUnderline {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExUnderline> for NodeValue {
    fn from(_node: ExUnderline) -> Self {
        NodeValue::Underline
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Subscript"]
pub struct ExSubscript {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExSubscript> for NodeValue {
    fn from(_node: ExSubscript) -> Self {
        NodeValue::Subscript
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.SpoileredText"]
pub struct ExSpoileredText {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExSpoileredText> for NodeValue {
    fn from(_node: ExSpoileredText) -> Self {
        NodeValue::SpoileredText
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Subtext"]
pub struct ExSubtext {
    pub nodes: Vec<NewNode>,
    pub sourcepos: ExSourcepos,
}

impl From<ExSubtext> for NodeValue {
    fn from(_node: ExSubtext) -> Self {
        NodeValue::Subtext
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.EscapedTag"]
pub struct ExEscapedTag {
    pub nodes: Vec<NewNode>,
    pub literal: String,
    pub sourcepos: ExSourcepos,
}

impl From<ExEscapedTag> for NodeValue {
    fn from(node: ExEscapedTag) -> Self {
        NodeValue::EscapedTag(Box::leak(node.literal.into_boxed_str()))
    }
}

#[derive(Clone, Debug, Default, NifUnitEnum, PartialEq)]
pub enum ExAlertType {
    #[default]
    Note,
    Tip,
    Important,
    Warning,
    Caution,
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Alert"]
pub struct ExAlert {
    pub nodes: Vec<NewNode>,
    pub alert_type: ExAlertType,
    pub title: Option<String>,
    pub multiline: bool,
    pub fence_length: usize,
    pub fence_offset: usize,
    pub sourcepos: ExSourcepos,
}

impl From<ExAlert> for NodeValue {
    fn from(node: ExAlert) -> Self {
        NodeValue::Alert(Box::new(comrak::nodes::NodeAlert {
            alert_type: match node.alert_type {
                ExAlertType::Note => comrak::nodes::AlertType::Note,
                ExAlertType::Tip => comrak::nodes::AlertType::Tip,
                ExAlertType::Important => comrak::nodes::AlertType::Important,
                ExAlertType::Warning => comrak::nodes::AlertType::Warning,
                ExAlertType::Caution => comrak::nodes::AlertType::Caution,
            },
            title: node.title,
            multiline: node.multiline,
            fence_length: node.fence_length,
            fence_offset: node.fence_offset,
        }))
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.BlockDirective"]
pub struct ExBlockDirective {
    pub nodes: Vec<NewNode>,
    pub info: String,
    pub fence_length: usize,
    pub fence_offset: usize,
    pub sourcepos: ExSourcepos,
}

impl From<ExBlockDirective> for NodeValue {
    fn from(node: ExBlockDirective) -> Self {
        NodeValue::BlockDirective(Box::new(comrak::nodes::NodeBlockDirective {
            info: node.info,
            fence_length: node.fence_length,
            fence_offset: node.fence_offset,
        }))
    }
}

pub fn ex_document_to_comrak_ast<'a>(
    arena: &'a TypedArena<AstNode<'a>>,
    new_node: NewNode,
) -> &'a AstNode<'a> {
    let node_value = NodeValue::from(new_node.clone());
    let node_arena = arena.alloc(node_value.into());

    let (sourcepos, children) = match new_node {
        NewNode::Document(ExDocument { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::FrontMatter(ExFrontMatter { sourcepos, .. }) => (sourcepos, None),
        NewNode::BlockQuote(ExBlockQuote { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::List(ExList {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::ListItem(ExListItem {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::DescriptionList(ExDescriptionList { nodes, sourcepos }) => {
            (sourcepos, Some(nodes))
        }
        NewNode::DescriptionItem(ExDescriptionItem {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::DescriptionTerm(ExDescriptionTerm { nodes, sourcepos }) => {
            (sourcepos, Some(nodes))
        }
        NewNode::DescriptionDetails(ExDescriptionDetails { nodes, sourcepos }) => {
            (sourcepos, Some(nodes))
        }
        NewNode::CodeBlock(ExCodeBlock {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::HtmlBlock(ExHtmlBlock {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::Paragraph(ExParagraph { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Heading(ExHeading {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::ThematicBreak(ExThematicBreak { sourcepos }) => (sourcepos, None),
        NewNode::FootnoteDefinition(ExFootnoteDefinition {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::FootnoteReference(ExFootnoteReference { sourcepos, .. }) => (sourcepos, None),
        NewNode::Table(ExTable {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::TableRow(ExTableRow {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::TableCell(ExTableCell { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Text(ExText { sourcepos, .. }) => (sourcepos, None),
        NewNode::TaskItem(ExTaskItem {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::SoftBreak(ExSoftBreak { sourcepos }) => (sourcepos, None),
        NewNode::LineBreak(ExLineBreak { sourcepos }) => (sourcepos, None),
        NewNode::Code(ExCode { sourcepos, .. }) => (sourcepos, None),
        NewNode::HtmlInline(ExHtmlInline { sourcepos, .. }) => (sourcepos, None),
        NewNode::Raw(ExRaw { sourcepos, .. }) => (sourcepos, None),
        NewNode::Emph(ExEmph { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Strong(ExStrong { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Strikethrough(ExStrikethrough { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Highlight(ExHighlight { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Insert(ExInsert { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Superscript(ExSuperscript { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Link(ExLink {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::Image(ExImage {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::ShortCode(ExShortCode { sourcepos, .. }) => (sourcepos, None),
        NewNode::Math(ExMath { sourcepos, .. }) => (sourcepos, None),
        NewNode::MultilineBlockQuote(ExMultilineBlockQuote {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::Escaped(ExEscaped { sourcepos }) => (sourcepos, None),
        NewNode::WikiLink(ExWikiLink {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::Underline(ExUnderline { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Subscript(ExSubscript { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::SpoileredText(ExSpoileredText { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::Subtext(ExSubtext { nodes, sourcepos }) => (sourcepos, Some(nodes)),
        NewNode::EscapedTag(ExEscapedTag {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::Alert(ExAlert {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::HeexBlock(ExHeexBlock {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
        NewNode::HeexInline(ExHeexInline { sourcepos, .. }) => (sourcepos, None),
        NewNode::BlockDirective(ExBlockDirective {
            nodes, sourcepos, ..
        }) => (sourcepos, Some(nodes)),
    };

    node_arena.data_mut().sourcepos = ex_to_sourcepos(&sourcepos);

    if let Some(nodes) = children {
        for node in nodes {
            let child = ex_document_to_comrak_ast(arena, node);
            node_arena.append(child);
        }
    }

    node_arena
}

pub fn comrak_ast_to_ex_document<'a>(node: &'a AstNode<'a>) -> NewNode {
    let children: Vec<NewNode> = node.children().map(comrak_ast_to_ex_document).collect();
    let node_data = node.data();
    let sourcepos = sourcepos_to_ex(&node_data.sourcepos);

    match &node_data.value {
        NodeValue::Document => NewNode::Document(ExDocument {
            nodes: children,
            sourcepos,
        }),

        NodeValue::FrontMatter(ref literal) => NewNode::FrontMatter(ExFrontMatter {
            literal: literal.to_string(),
            sourcepos,
        }),

        NodeValue::BlockQuote => NewNode::BlockQuote(ExBlockQuote {
            nodes: children,
            sourcepos,
        }),

        NodeValue::List(ref attrs) => NewNode::List(ExList {
            nodes: children,
            list_type: match attrs.list_type {
                comrak::nodes::ListType::Bullet => ExListType::Bullet,
                comrak::nodes::ListType::Ordered => ExListType::Ordered,
            },
            marker_offset: attrs.marker_offset,
            padding: attrs.padding,
            start: attrs.start,
            delimiter: match attrs.delimiter {
                comrak::nodes::ListDelimType::Period => ExListDelimType::Period,
                comrak::nodes::ListDelimType::Paren => ExListDelimType::Paren,
            },
            bullet_char: char_to_string(attrs.bullet_char).unwrap_or_default(),
            tight: attrs.tight,
            is_task_list: attrs.is_task_list,
            sourcepos,
        }),

        NodeValue::Item(ref attrs) => NewNode::ListItem(ExListItem {
            nodes: children,
            list_type: match attrs.list_type {
                comrak::nodes::ListType::Bullet => ExListType::Bullet,
                comrak::nodes::ListType::Ordered => ExListType::Ordered,
            },
            marker_offset: attrs.marker_offset,
            padding: attrs.padding,
            start: attrs.start,
            delimiter: match attrs.delimiter {
                comrak::nodes::ListDelimType::Period => ExListDelimType::Period,
                comrak::nodes::ListDelimType::Paren => ExListDelimType::Paren,
            },
            bullet_char: char_to_string(attrs.bullet_char).unwrap_or_default(),
            tight: attrs.tight,
            is_task_list: attrs.is_task_list,
            sourcepos,
        }),

        NodeValue::DescriptionList => NewNode::DescriptionList(ExDescriptionList {
            nodes: children,
            sourcepos,
        }),

        NodeValue::DescriptionItem(ref attrs) => NewNode::DescriptionItem(ExDescriptionItem {
            nodes: children,
            marker_offset: attrs.marker_offset,
            padding: attrs.padding,
            tight: attrs.tight,
            sourcepos,
        }),

        NodeValue::DescriptionTerm => NewNode::DescriptionTerm(ExDescriptionTerm {
            nodes: children,
            sourcepos,
        }),

        NodeValue::DescriptionDetails => NewNode::DescriptionDetails(ExDescriptionDetails {
            nodes: children,
            sourcepos,
        }),

        NodeValue::CodeBlock(attrs) => NewNode::CodeBlock(ExCodeBlock {
            nodes: children,
            fenced: attrs.fenced,
            fence_char: char_to_string(attrs.fence_char).unwrap_or_default(),
            fence_length: attrs.fence_length,
            fence_offset: attrs.fence_offset,
            info: attrs.info.to_string(),
            literal: attrs.literal.to_string(),
            closed: attrs.closed,
            sourcepos,
        }),

        NodeValue::HtmlBlock(ref attrs) => NewNode::HtmlBlock(ExHtmlBlock {
            nodes: children,
            block_type: attrs.block_type,
            literal: attrs.literal.to_string(),
            sourcepos,
        }),

        NodeValue::Paragraph => NewNode::Paragraph(ExParagraph {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Heading(ref attrs) => NewNode::Heading(ExHeading {
            nodes: children,
            level: attrs.level,
            setext: attrs.setext,
            closed: attrs.closed,
            sourcepos,
        }),

        NodeValue::ThematicBreak => NewNode::ThematicBreak(ExThematicBreak { sourcepos }),

        NodeValue::FootnoteDefinition(ref attrs) => {
            NewNode::FootnoteDefinition(ExFootnoteDefinition {
                nodes: children,
                name: attrs.name.to_string(),
                total_references: attrs.total_references,
                sourcepos,
            })
        }

        NodeValue::FootnoteReference(ref attrs) => {
            NewNode::FootnoteReference(ExFootnoteReference {
                name: attrs.name.to_string(),
                ref_num: attrs.ref_num,
                ix: attrs.ix,
                texts: attrs.texts.clone(),
                sourcepos,
            })
        }

        NodeValue::Table(attrs) => NewNode::Table(ExTable {
            nodes: children,
            alignments: attrs
                .alignments
                .iter()
                .map(|a| match a {
                    comrak::nodes::TableAlignment::None => ExTableAlignment::None,
                    comrak::nodes::TableAlignment::Left => ExTableAlignment::Left,
                    comrak::nodes::TableAlignment::Center => ExTableAlignment::Center,
                    comrak::nodes::TableAlignment::Right => ExTableAlignment::Right,
                })
                .collect(),
            num_columns: attrs.num_columns,
            num_rows: attrs.num_rows,
            num_nonempty_cells: attrs.num_nonempty_cells,
            sourcepos,
        }),

        NodeValue::TableRow(header) => NewNode::TableRow(ExTableRow {
            nodes: children,
            header: *header,
            sourcepos,
        }),

        NodeValue::TableCell => NewNode::TableCell(ExTableCell {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Text(ref literal) => NewNode::Text(ExText {
            literal: literal.to_string(),
            sourcepos,
        }),

        NodeValue::TaskItem(marker) => NewNode::TaskItem(ExTaskItem {
            nodes: children,
            checked: marker.symbol.is_some(),
            marker: marker.symbol.map_or_else(String::new, |c| c.to_string()),
            sourcepos,
        }),

        NodeValue::SoftBreak => NewNode::SoftBreak(ExSoftBreak { sourcepos }),

        NodeValue::LineBreak => NewNode::LineBreak(ExLineBreak { sourcepos }),

        NodeValue::Code(ref attrs) => NewNode::Code(ExCode {
            num_backticks: attrs.num_backticks,
            literal: attrs.literal.to_string(),
            sourcepos,
        }),

        NodeValue::HtmlInline(ref literal) => NewNode::HtmlInline(ExHtmlInline {
            literal: literal.to_string(),
            sourcepos,
        }),

        NodeValue::Raw(ref literal) => NewNode::Raw(ExRaw {
            literal: literal.to_string(),
            sourcepos,
        }),

        NodeValue::Emph => NewNode::Emph(ExEmph {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Strong => NewNode::Strong(ExStrong {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Strikethrough => NewNode::Strikethrough(ExStrikethrough {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Highlight => NewNode::Highlight(ExHighlight {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Insert => NewNode::Insert(ExInsert {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Superscript => NewNode::Superscript(ExSuperscript {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Link(attrs) => NewNode::Link(ExLink {
            nodes: children,
            url: attrs.url.to_string(),
            title: attrs.title.to_string(),
            sourcepos,
        }),

        NodeValue::Image(attrs) => NewNode::Image(ExImage {
            nodes: children,
            url: attrs.url.to_string(),
            title: attrs.title.to_string(),
            sourcepos,
        }),

        NodeValue::ShortCode(attrs) => NewNode::ShortCode(ExShortCode {
            code: attrs.code.to_string(),
            emoji: attrs.emoji.to_string(),
            sourcepos,
        }),

        NodeValue::Math(ref attrs) => NewNode::Math(ExMath {
            dollar_math: attrs.dollar_math,
            display_math: attrs.display_math,
            literal: attrs.literal.to_string(),
            sourcepos,
        }),

        NodeValue::MultilineBlockQuote(ref attrs) => {
            NewNode::MultilineBlockQuote(ExMultilineBlockQuote {
                nodes: children,
                fence_length: attrs.fence_length,
                fence_offset: attrs.fence_offset,
                sourcepos,
            })
        }

        NodeValue::Escaped => NewNode::Escaped(ExEscaped { sourcepos }),

        NodeValue::WikiLink(ref attrs) => NewNode::WikiLink(ExWikiLink {
            nodes: children,
            url: attrs.url.to_string(),
            sourcepos,
        }),

        NodeValue::Underline => NewNode::Underline(ExUnderline {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Subscript => NewNode::Subscript(ExSubscript {
            nodes: children,
            sourcepos,
        }),

        NodeValue::SpoileredText => NewNode::SpoileredText(ExSpoileredText {
            nodes: children,
            sourcepos,
        }),

        NodeValue::Subtext => NewNode::Subtext(ExSubtext {
            nodes: children,
            sourcepos,
        }),

        NodeValue::EscapedTag(ref literal) => NewNode::EscapedTag(ExEscapedTag {
            nodes: children,
            literal: literal.to_string(),
            sourcepos,
        }),

        NodeValue::Alert(attrs) => NewNode::Alert(ExAlert {
            nodes: children,
            alert_type: match attrs.alert_type {
                comrak::nodes::AlertType::Note => ExAlertType::Note,
                comrak::nodes::AlertType::Tip => ExAlertType::Tip,
                comrak::nodes::AlertType::Important => ExAlertType::Important,
                comrak::nodes::AlertType::Warning => ExAlertType::Warning,
                comrak::nodes::AlertType::Caution => ExAlertType::Caution,
            },
            title: attrs.title.to_owned(),
            multiline: attrs.multiline,
            fence_length: attrs.fence_length,
            fence_offset: attrs.fence_offset,
            sourcepos,
        }),

        NodeValue::HeexBlock(ref attrs) => NewNode::HeexBlock(ExHeexBlock {
            nodes: children,
            literal: attrs.literal.to_string(),
            node: match &attrs.node {
                HeexNode::Directive => "directive".to_string(),
                HeexNode::Comment => "comment".to_string(),
                HeexNode::MultilineComment => "multiline_comment".to_string(),
                HeexNode::Expression => "expression".to_string(),
                HeexNode::Tag(tag) => tag.clone(),
            },
            sourcepos,
        }),

        NodeValue::HeexInline(ref literal) => NewNode::HeexInline(ExHeexInline {
            literal: literal.to_string(),
            sourcepos,
        }),

        NodeValue::BlockDirective(ref attrs) => NewNode::BlockDirective(ExBlockDirective {
            nodes: children,
            info: attrs.info.clone(),
            fence_length: attrs.fence_length,
            fence_offset: attrs.fence_offset,
            sourcepos,
        }),
    }
}

fn string_to_char(s: String) -> u8 {
    s.bytes().next().unwrap_or(0)
}

fn char_to_string(c: u8) -> Result<String, &'static str> {
    if c == 0 {
        return Ok("".to_string());
    }

    match String::from_utf8(vec![c]) {
        Ok(s) => Ok(s),
        Err(_) => Err("failed to convert to string"),
    }
}
