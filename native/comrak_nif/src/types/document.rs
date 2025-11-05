use comrak::{
    nodes::{AstNode, NodeValue},
    Arena,
};

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
        }
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Document"]
pub struct ExDocument {
    pub nodes: Vec<NewNode>,
}

impl From<ExDocument> for NodeValue {
    fn from(node: ExDocument) -> Self {
        NodeValue::Document
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.FrontMatter"]
pub struct ExFrontMatter {
    pub literal: String,
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
}

impl From<ExBlockQuote> for NodeValue {
    fn from(node: ExBlockQuote) -> Self {
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
}

impl From<ExDescriptionList> for NodeValue {
    fn from(node: ExDescriptionList) -> Self {
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
}

impl From<ExDescriptionTerm> for NodeValue {
    fn from(node: ExDescriptionTerm) -> Self {
        NodeValue::DescriptionTerm
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.DescriptionDetails"]
pub struct ExDescriptionDetails {
    pub nodes: Vec<NewNode>,
}

impl From<ExDescriptionDetails> for NodeValue {
    fn from(node: ExDescriptionDetails) -> Self {
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
}

impl From<ExParagraph> for NodeValue {
    fn from(node: ExParagraph) -> Self {
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
pub struct ExThematicBreak {}

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
}

impl From<ExFootnoteReference> for NodeValue {
    fn from(node: ExFootnoteReference) -> Self {
        NodeValue::FootnoteReference(comrak::nodes::NodeFootnoteReference {
            name: node.name.to_string(),
            ref_num: node.ref_num,
            ix: node.ix,
        })
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
}

impl From<ExTaskItem> for NodeValue {
    fn from(node: ExTaskItem) -> Self {
        NodeValue::TaskItem(node.marker.chars().next())
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.SoftBreak"]
pub struct ExSoftBreak {}

impl From<ExSoftBreak> for NodeValue {
    fn from(_node: ExSoftBreak) -> Self {
        NodeValue::SoftBreak
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.LineBreak"]
pub struct ExLineBreak {}

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
}

impl From<ExHtmlInline> for NodeValue {
    fn from(node: ExHtmlInline) -> Self {
        NodeValue::HtmlInline(node.literal.to_string())
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Raw"]
pub struct ExRaw {
    pub literal: String,
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
}

impl From<ExStrikethrough> for NodeValue {
    fn from(_node: ExStrikethrough) -> Self {
        NodeValue::Strikethrough
    }
}

#[derive(Clone, Debug, NifStruct, PartialEq)]
#[module = "MDEx.Superscript"]
pub struct ExSuperscript {
    pub nodes: Vec<NewNode>,
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
pub struct ExEscaped {}

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
}

impl From<ExEscapedTag> for NodeValue {
    fn from(node: ExEscapedTag) -> Self {
        NodeValue::EscapedTag(node.literal.to_string())
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

pub fn ex_document_to_comrak_ast<'a>(
    arena: &'a Arena<AstNode<'a>>,
    new_node: NewNode,
) -> &'a AstNode<'a> {
    let node_value = NodeValue::from(new_node.clone());
    let node_arena = arena.alloc(node_value.into());

    if let NewNode::Document(ExDocument { nodes })
    | NewNode::BlockQuote(ExBlockQuote { nodes })
    | NewNode::List(ExList { nodes, .. })
    | NewNode::ListItem(ExListItem { nodes, .. })
    | NewNode::DescriptionList(ExDescriptionList { nodes })
    | NewNode::DescriptionItem(ExDescriptionItem { nodes, .. })
    | NewNode::DescriptionTerm(ExDescriptionTerm { nodes })
    | NewNode::DescriptionDetails(ExDescriptionDetails { nodes })
    | NewNode::CodeBlock(ExCodeBlock { nodes, .. })
    | NewNode::HtmlBlock(ExHtmlBlock { nodes, .. })
    | NewNode::Paragraph(ExParagraph { nodes })
    | NewNode::Heading(ExHeading { nodes, .. })
    | NewNode::FootnoteDefinition(ExFootnoteDefinition { nodes, .. })
    | NewNode::Table(ExTable { nodes, .. })
    | NewNode::TableRow(ExTableRow { nodes, .. })
    | NewNode::TableCell(ExTableCell { nodes })
    | NewNode::TaskItem(ExTaskItem { nodes, .. })
    | NewNode::Emph(ExEmph { nodes })
    | NewNode::Strong(ExStrong { nodes })
    | NewNode::Link(ExLink { nodes, .. })
    | NewNode::Image(ExImage { nodes, .. })
    | NewNode::Strikethrough(ExStrikethrough { nodes })
    | NewNode::Superscript(ExSuperscript { nodes })
    | NewNode::MultilineBlockQuote(ExMultilineBlockQuote { nodes, .. })
    | NewNode::WikiLink(ExWikiLink { nodes, .. })
    | NewNode::Underline(ExUnderline { nodes })
    | NewNode::Subscript(ExSubscript { nodes })
    | NewNode::SpoileredText(ExSpoileredText { nodes })
    | NewNode::EscapedTag(ExEscapedTag { nodes, .. })
    | NewNode::Alert(ExAlert { nodes, .. }) = new_node
    {
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

    match &node_data.value {
        NodeValue::Document => NewNode::Document(ExDocument { nodes: children }),

        NodeValue::FrontMatter(ref literal) => NewNode::FrontMatter(ExFrontMatter {
            literal: literal.to_string(),
        }),

        NodeValue::BlockQuote => NewNode::BlockQuote(ExBlockQuote { nodes: children }),

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
        }),

        NodeValue::DescriptionList => {
            NewNode::DescriptionList(ExDescriptionList { nodes: children })
        }

        NodeValue::DescriptionItem(ref attrs) => NewNode::DescriptionItem(ExDescriptionItem {
            nodes: children,
            marker_offset: attrs.marker_offset,
            padding: attrs.padding,
            tight: attrs.tight,
        }),

        NodeValue::DescriptionTerm => {
            NewNode::DescriptionTerm(ExDescriptionTerm { nodes: children })
        }

        NodeValue::DescriptionDetails => {
            NewNode::DescriptionDetails(ExDescriptionDetails { nodes: children })
        }

        NodeValue::CodeBlock(attrs) => NewNode::CodeBlock(ExCodeBlock {
            nodes: children,
            fenced: attrs.fenced,
            fence_char: char_to_string(attrs.fence_char).unwrap_or_default(),
            fence_length: attrs.fence_length,
            fence_offset: attrs.fence_offset,
            info: attrs.info.to_string(),
            literal: attrs.literal.to_string(),
            closed: attrs.closed,
        }),

        NodeValue::HtmlBlock(ref attrs) => NewNode::HtmlBlock(ExHtmlBlock {
            nodes: children,
            block_type: attrs.block_type,
            literal: attrs.literal.to_string(),
        }),

        NodeValue::Paragraph => NewNode::Paragraph(ExParagraph { nodes: children }),

        NodeValue::Heading(ref attrs) => NewNode::Heading(ExHeading {
            nodes: children,
            level: attrs.level,
            setext: attrs.setext,
            closed: attrs.closed,
        }),

        NodeValue::ThematicBreak => NewNode::ThematicBreak(ExThematicBreak {}),

        NodeValue::FootnoteDefinition(ref attrs) => {
            NewNode::FootnoteDefinition(ExFootnoteDefinition {
                nodes: children,
                name: attrs.name.to_string(),
                total_references: attrs.total_references,
            })
        }

        NodeValue::FootnoteReference(ref attrs) => {
            NewNode::FootnoteReference(ExFootnoteReference {
                name: attrs.name.to_string(),
                ref_num: attrs.ref_num,
                ix: attrs.ix,
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
        }),

        NodeValue::TableRow(header) => NewNode::TableRow(ExTableRow {
            nodes: children,
            header: *header,
        }),

        NodeValue::TableCell => NewNode::TableCell(ExTableCell { nodes: children }),

        NodeValue::Text(ref literal) => NewNode::Text(ExText {
            literal: literal.to_string(),
        }),

        NodeValue::TaskItem(marker) => NewNode::TaskItem(ExTaskItem {
            nodes: children,
            checked: marker.is_some(),
            marker: marker.map_or_else(String::new, |c| c.to_string()),
        }),

        NodeValue::SoftBreak => NewNode::SoftBreak(ExSoftBreak {}),

        NodeValue::LineBreak => NewNode::LineBreak(ExLineBreak {}),

        NodeValue::Code(ref attrs) => NewNode::Code(ExCode {
            num_backticks: attrs.num_backticks,
            literal: attrs.literal.to_string(),
        }),

        NodeValue::HtmlInline(ref literal) => NewNode::HtmlInline(ExHtmlInline {
            literal: literal.to_string(),
        }),

        NodeValue::Raw(ref literal) => NewNode::Raw(ExRaw {
            literal: literal.to_string(),
        }),

        NodeValue::Emph => NewNode::Emph(ExEmph { nodes: children }),

        NodeValue::Strong => NewNode::Strong(ExStrong { nodes: children }),

        NodeValue::Strikethrough => NewNode::Strikethrough(ExStrikethrough { nodes: children }),

        NodeValue::Superscript => NewNode::Superscript(ExSuperscript { nodes: children }),

        NodeValue::Link(attrs) => NewNode::Link(ExLink {
            nodes: children,
            url: attrs.url.to_string(),
            title: attrs.title.to_string(),
        }),

        NodeValue::Image(attrs) => NewNode::Image(ExImage {
            nodes: children,
            url: attrs.url.to_string(),
            title: attrs.title.to_string(),
        }),

        NodeValue::ShortCode(attrs) => NewNode::ShortCode(ExShortCode {
            code: attrs.code.to_string(),
            emoji: attrs.emoji.to_string(),
        }),

        NodeValue::Math(ref attrs) => NewNode::Math(ExMath {
            dollar_math: attrs.dollar_math,
            display_math: attrs.display_math,
            literal: attrs.literal.to_string(),
        }),

        NodeValue::MultilineBlockQuote(ref attrs) => {
            NewNode::MultilineBlockQuote(ExMultilineBlockQuote {
                nodes: children,
                fence_length: attrs.fence_length,
                fence_offset: attrs.fence_offset,
            })
        }

        NodeValue::Escaped => NewNode::Escaped(ExEscaped {}),

        NodeValue::WikiLink(ref attrs) => NewNode::WikiLink(ExWikiLink {
            nodes: children,
            url: attrs.url.to_string(),
        }),

        NodeValue::Underline => NewNode::Underline(ExUnderline { nodes: children }),

        NodeValue::Subscript => NewNode::Subscript(ExSubscript { nodes: children }),

        NodeValue::SpoileredText => NewNode::SpoileredText(ExSpoileredText { nodes: children }),

        NodeValue::Subtext => NewNode::Subtext(ExSubtext { nodes: children }),

        NodeValue::EscapedTag(ref literal) => NewNode::EscapedTag(ExEscapedTag {
            nodes: children,
            literal: literal.to_string(),
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
        }),
    }
}

fn string_to_char(s: String) -> u8 {
    if s.is_empty() {
        return 0;
    }

    s.chars().next().unwrap_or(' ') as u8
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
