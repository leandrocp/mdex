use rustler::NifUntaggedEnum;

#[derive(Debug, Clone, PartialEq, NifUntaggedEnum)]
pub enum AttrValue {
    U8(u8),
    U32(u32),
    Usize(usize),
    Bool(bool),
    Text(String),
    List(Vec<String>),
}

#[derive(Debug, Clone, PartialEq)]
pub enum ExNode<'a> {
    Element {
        name: &'a str,
        attrs: Vec<(&'a str, AttrValue)>,
        children: Vec<ExNode<'a>>,
    },
    Text(String),
}
