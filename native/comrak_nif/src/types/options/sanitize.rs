#![allow(clippy::type_complexity)]

use std::{
    borrow::Borrow,
    collections::{HashMap, HashSet},
};

use ammonia::{Builder, Url, UrlRelative};

// Utility functions to turn e.g. &'a Vec<String> into HashSet<&'a str>,
// &'a HashMap<String, String> into HashMap<&'a str, &'a str>, etc.
//
// We use the former types because they store our options from Elixir nicely
// (with automatic Decoder impls from rustler), and the latter types are what
// ammonia take.
//
// These could be written with concrete inputs (&Vec<String> instead of <I:
// IntoIterator<...>>), but this gives us some flexibility later if we decide to
// change the storage.

fn borrowed_set<'a, I, K>(it: I) -> HashSet<&'a str>
where
    I: IntoIterator<Item = &'a K>,
    K: 'a + ?Sized + Borrow<str>,
{
    it.into_iter().map(|s| s.borrow()).collect()
}

fn borrowed_map<'a, I, K, V>(it: I) -> HashMap<&'a str, &'a str>
where
    I: IntoIterator<Item = (&'a K, &'a V)>,
    K: 'a + ?Sized + Borrow<str>,
    V: 'a + ?Sized + Borrow<str>,
{
    it.into_iter()
        .map(|(key, val)| (key.borrow(), val.borrow()))
        .collect()
}

fn borrowed_map_set<'a, KI, K, VI, V>(it: KI) -> HashMap<&'a str, HashSet<&'a str>>
where
    KI: IntoIterator<Item = (&'a K, VI)>,
    K: 'a + ?Sized + Borrow<str>,
    VI: IntoIterator<Item = &'a V>,
    V: 'a + ?Sized + Borrow<str>,
{
    it.into_iter()
        .map(|(key, vals)| (key.borrow(), borrowed_set(vals)))
        .collect()
}

fn borrowed_map_map<'a, TI, T, AI, A, V>(it: TI) -> HashMap<&'a str, HashMap<&'a str, &'a str>>
where
    TI: IntoIterator<Item = (&'a T, AI)>,
    T: 'a + ?Sized + Borrow<str>,
    AI: IntoIterator<Item = (&'a A, &'a V)>,
    A: 'a + ?Sized + Borrow<str>,
    V: 'a + ?Sized + Borrow<str>,
{
    it.into_iter()
        .map(|(key, vals)| (key.borrow(), borrowed_map(vals)))
        .collect()
}

fn borrowed_map_map_set<'a, TI, T, AI, A, VI, V>(
    it: TI,
) -> HashMap<&'a str, HashMap<&'a str, HashSet<&'a str>>>
where
    TI: IntoIterator<Item = (&'a T, AI)>,
    T: 'a + ?Sized + Borrow<str>,
    AI: IntoIterator<Item = (&'a A, VI)>,
    A: 'a + ?Sized + Borrow<str>,
    VI: IntoIterator<Item = &'a V>,
    V: 'a + ?Sized + Borrow<str>,
{
    it.into_iter()
        .map(|(key, vals)| (key.borrow(), borrowed_map_set(vals)))
        .collect()
}

// ammonia exposes many options which can be set (discard previous value,
// assign new one), added to (append/merge with previous value), or removed
// from (subtract from previous value).  We let the user choose which of these
// operations they want by saying `option: [set: ..., add: ..., rm: ...]`.
//
// Most operate with the same shape of value in all three modes, but
// set_tag_attribute_values is different.

#[derive(Debug, Default, NifMap)]
pub struct ExSanitizeCustomSetAddRm<TSet, TAdd = TSet, TRm = TSet> {
    set: Option<TSet>,
    add: Option<TAdd>,
    rm: Option<TRm>,
}

// How such options actually function depends on the shape of value they
// actually manipulate. We write an "apply" implementation for each type used.
//
// The higher-ranked bounds used in the function pointer types make it possible
// for us to pass the builder reference into each of them without the borrow
// lasting as long as a lifetime parameter on the apply function itself (and
// therefore overlapping).

impl ExSanitizeCustomSetAddRm<Vec<String>> {
    fn apply<'a>(
        &'a self,
        builder: &mut Builder<'a>,
        set_fn: for<'r> fn(&'r mut Builder<'a>, HashSet<&'a str>) -> &'r mut Builder<'a>,
        add_fn: for<'r> fn(&'r mut Builder<'a>, HashSet<&'a str>) -> &'r mut Builder<'a>,
        rm_fn: for<'r> fn(&'r mut Builder<'a>, HashSet<&'a str>) -> &'r mut Builder<'a>,
    ) {
        if let Some(set) = &self.set {
            set_fn(builder, borrowed_set(set));
        }
        if let Some(add) = &self.add {
            add_fn(builder, borrowed_set(add));
        }
        if let Some(rm) = &self.rm {
            rm_fn(builder, borrowed_set(rm));
        }
    }
}
impl ExSanitizeCustomSetAddRm<HashMap<String, Vec<String>>> {
    fn apply<'a>(
        &'a self,
        builder: &mut Builder<'a>,
        set_fn: for<'r> fn(
            &'r mut Builder<'a>,
            HashMap<&'a str, HashSet<&'a str>>,
        ) -> &'r mut Builder<'a>,
        add_fn: for<'r> fn(&'r mut Builder<'a>, &'a str, HashSet<&'a str>) -> &'r mut Builder<'a>,
        rm_fn: for<'r> fn(&'r mut Builder<'a>, &'a str, HashSet<&'a str>) -> &'r mut Builder<'a>,
    ) {
        if let Some(set) = &self.set {
            set_fn(builder, borrowed_map_set(set));
        }
        if let Some(add) = &self.add {
            for (tag, attrs) in add {
                add_fn(builder, tag, borrowed_set(attrs));
            }
        }
        if let Some(rm) = &self.rm {
            for (tag, attrs) in rm {
                rm_fn(builder, tag, borrowed_set(attrs));
            }
        }
    }
}

impl
    ExSanitizeCustomSetAddRm<
        HashMap<String, HashMap<String, String>>,
        HashMap<String, HashMap<String, String>>,
        HashMap<String, String>,
    >
{
    fn apply<'a>(
        &'a self,
        builder: &mut Builder<'a>,
        set_fn: for<'r> fn(
            &'r mut Builder<'a>,
            HashMap<&'a str, HashMap<&'a str, &'a str>>,
        ) -> &'r mut Builder<'a>,
        add_fn: for<'r> fn(&'r mut Builder<'a>, &'a str, &'a str, &'a str) -> &'r mut Builder<'a>,
        rm_fn: for<'r> fn(&'r mut Builder<'a>, &'a str, &'a str) -> &'r mut Builder<'a>,
    ) {
        if let Some(set) = &self.set {
            set_fn(builder, borrowed_map_map(set));
        }
        if let Some(add) = &self.add {
            for (tag, attrs) in add {
                for (attr, value) in attrs {
                    add_fn(builder, tag, attr, value);
                }
            }
        }
        if let Some(rm) = &self.rm {
            for (tag, attr) in rm {
                rm_fn(builder, tag, attr);
            }
        }
    }
}

impl ExSanitizeCustomSetAddRm<HashMap<String, HashMap<String, Vec<String>>>> {
    fn apply<'a>(
        &'a self,
        builder: &mut Builder<'a>,
        set_fn: for<'r> fn(
            &'r mut Builder<'a>,
            HashMap<&'a str, HashMap<&'a str, HashSet<&'a str>>>,
        ) -> &'r mut Builder<'a>,
        add_fn: for<'r> fn(
            &'r mut Builder<'a>,
            &'a str,
            &'a str,
            HashSet<&'a str>,
        ) -> &'r mut Builder<'a>,
        rm_fn: for<'r> fn(
            &'r mut Builder<'a>,
            &'a str,
            &'a str,
            HashSet<&'a str>,
        ) -> &'r mut Builder<'a>,
    ) {
        if let Some(set) = &self.set {
            set_fn(builder, borrowed_map_map_set(set));
        }
        if let Some(add) = &self.add {
            for (tag, attrs) in add {
                for (attr, values) in attrs {
                    add_fn(builder, tag, attr, borrowed_set(values));
                }
            }
        }
        if let Some(rm) = &self.rm {
            for (tag, attrs) in rm {
                for (attr, values) in attrs {
                    rm_fn(builder, tag, attr, borrowed_set(values));
                }
            }
        }
    }
}

#[derive(Debug, NifTaggedEnum)]
pub enum ExSanitizeCustomUrlRelative {
    Deny,
    Passthrough,
    RewriteWithBase(String),
    RewriteWithRoot((String, String)),
    // Custom is also available in ammonia.
}

impl ExSanitizeCustomUrlRelative {
    fn to_ammonia(&self) -> UrlRelative<'_> {
        match self {
            &ExSanitizeCustomUrlRelative::Deny => UrlRelative::Deny,
            &ExSanitizeCustomUrlRelative::Passthrough => UrlRelative::PassThrough,
            ExSanitizeCustomUrlRelative::RewriteWithBase(base) => match Url::parse(base) {
                Ok(url) => UrlRelative::RewriteWithBase(url),
                Err(_) => UrlRelative::Deny,
            },
            ExSanitizeCustomUrlRelative::RewriteWithRoot((root, path)) => match Url::parse(root) {
                Ok(url) => UrlRelative::RewriteWithRoot {
                    root: url,
                    path: path.to_string(),
                },
                Err(_) => UrlRelative::Deny,
            },
        }
    }
}

#[derive(Debug, Default, NifMap)]
pub struct ExSanitizeCustom {
    pub tags: ExSanitizeCustomSetAddRm<Vec<String>>,
    pub clean_content_tags: ExSanitizeCustomSetAddRm<Vec<String>>,
    pub tag_attributes: ExSanitizeCustomSetAddRm<HashMap<String, Vec<String>>>,
    pub tag_attribute_values:
        ExSanitizeCustomSetAddRm<HashMap<String, HashMap<String, Vec<String>>>>,
    pub generic_attribute_prefixes: ExSanitizeCustomSetAddRm<Vec<String>>,
    pub generic_attributes: ExSanitizeCustomSetAddRm<Vec<String>>,
    pub url_schemes: ExSanitizeCustomSetAddRm<Vec<String>>,
    pub allowed_classes: ExSanitizeCustomSetAddRm<HashMap<String, Vec<String>>>,
    pub set_tag_attribute_values: ExSanitizeCustomSetAddRm<
        HashMap<String, HashMap<String, String>>,
        HashMap<String, HashMap<String, String>>,
        HashMap<String, String>,
    >,
    pub strip_comments: Option<bool>,
    pub link_rel: Option<String>,
    pub id_prefix: Option<String>,
    pub url_relative: Option<ExSanitizeCustomUrlRelative>,
    // attribute_filter is also available in ammonia.
}

impl ExSanitizeCustom {
    pub fn to_ammonia(&self) -> Builder<'_> {
        let mut builder = ammonia::Builder::default();

        self.tags.apply(
            &mut builder,
            Builder::tags,
            Builder::add_tags,
            Builder::rm_tags,
        );
        self.clean_content_tags.apply(
            &mut builder,
            Builder::clean_content_tags,
            Builder::add_clean_content_tags,
            Builder::rm_clean_content_tags,
        );
        self.tag_attributes.apply(
            &mut builder,
            Builder::tag_attributes,
            Builder::add_tag_attributes,
            Builder::rm_tag_attributes,
        );
        self.tag_attribute_values.apply(
            &mut builder,
            Builder::tag_attribute_values,
            Builder::add_tag_attribute_values,
            Builder::rm_tag_attribute_values,
        );
        self.generic_attribute_prefixes.apply(
            &mut builder,
            Builder::generic_attribute_prefixes,
            Builder::add_generic_attribute_prefixes,
            Builder::rm_generic_attribute_prefixes,
        );
        self.generic_attributes.apply(
            &mut builder,
            Builder::generic_attributes,
            Builder::add_generic_attributes,
            Builder::rm_generic_attributes,
        );
        self.url_schemes.apply(
            &mut builder,
            Builder::url_schemes,
            Builder::add_url_schemes,
            Builder::rm_url_schemes,
        );
        self.allowed_classes.apply(
            &mut builder,
            Builder::allowed_classes,
            Builder::add_allowed_classes,
            Builder::rm_allowed_classes,
        );
        self.set_tag_attribute_values.apply(
            &mut builder,
            Builder::set_tag_attribute_values,
            Builder::set_tag_attribute_value,
            Builder::rm_set_tag_attribute_value,
        );
        if let Some(strip_comments) = self.strip_comments {
            builder.strip_comments(strip_comments);
        }
        builder.link_rel(self.link_rel.as_ref().map(|s| s.borrow()));
        builder.id_prefix(self.id_prefix.as_ref().map(|s| s.borrow()));
        if let Some(url_relative) = &self.url_relative {
            builder.url_relative(url_relative.to_ammonia());
        }

        builder
    }
}
