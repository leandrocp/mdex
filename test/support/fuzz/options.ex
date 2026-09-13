defmodule MDEx.Fuzz.Options do
  @moduledoc """
  Generators for every MDEx option group.

  The option name lists are the source of truth for the coverage assertions in
  the fuzz suite: `MDEx.OptionsFuzzTest` and `MDEx.FeaturesFuzzTest` compare them
  against `MDEx.Document` defaults, so an option added upstream fails the suite
  until it is generated here.
  """

  use ExUnitProperties

  import MDEx.Fuzz, only: [option_string: 0]

  @extension_option_kinds %{
    alerts: :boolean,
    autolink: :boolean,
    block_directive: :boolean,
    cjk_friendly_emphasis: :boolean,
    description_lists: :boolean,
    fenced_code_attributes: :boolean,
    footnotes: :boolean,
    front_matter_delimiter: :front_matter_delimiter,
    greentext: :boolean,
    header_attributes: :boolean,
    header_id_prefix: :optional_string,
    header_id_prefix_in_href: :boolean,
    header_ids: :deprecated_header_ids,
    highlight: :boolean,
    image_url_rewriter: :url_rewriter,
    inline_code_attributes: :boolean,
    inline_footnotes: :boolean,
    insert: :boolean,
    link_attributes: :boolean,
    link_url_rewriter: :url_rewriter,
    math_code: :boolean,
    math_dollars: :boolean,
    math_latex: :boolean,
    multiline_block_quotes: :boolean,
    phoenix_heex: :boolean,
    shortcodes: :boolean,
    spoiler: :boolean,
    strikethrough: :boolean,
    subscript: :boolean,
    subtext: :boolean,
    superscript: :boolean,
    table: :boolean,
    tagfilter: :boolean,
    tasklist: :boolean,
    underline: :boolean,
    wikilinks_title_after_pipe: :boolean,
    wikilinks_title_before_pipe: :boolean
  }

  @parse_option_kinds %{
    default_info_string: :optional_string,
    escaped_char_spans: :upstream_escaped_char_spans,
    ignore_setext: :boolean,
    leave_footnote_definitions: :boolean,
    relaxed_autolinks: :boolean,
    relaxed_tasklist_matching: :boolean,
    smart: :boolean,
    sourcepos_chars: :boolean,
    tasklist_in_table: :boolean
  }

  @render_option_kinds %{
    alert_style: {:member_of, [:specific, :semantic]},
    compact_html: :boolean,
    escape: :boolean,
    escaped_char_spans: :upstream_escaped_char_spans,
    experimental_minimize_commonmark: :boolean,
    figure_with_caption: :boolean,
    full_info_string: :boolean,
    gfm_quirks: :boolean,
    github_pre_lang: :boolean,
    hardbreaks: :boolean,
    ignore_empty_links: :boolean,
    list_style: {:member_of, [:dash, :plus, :star]},
    ol_width: :non_negative_integer,
    prefer_fenced: :boolean,
    sourcepos: :boolean,
    tasklist_classes: :boolean,
    unsafe: :boolean,
    width: :non_negative_integer
  }

  @sanitize_option_kinds %{
    add_allowed_classes: :allowed_classes,
    add_clean_content_tags: :clean_content_tags,
    add_generic_attribute_prefixes: :attribute_prefixes,
    add_generic_attributes: :attributes,
    add_tag_attribute_values: :tag_attribute_value_lists,
    add_tag_attributes: :tag_attributes,
    add_tags: :tags,
    add_url_schemes: :url_schemes,
    allowed_classes: :allowed_classes,
    clean_content_tags: :clean_content_tags,
    generic_attribute_prefixes: :attribute_prefixes,
    generic_attributes: :attributes,
    id_prefix: :optional_string,
    link_rel: :optional_string,
    rm_allowed_classes: :allowed_classes,
    rm_clean_content_tags: :clean_content_tags,
    rm_generic_attribute_prefixes: :attribute_prefixes,
    rm_generic_attributes: :attributes,
    rm_set_tag_attribute_value: :tag_values,
    rm_tag_attribute_values: :tag_attribute_value_lists,
    rm_tag_attributes: :tag_attributes,
    rm_tags: :tags,
    rm_url_schemes: :url_schemes,
    set_tag_attribute_value: :tag_attribute_values,
    set_tag_attribute_values: :tag_attribute_values,
    strip_comments: :boolean,
    tag_attribute_values: :tag_attribute_value_lists,
    tag_attributes: :tag_attributes,
    tags: :tags,
    url_relative: :url_relative,
    url_schemes: :url_schemes
  }

  @sanitize_tags ~w(a code custom-element div h1 img p span)
  @clean_content_tags ~w(script style)
  @sanitize_attributes ~w(data-kind href id src title)
  @sanitize_generic_attributes ~w(data-kind id title)
  @sanitize_values ~w(allowed blocked first second)
  @sanitize_schemes ~w(data http https javascript mailto)
  @attribute_prefixes ["aria-", "data-", "phx-"]

  @doc "Option names generated for each `MDEx.Document` option group."
  def extension_option_names, do: Map.keys(@extension_option_kinds)
  def parse_option_names, do: Map.keys(@parse_option_kinds)
  def render_option_names, do: Map.keys(@render_option_kinds)
  def sanitize_option_names, do: Map.keys(@sanitize_option_kinds)

  @doc """
  A full `[extension: ..., parse: ..., render: ...]` option list.
  """
  def options do
    fixed_map(%{
      extension: option_group(@extension_option_kinds),
      parse: option_group(@parse_option_kinds),
      render: option_group(@render_option_kinds)
    })
    |> map(&Map.to_list/1)
  end

  @doc """
  A full `:sanitize` option list covering every sanitizer setting.
  """
  def sanitize_options do
    @sanitize_option_kinds
    |> Map.new(fn {name, kind} -> {name, sanitize_value(kind)} end)
    |> fixed_map()
    |> map(&Map.to_list/1)
  end

  @doc """
  Every supported `:syntax_highlight` setting, including the disabled forms.
  """
  def syntax_highlight_options do
    member_of([
      nil,
      false,
      [formatter: :html_linked],
      [formatter: {:html_inline, theme: "onedark"}],
      [engine: :lumis, opts: [formatter: :html_linked]]
    ])
  end

  defp option_group(kinds) do
    kinds
    |> Map.new(fn {name, kind} -> {name, option_value(kind)} end)
    |> fixed_map()
    |> map(&Map.to_list/1)
  end

  defp option_value(:boolean), do: boolean()

  # mdex_native currently exposes Escaped children through an undeclared
  # dynamic :nodes field, so any Document round trip loses those children.
  # Restore boolean generation when https://github.com/leandrocp/mdex_native/issues/69 is released.
  defp option_value(:upstream_escaped_char_spans), do: constant(false)

  defp option_value(:deprecated_header_ids), do: constant(nil)
  defp option_value(:optional_string), do: one_of([constant(nil), option_string()])
  defp option_value(:front_matter_delimiter), do: member_of([nil, "---", "+++", ";;;"])

  defp option_value(:url_rewriter) do
    member_of([nil, "https://proxy.test/?url={@url}", "/proxy/{@url}"])
  end

  defp option_value(:non_negative_integer) do
    frequency([{8, integer(0..100)}, {1, member_of([255, 1_024])}])
  end

  defp option_value({:member_of, values}), do: member_of(values)

  defp sanitize_value(:tags), do: list_of(member_of(@sanitize_tags), max_length: 5)

  defp sanitize_value(:clean_content_tags) do
    list_of(member_of(@clean_content_tags), max_length: 2)
  end

  defp sanitize_value(:attributes), do: list_of(member_of(@sanitize_generic_attributes), max_length: 3)
  defp sanitize_value(:attribute_prefixes), do: list_of(member_of(@attribute_prefixes), max_length: 3)
  defp sanitize_value(:url_schemes), do: list_of(member_of(@sanitize_schemes), max_length: 4)
  defp sanitize_value(:optional_string), do: one_of([constant(nil), option_string()])
  defp sanitize_value(:boolean), do: boolean()

  defp sanitize_value(:tag_attributes) do
    pair_map(
      member_of(@sanitize_tags),
      list_of(member_of(@sanitize_attributes), max_length: 4),
      4
    )
  end

  defp sanitize_value(:allowed_classes) do
    pair_map(
      member_of(@sanitize_tags),
      list_of(member_of(@sanitize_values), max_length: 4),
      4
    )
  end

  defp sanitize_value(:tag_attribute_value_lists) do
    pair_map(
      member_of(@sanitize_tags),
      pair_map(
        member_of(@sanitize_attributes),
        list_of(member_of(@sanitize_values), max_length: 4),
        3
      ),
      3
    )
  end

  defp sanitize_value(:tag_attribute_values) do
    pair_map(
      member_of(@sanitize_tags),
      pair_map(member_of(@sanitize_attributes), member_of(@sanitize_values), 3),
      3
    )
  end

  defp sanitize_value(:tag_values) do
    pair_map(member_of(@sanitize_tags), member_of(@sanitize_attributes), 4)
  end

  defp sanitize_value(:url_relative) do
    member_of([
      :deny,
      :passthrough,
      {:rewrite_with_base, "https://example.com/base/"},
      {:rewrite_with_root, {"https://example.com/root/", "index.html"}}
    ])
  end

  defp pair_map(key_generator, value_generator, max_length) do
    tuple({key_generator, value_generator})
    |> list_of(max_length: max_length)
    |> map(&Map.new/1)
  end
end
