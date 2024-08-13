use crate::types::options::*;
use comrak::{
    nodes::{
        Ast, AstNode, LineColumn, ListDelimType, ListType, NodeCode, NodeCodeBlock,
        NodeDescriptionItem, NodeFootnoteDefinition, NodeFootnoteReference, NodeHeading,
        NodeHtmlBlock, NodeLink, NodeList, NodeMath, NodeMultilineBlockQuote, NodeShortCode,
        NodeTable, NodeValue, NodeWikiLink, TableAlignment,
    },
    Arena, Options,
};
use rustler::{
    types::tuple::get_tuple, Binary, Decoder, Encoder, Env, NifResult, NifTuple, NifUntaggedEnum,
    Term,
};
use std::cell::RefCell;

pub type ExNodeTree = Vec<ExNode>;

#[derive(Debug, Clone, PartialEq)]
pub struct ExNode {
    pub data: ExNodeData,
    pub children: ExNodeChildren,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ExNodeData {
    Document,
    FrontMatter(String),
    BlockQuote,
    List(ExNodeList),
    Item(ExNodeList),
    DescriptionList,
    DescriptionItem(ExNodeDescriptionItem),
    DescriptionTerm,
    DescriptionDetails,
    CodeBlock(ExNodeCodeBlock),
    HtmlBlock(ExNodeHtmlBlock),
    Paragraph,
    Heading(ExNodeHeading),
    ThematicBreak,
    FootnoteDefinition(ExNodeFootnoteDefinition),
    Table(ExNodeTable),
    TableRow(bool),
    TableCell,
    Text(String),
    TaskItem(Option<char>),
    SoftBreak,
    LineBreak,
    Code(ExNodeCode),
    HtmlInline(String),
    Emph,
    Strong,
    Strikethrough,
    Superscript,
    Link(ExNodeLink),
    Image(ExNodeLink),
    FootnoteReference(ExNodeFootnoteReference),
    ShortCode(ExNodeShortCode),
    Math(ExNodeMath),
    MultilineBlockQuote(ExNodeMultilineBlockQuote),
    Escaped,
    WikiLink(ExNodeWikiLink),
    Underline,
    SpoileredText,
    EscapedTag(String),
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeList {
    pub list_type: ExListType,
    pub marker_offset: usize,
    pub padding: usize,
    pub start: usize,
    pub delimiter: ExListDelimType,
    pub bullet_char: u8,
    pub tight: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ExListType {
    Bullet,
    Ordered,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ExListDelimType {
    Period,
    Paren,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeDescriptionItem {
    pub marker_offset: usize,
    pub padding: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeCodeBlock {
    pub fenced: bool,
    pub fence_char: u8,
    pub fence_length: usize,
    pub fence_offset: usize,
    pub info: String,
    pub literal: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeHtmlBlock {
    pub block_type: u8,
    pub literal: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeHeading {
    pub level: u8,
    pub setext: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeFootnoteDefinition {
    pub name: String,
    pub total_references: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeTable {
    pub alignments: Vec<ExTableAlignment>,
    pub num_columns: usize,
    pub num_rows: usize,
    pub num_nonempty_cells: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ExTableAlignment {
    None,
    Left,
    Center,
    Right,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeCode {
    pub num_backticks: usize,
    pub literal: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeLink {
    pub url: String,
    pub title: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeShortCode {
    pub code: String,
    pub emoji: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeFootnoteReference {
    pub name: String,
    pub ref_num: u32,
    pub ix: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeMath {
    pub dollar_math: bool,
    pub display_math: bool,
    pub literal: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeMultilineBlockQuote {
    pub fence_length: usize,
    pub fence_offset: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ExNodeWikiLink {
    pub url: String,
}

pub type ExNodeAttrs = Vec<ExNodeAttr>;
pub type ExNodeChildren = Vec<ExNode>;

#[derive(Debug, Clone, PartialEq, NifTuple)]
pub struct ExNodeAttr(pub String, pub ExNodeAttrValue);

#[derive(Debug, Clone, PartialEq, NifUntaggedEnum)]
pub enum ExNodeAttrValue {
    U8(u8),
    U32(u32),
    Usize(usize),
    Bool(bool),
    Text(String),
    List(Vec<String>),
}

impl ExNode {
    // TODO: error handling
    fn decode_term<'a>(term: Term<'a>) -> Self {
        // println!("term: {:?}", term);

        if term.is_binary() {
            let text: String = term.decode().unwrap();

            ExNode {
                data: ExNodeData::Text(text),
                children: vec![],
            }
        } else if term.is_tuple() {
            let node: Vec<Term<'a>> = get_tuple(term).unwrap();
            ExNode::decode_node(node)
        } else {
            panic!("TODO")
        }
    }

    // decode
    // [node, attrs, children] to ExNode
    fn decode_node<'a>(node: Vec<Term<'a>>) -> Self {
        println!("node: {:?}", node);

        let name = node.get(0).expect("TODO");
        let name = ExNode::decode_node_name(name);
        // println!("name: {:?}", name);

        let attrs = node
            .get(1)
            .expect("TODO")
            .decode::<Vec<Term>>()
            .unwrap_or(vec![]);

        // println!("attrs: {:?}", attrs);

        let children = node.get(2).expect("TODO");
        let children = children.decode::<Vec<Term>>().unwrap();
        let children = children
            .iter()
            .map(|child| ExNode::decode_term(*child))
            .collect();
        // println!("children: {:?}", children);

        match name.as_str() {
            "document" => ExNode {
                data: ExNodeData::Document,
                children,
            },
            // FIXME: front matter content
            "front_matter" => ExNode {
                data: ExNodeData::FrontMatter("TODO".to_string()),
                children,
            },
            "block_quote" => ExNode {
                data: ExNodeData::BlockQuote,
                children,
            },
            "list" => {
                let node_list = ExNodeList::from_attrs(attrs).unwrap();
                ExNode {
                    data: ExNodeData::List(node_list),
                    children,
                }
            }
            "item" => {
                let node_list = ExNodeList::from_attrs(attrs).unwrap();
                ExNode {
                    data: ExNodeData::Item(node_list),
                    children,
                }
            }
            "description_list" => ExNode {
                data: ExNodeData::DescriptionList,
                children,
            },
            // FIXME: description list attrs
            "description_item" => ExNode {
                data: ExNodeData::DescriptionItem(ExNodeDescriptionItem {
                    marker_offset: 0,
                    padding: 2,
                }),
                children,
            },
            "description_term" => ExNode {
                data: ExNodeData::DescriptionTerm,
                children,
            },
            "description_details" => ExNode {
                data: ExNodeData::DescriptionDetails,
                children,
            },
            "code_block" => ExNode {
                data: ExNodeData::code_block_from_attrs(attrs)
                    .expect("failed to decode code_block"),
                children,
            },
            "html_block" => ExNode {
                data: ExNodeData::HtmlBlock(ExNodeHtmlBlock {
                    block_type: 0,
                    literal: "TODO".to_string(),
                }),
                children,
            },
            "paragraph" => ExNode {
                data: ExNodeData::Paragraph,
                children,
            },
            "heading" => ExNode {
                data: ExNodeData::heading_from_attrs(attrs).expect("failed to decode heading"),
                children,
            },
            "thematic_break" => ExNode {
                data: ExNodeData::ThematicBreak,
                children,
            },
            "footnote_definition" => ExNode {
                data: ExNodeData::FootnoteDefinition(ExNodeFootnoteDefinition {
                    name: "TODO".to_string(),
                    total_references: 0,
                }),
                children,
            },
            "table" => ExNode {
                data: ExNodeData::table_from_attrs(attrs).expect("failed to decode table"),
                children,
            },
            "table_row" => ExNode {
                data: ExNodeData::table_row_from_attrs(attrs).expect("failed to decode table row"),
                children,
            },
            "table_cell" => ExNode {
                data: ExNodeData::TableCell,
                children,
            },
            "text" => ExNode {
                data: ExNodeData::Text("TODO".to_string()),
                children,
            },
            "task_item" => ExNode {
                data: ExNodeData::TaskItem(Some('x')),
                children,
            },
            "soft_break" => ExNode {
                data: ExNodeData::SoftBreak,
                children,
            },
            "line_break" => ExNode {
                data: ExNodeData::LineBreak,
                children,
            },
            "code" => ExNode {
                data: ExNodeData::Code(ExNodeCode {
                    num_backticks: 0,
                    literal: "TODO".to_string(),
                }),
                children,
            },
            "html_inline" => ExNode {
                data: ExNodeData::HtmlInline("TODO".to_string()),
                children,
            },
            "emph" => ExNode {
                data: ExNodeData::Emph,
                children,
            },
            "strong" => ExNode {
                data: ExNodeData::Strong,
                children,
            },
            "strikethrough" => ExNode {
                data: ExNodeData::Strikethrough,
                children,
            },
            "superscript" => ExNode {
                data: ExNodeData::Superscript,
                children,
            },
            "link" => ExNode {
                data: ExNodeData::Link(ExNodeLink {
                    url: "TODO".to_string(),
                    title: "TODO".to_string(),
                }),
                children,
            },
            "image" => ExNode {
                data: ExNodeData::Image(ExNodeLink {
                    url: "TODO".to_string(),
                    title: "TODO".to_string(),
                }),
                children,
            },
            "footnote_reference" => ExNode {
                data: ExNodeData::FootnoteReference(ExNodeFootnoteReference {
                    name: "TODO".to_string(),
                    ref_num: 0,
                    ix: 0,
                }),
                children,
            },
            "short_code" => ExNode {
                data: ExNodeData::ShortCode(ExNodeShortCode {
                    code: "TODO".to_string(),
                    emoji: "TODO".to_string(),
                }),
                children,
            },
            "math" => ExNode {
                data: ExNodeData::Math(ExNodeMath {
                    dollar_math: true,
                    display_math: true,
                    literal: "TODO".to_string(),
                }),
                children,
            },
            "multiline_block_quote" => ExNode {
                data: ExNodeData::MultilineBlockQuote(ExNodeMultilineBlockQuote {
                    fence_length: 0,
                    fence_offset: 0,
                }),
                children,
            },
            "escaped" => ExNode {
                data: ExNodeData::Escaped,
                children,
            },
            &_ => todo!("TODO: handle missing or incorrect decode node"),
        }
    }

    // FIXME: find a better way to convert Term to String
    // FIXME: error handling
    fn decode_node_name<'a>(name: &Term<'a>) -> String {
        let name = Binary::from_term(*name).unwrap().as_slice();
        String::from_utf8(name.to_vec()).unwrap()
    }

    pub fn parse_document(md: &str, options: ExOptions) -> ExNodeTree {
        let comrak_options = comrak::Options {
            extension: extension_options_from_ex_options(&options),
            parse: parse_options_from_ex_options(&options),
            render: render_options_from_ex_options(&options),
        };
        let arena = Arena::new();
        let root = comrak::parse_document(&arena, md, &comrak_options);
        vec![Self::from(root)]
    }

    pub fn format_document(&self, options: &Options) -> String {
        let arena = Arena::new();

        if let ExNode {
            data: ExNodeData::Document,
            children,
        } = self
        {
            let mut output = vec![];
            let ast_node = self.to_ast_node(
                &arena,
                ExNode {
                    data: ExNodeData::Document,
                    children: children.to_vec(),
                },
            );
            comrak::html::format_document(ast_node, options, &mut output).unwrap();
            String::from_utf8(output).unwrap()
        } else {
            // TODO: return Result
            panic!("Expected `document` node in AST")
        }
    }

    fn ast<'a>(&self, arena: &'a Arena<AstNode<'a>>, node_value: NodeValue) -> &AstNode<'a> {
        arena.alloc(AstNode::new(RefCell::new(Ast::new(
            node_value,
            LineColumn { line: 0, column: 0 },
        ))))
    }

    // decode
    // ExNode (Elixir) to AstNode (Rust comrak)
    fn to_ast_node<'a>(&'a self, arena: &'a Arena<AstNode<'a>>, exnode: ExNode) -> &'a AstNode<'a> {
        let build = |node_value: NodeValue, children: Vec<ExNode>| {
            let parent = self.ast(arena, node_value);

            for child in children {
                let ast_child = self.to_ast_node(arena, child);
                parent.append(ast_child);
            }

            parent
        };

        println!("exnode: {:?}", exnode);

        match exnode {
            ExNode {
                data: ExNodeData::Document,
                children,
            } => build(NodeValue::Document, children),

            ExNode {
                data: ExNodeData::FrontMatter(ref front_matter),
                children,
            } => build(NodeValue::FrontMatter(front_matter.to_owned()), children),

            ExNode {
                data: ExNodeData::BlockQuote,
                children,
            } => build(NodeValue::BlockQuote, children),

            ExNode {
                data: ExNodeData::List(ref node_list),
                children,
            } => build(NodeValue::List(node_list.to_node_list()), children),

            ExNode {
                data: ExNodeData::Item(ref node_list),
                children,
            } => build(NodeValue::Item(node_list.to_node_list()), children),

            ExNode {
                data: ExNodeData::DescriptionList,
                children,
            } => build(NodeValue::DescriptionList, vec![]),

            ExNode {
                data: ExNodeData::DescriptionItem(ref node_description_item),
                children,
            } => build(
                NodeValue::DescriptionItem(NodeDescriptionItem {
                    marker_offset: node_description_item.marker_offset,
                    padding: node_description_item.padding,
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::DescriptionTerm,
                children,
            } => build(NodeValue::DescriptionTerm, vec![]),

            ExNode {
                data: ExNodeData::DescriptionDetails,
                children,
            } => build(NodeValue::DescriptionDetails, vec![]),

            ExNode {
                data: ExNodeData::CodeBlock(ref node_code_block),
                children,
            } => build(
                NodeValue::CodeBlock(NodeCodeBlock {
                    fenced: node_code_block.fenced,
                    fence_char: node_code_block.fence_char,
                    fence_length: node_code_block.fence_length,
                    fence_offset: node_code_block.fence_offset,
                    info: node_code_block.info.to_owned(),
                    literal: node_code_block.literal.to_owned(),
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::HtmlBlock(ref node_html_block),
                children,
            } => build(
                NodeValue::HtmlBlock(NodeHtmlBlock {
                    block_type: node_html_block.block_type,
                    literal: node_html_block.literal.to_owned(),
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::Paragraph,
                children,
            } => build(NodeValue::Paragraph, children),

            ExNode {
                data: ExNodeData::Heading(ref heading),
                children,
            } => build(
                NodeValue::Heading(NodeHeading {
                    level: heading.level,
                    setext: heading.setext,
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::ThematicBreak,
                children,
            } => build(NodeValue::ThematicBreak, children),

            ExNode {
                data: ExNodeData::FootnoteDefinition(ref footnote_definition),
                children,
            } => build(
                NodeValue::FootnoteDefinition(NodeFootnoteDefinition {
                    name: footnote_definition.name.to_owned(),
                    total_references: footnote_definition.total_references,
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::Table(ref node_table),
                children,
            } => build(
                NodeValue::Table(NodeTable {
                    alignments: ExTableAlignment::to_table_alignments(
                        node_table.alignments.to_owned(),
                    ),
                    num_columns: node_table.num_columns,
                    num_rows: node_table.num_rows,
                    num_nonempty_cells: node_table.num_nonempty_cells,
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::TableRow(ref table_row),
                children,
            } => build(NodeValue::TableRow(*table_row), children),

            ExNode {
                data: ExNodeData::TableCell,
                children,
            } => build(NodeValue::TableCell, children),

            ExNode {
                data: ExNodeData::Text(ref text),
                children,
            } => build(NodeValue::Text(text.to_owned()), children),

            ExNode {
                data: ExNodeData::TaskItem(ref task_item),
                children,
            } => build(NodeValue::TaskItem(*task_item), children),

            ExNode {
                data: ExNodeData::SoftBreak,
                children,
            } => build(NodeValue::SoftBreak, children),

            ExNode {
                data: ExNodeData::LineBreak,
                children,
            } => build(NodeValue::LineBreak, children),

            ExNode {
                data: ExNodeData::Code(ref node_code),
                children,
            } => build(
                NodeValue::Code(NodeCode {
                    num_backticks: node_code.num_backticks,
                    literal: node_code.literal.to_owned(),
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::HtmlInline(html_inline),
                children,
            } => build(NodeValue::HtmlInline(html_inline.to_string()), children),

            ExNode {
                data: ExNodeData::Emph,
                children,
            } => build(NodeValue::Emph, children),

            ExNode {
                data: ExNodeData::Strong,
                children,
            } => build(NodeValue::Strong, children),

            ExNode {
                data: ExNodeData::Strikethrough,
                children,
            } => build(NodeValue::Strikethrough, children),

            ExNode {
                data: ExNodeData::Superscript,
                children,
            } => build(NodeValue::Superscript, children),

            ExNode {
                data: ExNodeData::Link(ref node_link),
                children,
            } => build(
                NodeValue::Link(NodeLink {
                    url: node_link.url.to_owned(),
                    title: node_link.title.to_owned(),
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::Image(ref node_link),
                children,
            } => build(
                NodeValue::Image(NodeLink {
                    url: node_link.url.to_owned(),
                    title: node_link.title.to_owned(),
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::FootnoteReference(ref node_footnote_reference),
                children,
            } => build(
                NodeValue::FootnoteReference(NodeFootnoteReference {
                    name: node_footnote_reference.name.to_owned(),
                    ref_num: node_footnote_reference.ref_num,
                    ix: node_footnote_reference.ix,
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::ShortCode(ref node_shortcode),
                children,
            } => build(
                // TODO: resolve shortcode emoji name
                NodeValue::ShortCode(NodeShortCode::resolve("rocket").unwrap()),
                children,
            ),

            ExNode {
                data: ExNodeData::Math(ref node_math),
                children,
            } => build(
                NodeValue::Math(NodeMath {
                    dollar_math: node_math.dollar_math,
                    display_math: node_math.display_math,
                    literal: node_math.literal.to_owned(),
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::MultilineBlockQuote(ref node_multiline_block_quote),
                children,
            } => build(
                NodeValue::MultilineBlockQuote(NodeMultilineBlockQuote {
                    fence_length: node_multiline_block_quote.fence_length,
                    fence_offset: node_multiline_block_quote.fence_offset,
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::Escaped,
                children,
            } => build(NodeValue::Escaped, children),

            ExNode {
                data: ExNodeData::WikiLink(ref wiki_link),
                children,
            } => build(
                NodeValue::WikiLink(NodeWikiLink {
                    url: wiki_link.url.to_owned(),
                }),
                children,
            ),

            ExNode {
                data: ExNodeData::Underline,
                children,
            } => build(NodeValue::Underline, children),

            ExNode {
                data: ExNodeData::SpoileredText,
                children,
            } => build(NodeValue::SpoileredText, children),

            ExNode {
                data: ExNodeData::EscapedTag(ref escaped_tag),
                children,
            } => build(NodeValue::EscapedTag(escaped_tag.to_owned()), children),
        }
    }
}

// decoding
impl<'a> Decoder<'a> for ExNode {
    fn decode(term: Term<'a>) -> NifResult<Self> {
        let node = ExNode::decode_term(term);
        Ok(node)
    }
}

// encode
// AstNode (Rust comrak) to ExNode (Elixir)
impl<'a> From<&'a AstNode<'a>> for ExNode {
    fn from(ast_node: &'a AstNode<'a>) -> Self {
        let children = ast_node.children().map(Self::from).collect::<Vec<_>>();
        let node_value = &ast_node.data.borrow().value;

        // println!("encode astnode to exnode: {:?}", node_value);

        match node_value {
            NodeValue::Document => Self {
                data: ExNodeData::Document,
                children,
            },

            NodeValue::FrontMatter(ref content) => Self {
                data: ExNodeData::FrontMatter(content.to_string()),
                children,
            },

            NodeValue::BlockQuote => Self {
                data: ExNodeData::BlockQuote,
                children,
            },

            NodeValue::List(ref node_list) => Self {
                data: ExNodeData::List(ExNodeList {
                    list_type: ExListType::from_list_type(node_list.list_type),
                    marker_offset: node_list.marker_offset,
                    padding: node_list.padding,
                    start: node_list.start,
                    delimiter: ExListDelimType::from_list_delim_type(node_list.delimiter),
                    bullet_char: node_list.bullet_char,
                    tight: node_list.tight,
                }),
                children,
            },

            NodeValue::Item(ref node_list) => Self {
                data: ExNodeData::Item(ExNodeList {
                    list_type: ExListType::from_list_type(node_list.list_type),
                    marker_offset: node_list.marker_offset,
                    padding: node_list.padding,
                    start: node_list.start,
                    delimiter: ExListDelimType::from_list_delim_type(node_list.delimiter),
                    bullet_char: node_list.bullet_char,
                    tight: node_list.tight,
                }),
                children,
            },

            NodeValue::DescriptionList => Self {
                data: ExNodeData::DescriptionList,
                children,
            },

            NodeValue::DescriptionItem(ref description_item) => Self {
                data: ExNodeData::DescriptionItem(ExNodeDescriptionItem {
                    marker_offset: description_item.marker_offset,
                    padding: description_item.padding,
                }),
                children,
            },

            NodeValue::DescriptionTerm => Self {
                data: ExNodeData::DescriptionTerm,
                children,
            },

            NodeValue::DescriptionDetails => Self {
                data: ExNodeData::DescriptionDetails,
                children,
            },

            NodeValue::CodeBlock(ref code_block) => Self {
                data: ExNodeData::CodeBlock(ExNodeCodeBlock {
                    fenced: code_block.fenced,
                    fence_char: code_block.fence_char,
                    fence_length: code_block.fence_length,
                    fence_offset: code_block.fence_offset,
                    info: code_block.info.to_string(),
                    literal: code_block.literal.to_string(),
                }),
                children,
            },

            NodeValue::HtmlBlock(ref html_block) => Self {
                data: ExNodeData::HtmlBlock(ExNodeHtmlBlock {
                    block_type: html_block.block_type,
                    literal: html_block.literal.to_string(),
                }),
                children,
            },

            NodeValue::Paragraph => Self {
                data: ExNodeData::Paragraph,
                children,
            },

            NodeValue::Heading(ref heading) => Self {
                data: ExNodeData::Heading(ExNodeHeading {
                    level: heading.level,
                    setext: heading.setext,
                }),
                children,
            },

            NodeValue::ThematicBreak => Self {
                data: ExNodeData::ThematicBreak,
                children,
            },

            NodeValue::FootnoteDefinition(ref footnote_definition) => Self {
                data: ExNodeData::FootnoteDefinition(ExNodeFootnoteDefinition {
                    name: footnote_definition.name.to_string(),
                    total_references: footnote_definition.total_references,
                }),
                children,
            },

            NodeValue::Table(ref table) => Self {
                data: ExNodeData::Table(ExNodeTable {
                    alignments: ExTableAlignment::from_table_alignments(table.alignments.to_vec()),
                    num_columns: table.num_columns,
                    num_rows: table.num_rows,
                    num_nonempty_cells: table.num_nonempty_cells,
                }),
                children,
            },

            NodeValue::TableRow(ref header) => Self {
                data: ExNodeData::TableRow(*header),
                children,
            },

            NodeValue::TableCell => Self {
                data: ExNodeData::TableCell,
                children,
            },

            NodeValue::Text(ref text) => Self {
                data: ExNodeData::Text(text.to_string()),
                children: vec![],
            },

            NodeValue::TaskItem(ref symbol) => Self {
                data: ExNodeData::TaskItem(*symbol),
                children,
            },

            NodeValue::SoftBreak => Self {
                data: ExNodeData::SoftBreak,
                children,
            },
            NodeValue::LineBreak => Self {
                data: ExNodeData::LineBreak,
                children,
            },

            NodeValue::Code(ref code) => Self {
                data: ExNodeData::Code(ExNodeCode {
                    num_backticks: code.num_backticks,
                    literal: code.literal.to_string(),
                }),
                children,
            },

            NodeValue::HtmlInline(ref raw_html) => Self {
                data: ExNodeData::HtmlInline(raw_html.to_string()),
                children,
            },

            NodeValue::Emph => Self {
                data: ExNodeData::Emph,
                children,
            },

            NodeValue::Strong => Self {
                data: ExNodeData::Strong,
                children,
            },

            NodeValue::Strikethrough => Self {
                data: ExNodeData::Strikethrough,
                children,
            },

            NodeValue::Superscript => Self {
                data: ExNodeData::Superscript,
                children,
            },

            NodeValue::Link(ref link) => Self {
                data: ExNodeData::Link(ExNodeLink {
                    url: link.url.to_string(),
                    title: link.title.to_string(),
                }),
                children,
            },

            NodeValue::Image(ref link) => Self {
                data: ExNodeData::Image(ExNodeLink {
                    url: link.url.to_string(),
                    title: link.title.to_string(),
                }),
                children,
            },

            NodeValue::FootnoteReference(ref footnote_reference) => Self {
                data: ExNodeData::FootnoteReference(ExNodeFootnoteReference {
                    name: footnote_reference.name.to_string(),
                    ref_num: footnote_reference.ref_num,
                    ix: footnote_reference.ix,
                }),
                children,
            },

            NodeValue::ShortCode(ref short_code) => Self {
                data: ExNodeData::ShortCode(ExNodeShortCode {
                    code: short_code.code.to_string(),
                    emoji: short_code.emoji.to_string(),
                }),
                children,
            },

            NodeValue::Math(ref math) => Self {
                data: ExNodeData::Math(ExNodeMath {
                    dollar_math: math.dollar_math,
                    display_math: math.display_math,
                    literal: math.literal.to_string(),
                }),
                children,
            },

            NodeValue::MultilineBlockQuote(ref multiline_block_quote) => Self {
                data: ExNodeData::MultilineBlockQuote(ExNodeMultilineBlockQuote {
                    fence_length: multiline_block_quote.fence_length,
                    fence_offset: multiline_block_quote.fence_offset,
                }),
                children,
            },

            NodeValue::Escaped => Self {
                data: ExNodeData::Escaped,
                children,
            },

            NodeValue::WikiLink(ref wiki_link) => Self {
                data: ExNodeData::WikiLink(ExNodeWikiLink {
                    url: wiki_link.url.to_string(),
                }),
                children,
            },

            NodeValue::Underline => Self {
                data: ExNodeData::Underline,
                children,
            },

            NodeValue::SpoileredText => Self {
                data: ExNodeData::SpoileredText,
                children,
            },

            NodeValue::EscapedTag(ref tag) => Self {
                data: ExNodeData::EscapedTag(tag.to_string()),
                children,
            },
        }
    }
}

impl<'a> From<Term<'a>> for ExNode {
    fn from(term: Term<'a>) -> Self {
        // println!("from term: {:?}", term);

        if term.is_binary() {
            let text: String = term.decode().unwrap();
            ExNode {
                data: ExNodeData::Text(text),
                children: vec![],
            }
        } else {
            ExNode {
                data: ExNodeData::Text("TODO".to_string()),
                children: vec![],
            }
        }
    }
}

// encode
// ExNode to [node, attrs, children]
impl Encoder for ExNode {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        // println!("encode exnode to list: {:?}", self);

        match self {
            // document
            ExNode {
                data: ExNodeData::Document,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("document".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // front matter
            ExNode {
                data: ExNodeData::FrontMatter(delimiter),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "front_matter".to_string(),
                    vec![ExNodeAttr(
                        "content".to_string(),
                        ExNodeAttrValue::Text(delimiter.to_string()),
                    )],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // block quote
            ExNode {
                data: ExNodeData::BlockQuote,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("block_quote".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // list
            ExNode {
                data: ExNodeData::List(list),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "list".to_string(),
                    vec![
                        ExNodeAttr(
                            "list_type".to_string(),
                            ExNodeAttrValue::Text(list.list_type.to_string()),
                        ),
                        ExNodeAttr(
                            "marker_offset".to_string(),
                            ExNodeAttrValue::Usize(list.marker_offset),
                        ),
                        ExNodeAttr("padding".to_string(), ExNodeAttrValue::Usize(list.padding)),
                        ExNodeAttr("start".to_string(), ExNodeAttrValue::Usize(list.start)),
                        ExNodeAttr(
                            "delimiter".to_string(),
                            ExNodeAttrValue::Text(list.delimiter.to_string()),
                        ),
                        ExNodeAttr(
                            "bullet_char".to_string(),
                            ExNodeAttrValue::Text(
                                char_to_string(list.bullet_char).unwrap_or_default(),
                            ),
                        ),
                        ExNodeAttr("tight".to_string(), ExNodeAttrValue::Bool(list.tight)),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // item
            ExNode {
                data: ExNodeData::Item(list),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "item".to_string(),
                    vec![
                        ExNodeAttr(
                            "list_type".to_string(),
                            ExNodeAttrValue::Text(list.list_type.to_string()),
                        ),
                        ExNodeAttr(
                            "marker_offset".to_string(),
                            ExNodeAttrValue::Usize(list.marker_offset),
                        ),
                        ExNodeAttr("padding".to_string(), ExNodeAttrValue::Usize(list.padding)),
                        ExNodeAttr("start".to_string(), ExNodeAttrValue::Usize(list.start)),
                        ExNodeAttr(
                            "delimiter".to_string(),
                            ExNodeAttrValue::Text(list.delimiter.to_string()),
                        ),
                        ExNodeAttr(
                            "bullet_char".to_string(),
                            ExNodeAttrValue::Text(
                                char_to_string(list.bullet_char).unwrap_or_default(),
                            ),
                        ),
                        ExNodeAttr("tight".to_string(), ExNodeAttrValue::Bool(list.tight)),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // description list
            ExNode {
                data: ExNodeData::DescriptionList,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("description_list".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // description item
            ExNode {
                data: ExNodeData::DescriptionItem(node_description_item),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "description_item".to_string(),
                    vec![
                        ExNodeAttr(
                            "marker_offset".to_string(),
                            ExNodeAttrValue::Usize(node_description_item.marker_offset),
                        ),
                        ExNodeAttr(
                            "padding".to_string(),
                            ExNodeAttrValue::Usize(node_description_item.padding),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // description term
            ExNode {
                data: ExNodeData::DescriptionTerm,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("description_term".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // description details
            ExNode {
                data: ExNodeData::DescriptionDetails,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("description_details".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // code block
            ExNode {
                data: ExNodeData::CodeBlock(code_block),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "code_block".to_string(),
                    vec![
                        ExNodeAttr(
                            "fenced".to_string(),
                            ExNodeAttrValue::Bool(code_block.fenced),
                        ),
                        ExNodeAttr(
                            "fence_char".to_string(),
                            ExNodeAttrValue::Text(
                                char_to_string(code_block.fence_char).unwrap_or_default(),
                            ),
                        ),
                        ExNodeAttr(
                            "fence_length".to_string(),
                            ExNodeAttrValue::Usize(code_block.fence_length),
                        ),
                        ExNodeAttr(
                            "fence_offset".to_string(),
                            ExNodeAttrValue::Usize(code_block.fence_offset),
                        ),
                        ExNodeAttr(
                            "info".to_string(),
                            ExNodeAttrValue::Text(code_block.info.to_string()),
                        ),
                        ExNodeAttr(
                            "literal".to_string(),
                            ExNodeAttrValue::Text(code_block.literal.to_string()),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // html block
            ExNode {
                data: ExNodeData::HtmlBlock(html_block),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "html_block".to_string(),
                    vec![
                        ExNodeAttr(
                            "block_type".to_string(),
                            ExNodeAttrValue::U8(html_block.block_type),
                        ),
                        ExNodeAttr(
                            "literal".to_string(),
                            ExNodeAttrValue::Text(html_block.literal.to_string()),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // paragraph
            ExNode {
                data: ExNodeData::Paragraph,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("paragraph".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // heading
            ExNode {
                data: ExNodeData::Heading(heading),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "heading".to_string(),
                    vec![
                        ExNodeAttr("level".to_string(), ExNodeAttrValue::U8(heading.level)),
                        ExNodeAttr("setext".to_string(), ExNodeAttrValue::Bool(heading.setext)),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // thematic break
            ExNode {
                data: ExNodeData::ThematicBreak,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("thematic_break".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // footnote definition
            ExNode {
                data: ExNodeData::FootnoteDefinition(footnote_definition),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "footnote_definition".to_string(),
                    vec![
                        ExNodeAttr(
                            "name".to_string(),
                            ExNodeAttrValue::Text(footnote_definition.name.to_string()),
                        ),
                        ExNodeAttr(
                            "total_references".to_string(),
                            ExNodeAttrValue::U32(footnote_definition.total_references),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // table
            ExNode {
                data: ExNodeData::Table(table),
                children,
            } => {
                let alignments: Vec<String> = table
                    .alignments
                    .iter()
                    .map(|alignment| alignment.to_string())
                    .collect();

                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "table".to_string(),
                    vec![
                        ExNodeAttr("alignments".to_string(), ExNodeAttrValue::List(alignments)),
                        ExNodeAttr(
                            "num_columns".to_string(),
                            ExNodeAttrValue::Usize(table.num_columns),
                        ),
                        ExNodeAttr(
                            "num_rows".to_string(),
                            ExNodeAttrValue::Usize(table.num_rows),
                        ),
                        ExNodeAttr(
                            "num_nonempty_cells".to_string(),
                            ExNodeAttrValue::Usize(table.num_nonempty_cells),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // table row
            ExNode {
                data: ExNodeData::TableRow(header),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "table_row".to_string(),
                    vec![ExNodeAttr(
                        "header".to_string(),
                        ExNodeAttrValue::Bool(*header),
                    )],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // table cell
            ExNode {
                data: ExNodeData::TableCell,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("table_cell".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // text
            ExNode {
                data: ExNodeData::Text(text),
                children,
            } => text.encode(env),

            // task item
            ExNode {
                data: ExNodeData::TaskItem(symbol),
                children,
            } => {
                let symbol = symbol.unwrap_or(' ');

                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "task_item".to_string(),
                    vec![ExNodeAttr(
                        "symbol".to_string(),
                        ExNodeAttrValue::Text(symbol.to_string()),
                    )],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // soft break
            ExNode {
                data: ExNodeData::SoftBreak,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("soft_break".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // line break
            ExNode {
                data: ExNodeData::LineBreak,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("line_break".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // code
            ExNode {
                data: ExNodeData::Code(code),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "code".to_string(),
                    vec![
                        ExNodeAttr(
                            "num_backticks".to_string(),
                            ExNodeAttrValue::Usize(code.num_backticks),
                        ),
                        ExNodeAttr(
                            "literal".to_string(),
                            ExNodeAttrValue::Text(code.literal.to_string()),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // html inline
            ExNode {
                data: ExNodeData::HtmlInline(raw_html),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "code".to_string(),
                    vec![ExNodeAttr(
                        "raw_html".to_string(),
                        ExNodeAttrValue::Text(raw_html.to_string()),
                    )],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // emph
            ExNode {
                data: ExNodeData::Emph,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("emph".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // strong
            ExNode {
                data: ExNodeData::Strong,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("strong".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // strikethrough
            ExNode {
                data: ExNodeData::Strikethrough,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("strikethrough".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // superscript
            ExNode {
                data: ExNodeData::Superscript,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("superscript".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // link
            ExNode {
                data: ExNodeData::Link(link),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "link".to_string(),
                    vec![
                        ExNodeAttr(
                            "url".to_string(),
                            ExNodeAttrValue::Text(link.url.to_string()),
                        ),
                        ExNodeAttr(
                            "title".to_string(),
                            ExNodeAttrValue::Text(link.title.to_string()),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // image
            ExNode {
                data: ExNodeData::Image(link),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "image".to_string(),
                    vec![
                        ExNodeAttr(
                            "url".to_string(),
                            ExNodeAttrValue::Text(link.url.to_string()),
                        ),
                        ExNodeAttr(
                            "title".to_string(),
                            ExNodeAttrValue::Text(link.title.to_string()),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // footnote reference
            ExNode {
                data: ExNodeData::FootnoteReference(footnote_reference),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "footnote_reference".to_string(),
                    vec![
                        ExNodeAttr(
                            "name".to_string(),
                            ExNodeAttrValue::Text(footnote_reference.name.to_string()),
                        ),
                        ExNodeAttr(
                            "ref_num".to_string(),
                            ExNodeAttrValue::U32(footnote_reference.ref_num),
                        ),
                        ExNodeAttr(
                            "ix".to_string(),
                            ExNodeAttrValue::U32(footnote_reference.ix),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }
            ExNode {
                data: ExNodeData::ShortCode(short_code),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "short_code".to_string(),
                    vec![
                        ExNodeAttr(
                            "name".to_string(),
                            ExNodeAttrValue::Text(short_code.code.to_string()),
                        ),
                        ExNodeAttr(
                            "emoji".to_string(),
                            ExNodeAttrValue::Text(short_code.emoji.to_string()),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // short code

            // math
            ExNode {
                data: ExNodeData::Math(math),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "math".to_string(),
                    vec![
                        ExNodeAttr(
                            "dollar_math".to_string(),
                            ExNodeAttrValue::Bool(math.dollar_math),
                        ),
                        ExNodeAttr(
                            "display_math".to_string(),
                            ExNodeAttrValue::Bool(math.display_math),
                        ),
                        ExNodeAttr(
                            "literal".to_string(),
                            ExNodeAttrValue::Text(math.literal.to_string()),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // multiline block quote
            ExNode {
                data: ExNodeData::MultilineBlockQuote(multline_block_quote),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "multiline_block_quote".to_string(),
                    vec![
                        ExNodeAttr(
                            "fence_length".to_string(),
                            ExNodeAttrValue::Usize(multline_block_quote.fence_length),
                        ),
                        ExNodeAttr(
                            "fence_offset".to_string(),
                            ExNodeAttrValue::Usize(multline_block_quote.fence_offset),
                        ),
                    ],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // escaped
            ExNode {
                data: ExNodeData::Escaped,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("escaped".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // wiki link
            ExNode {
                data: ExNodeData::WikiLink(wiki_link),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "wiki_link".to_string(),
                    vec![ExNodeAttr(
                        "url".to_string(),
                        ExNodeAttrValue::Text(wiki_link.url.clone()),
                    )],
                    children.to_vec(),
                );
                doc.encode(env)
            }

            // underline
            ExNode {
                data: ExNodeData::Underline,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("underline".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // spoiler
            ExNode {
                data: ExNodeData::SpoileredText,
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) =
                    ("spoilered_text".to_string(), vec![], children.to_vec());
                doc.encode(env)
            }

            // escaped tag
            ExNode {
                data: ExNodeData::EscapedTag(tag),
                children,
            } => {
                let doc: (String, ExNodeAttrs, ExNodeChildren) = (
                    "escaped_tag".to_string(),
                    vec![ExNodeAttr(
                        "content".to_string(),
                        ExNodeAttrValue::Text(tag.to_string()),
                    )],
                    children.to_vec(),
                );
                doc.encode(env)
            }
        }
    }
}

impl<'a> From<Term<'a>> for ExNodeAttr {
    fn from(term: Term<'a>) -> Self {
        let term = get_tuple(term).unwrap();

        let name: String = term.get(0).unwrap().decode().unwrap();

        let value = *term.get(1).unwrap();
        let value: ExNodeAttrValue = ExNodeAttrValue::from(value);

        ExNodeAttr(name, value)
    }
}

impl<'a> From<Term<'a>> for ExNodeAttrValue {
    fn from(term: Term<'a>) -> Self {
        // println!("term: {:?}", term.get_type());

        ExNodeAttrValue::Text("todo".to_string())
    }
}

impl ExNodeList {
    fn default() -> Self {
        ExNodeList {
            list_type: ExListType::Bullet,
            marker_offset: 0,
            padding: 0,
            start: 0,
            delimiter: ExListDelimType::Period,
            bullet_char: 0,
            tight: false,
        }
    }

    fn from_attrs<'a>(attrs: Vec<Term<'a>>) -> NifResult<Self> {
        let mut node_list = Self::default();

        for attr in attrs {
            let (key, value) = attr.decode::<(String, Term)>().unwrap();

            match key.as_str() {
                "list_type" => node_list.list_type = ExListType::from_attr(value.decode()?),
                "marker_offset" => node_list.marker_offset = value.decode()?,
                "padding" => node_list.padding = value.decode()?,
                "start" => node_list.start = value.decode()?,
                "delimiter" => node_list.delimiter = ExListDelimType::from_attr(value.decode()?),
                "tight" => node_list.tight = value.decode()?,
                _ => {}
            }
        }

        Ok(node_list)
    }

    fn to_node_list(&self) -> NodeList {
        NodeList {
            list_type: ExListType::to_list_type(&self.list_type),
            marker_offset: self.marker_offset,
            padding: self.padding,
            start: self.start,
            delimiter: ExListDelimType::to_list_delim_type(&self.delimiter),
            bullet_char: self.bullet_char,
            tight: self.tight,
        }
    }
}

impl ExListType {
    fn default() -> Self {
        Self::Bullet
    }

    fn from_list_type(list_type: ListType) -> Self {
        match list_type {
            ListType::Bullet => Self::Bullet,
            ListType::Ordered => Self::Ordered,
        }
    }

    fn to_list_type(&self) -> ListType {
        match self {
            Self::Bullet => ListType::Bullet,
            Self::Ordered => ListType::Ordered,
        }
    }

    fn from_attr(list_type: &str) -> Self {
        match list_type {
            "bullet" => Self::Bullet,
            "ordered" => Self::Ordered,
            _ => Self::default(),
        }
    }
}

impl ToString for ExListType {
    fn to_string(&self) -> String {
        match self {
            ExListType::Bullet => "bullet".to_string(),
            ExListType::Ordered => "ordered".to_string(),
        }
    }
}

impl ExListDelimType {
    fn default() -> Self {
        Self::Period
    }

    fn from_list_delim_type(list_delim_type: ListDelimType) -> Self {
        match list_delim_type {
            ListDelimType::Period => Self::Period,
            ListDelimType::Paren => Self::Paren,
        }
    }

    fn to_list_delim_type(&self) -> ListDelimType {
        match self {
            Self::Period => ListDelimType::Period,
            Self::Paren => ListDelimType::Paren,
        }
    }

    fn from_attr(list_delim_type: &str) -> Self {
        match list_delim_type {
            "period" => Self::Period,
            "paren" => Self::Paren,
            _ => Self::default(),
        }
    }
}

impl ToString for ExListDelimType {
    fn to_string(&self) -> String {
        match self {
            ExListDelimType::Period => "period".to_string(),
            ExListDelimType::Paren => "paren".to_string(),
        }
    }
}

fn char_to_string(c: u8) -> Result<String, &'static str> {
    // println!("char_to_string: {:?}", c);

    if c == 0 {
        return Ok("".to_string());
    }

    match String::from_utf8(vec![c]) {
        Ok(s) => Ok(s),
        Err(_) => Err("failed to convert to string"),
    }
}

fn string_to_char(c: String) -> Option<u8> {
    let value = c.chars().next().unwrap();
    if value.is_ascii() {
        Some(value as u8)
    } else {
        None
    }
}

impl ExTableAlignment {
    fn from_table_alignments(alignments: Vec<TableAlignment>) -> Vec<Self> {
        alignments
            .iter()
            .map(|&ta| Self::from_table_alignment(ta))
            .collect::<Vec<Self>>()
    }

    fn from_table_alignment(alignment: TableAlignment) -> Self {
        match alignment {
            TableAlignment::None => Self::None,
            TableAlignment::Left => Self::Left,
            TableAlignment::Center => Self::Center,
            TableAlignment::Right => Self::Right,
        }
    }

    fn from_terms(alignments: Vec<Term>) -> Vec<Self> {
        alignments
            .iter()
            .map(|&ta| match ta.decode().unwrap() {
                "none" => Self::None,
                "left" => Self::Left,
                "center" => Self::Center,
                "right" => Self::Right,
                _ => panic!("invalid table alignment"),
            })
            .collect::<Vec<Self>>()
    }

    fn to_table_alignments(alignments: Vec<ExTableAlignment>) -> Vec<TableAlignment> {
        alignments
            .iter()
            .map(|ta| Self::to_table_alignment(ta.clone()))
            .collect::<Vec<TableAlignment>>()
    }

    fn to_table_alignment(alignment: ExTableAlignment) -> TableAlignment {
        match alignment {
            ExTableAlignment::None => TableAlignment::None,
            ExTableAlignment::Left => TableAlignment::Left,
            ExTableAlignment::Center => TableAlignment::Center,
            ExTableAlignment::Right => TableAlignment::Right,
        }
    }
}

impl ToString for ExTableAlignment {
    fn to_string(&self) -> String {
        match self {
            Self::None => "none".to_string(),
            Self::Left => "left".to_string(),
            Self::Center => "center".to_string(),
            Self::Right => "right".to_string(),
        }
    }
}

impl ExNodeData {
    fn heading_from_attrs(attrs: Vec<Term>) -> Result<Self, &'static str> {
        let mut level: Option<u8> = None;
        let mut setext: Option<bool> = None;

        for term in attrs {
            let (name, value): (&str, Term) = term.decode().unwrap();

            match (name, value) {
                ("level", _) => level = value.decode().ok(),
                ("setext", _) => setext = value.decode().ok(),
                (_name, _) => return Err("unexpected attribute"),
            }
        }

        Ok(ExNodeData::Heading(ExNodeHeading {
            level: level.ok_or("attr alignments is missing or invalid")?,
            setext: setext.ok_or("attr num_columns is missing or invalid")?,
        }))
    }

    fn table_from_attrs(attrs: Vec<Term>) -> Result<Self, &'static str> {
        let mut alignments: Option<Vec<ExTableAlignment>> = None;
        let mut num_columns: Option<usize> = None;
        let mut num_rows: Option<usize> = None;
        let mut num_nonempty_cells: Option<usize> = None;

        for term in attrs {
            let (name, value): (&str, Term) = term.decode().unwrap();

            match (name, value) {
                ("alignments", _) => {
                    // FIXME: improve this code
                    let v: Vec<Term> = value.decode().unwrap();
                    let vv = ExTableAlignment::from_terms(v);
                    alignments = Some(vv);
                }
                ("num_columns", _) => num_columns = value.decode().ok(),
                ("num_rows", _) => num_rows = value.decode().ok(),
                ("num_nonempty_cells", _) => num_nonempty_cells = value.decode().ok(),
                (_name, _) => return Err("unexpected attribute"),
            }
        }

        Ok(ExNodeData::Table(ExNodeTable {
            alignments: alignments.ok_or("attr alignments is missing or invalid")?,
            num_columns: num_columns.ok_or("attr num_columns is missing or invalid")?,
            num_rows: num_rows.ok_or("attr num_rows is missing or invalid")?,
            num_nonempty_cells: num_nonempty_cells
                .ok_or("attr num_nonempty_cells is missing or invalid")?,
        }))
    }

    fn table_row_from_attrs(attrs: Vec<Term>) -> Result<Self, &'static str> {
        for &term in &attrs {
            let (name, value): (&str, Term) = term.decode().unwrap();
            if name == "header" {
                let header: bool = value.decode().expect("attr header is missing or invalid");
                return Ok(ExNodeData::TableRow(header));
            }
        }

        Err("attr header is missing or invalid")
    }

    fn code_block_from_attrs(attrs: Vec<Term>) -> Result<Self, &'static str> {
        let mut fenced: Option<bool> = None;
        let mut fence_char: Option<u8> = None;
        let mut fence_length: Option<usize> = None;
        let mut fence_offset: Option<usize> = None;
        let mut info: Option<String> = None;
        let mut literal: Option<String> = None;

        for term in attrs {
            let (name, value): (&str, Term) = term.decode().unwrap();

            match (name, value) {
                ("fenced", _) => fenced = value.decode().ok(),
                ("fence_char", _) => {
                    let fence_char_string: NifResult<String> = value.decode();

                    match fence_char_string {
                        Ok(c) => {
                            fence_char = string_to_char(c);
                        }
                        Err(e) => {
                            return Err("failed to convert fence_char");
                        }
                    }
                }
                ("fence_length", _) => fence_length = value.decode().ok(),
                ("fence_offset", _) => fence_offset = value.decode().ok(),
                ("info", _) => info = value.decode().ok(),
                ("literal", _) => literal = value.decode().ok(),
                (_name, _) => return Err("unexpected attribute"),
            }
        }

        Ok(ExNodeData::CodeBlock(ExNodeCodeBlock {
            fenced: fenced.ok_or("attr fenced is missing or invalid")?,
            fence_char: fence_char.ok_or("attr fence_char is missing or invalid")?,
            fence_length: fence_length.ok_or("attr fence_length is missing or invalid")?,
            fence_offset: fence_offset.ok_or("attr fence_offset is missing or invalid")?,
            info: info.ok_or("attr info is missing or invalid")?,
            literal: literal.ok_or("attr literal is missing or invalid")?,
        }))
    }
}
