use rustler::{Encoder, Env, NifUntaggedEnum, Term};

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

impl<'a> Encoder for ExNode<'a> {
    fn encode<'b>(&self, env: Env<'b>) -> Term<'b> {
        match self {
            Self::Text(text) => text.encode(env),

            Self::Element {
                name,
                attrs,
                children,
            } => {
                let mut attr_list = Vec::new();

                for (key, value) in attrs {
                    let attr_value = match value {
                        AttrValue::U8(v) => (key, v.encode(env)),
                        AttrValue::U32(v) => (key, v.encode(env)),
                        AttrValue::Usize(v) => (key, v.encode(env)),
                        AttrValue::Bool(v) => (key, v.encode(env)),
                        AttrValue::Text(v) => (key, v.encode(env)),
                        AttrValue::List(v) => (key, v.encode(env)),
                    };

                    attr_list.push(attr_value);
                }

                (name, attr_list, children).encode(env)
            }
        }
    }
}
