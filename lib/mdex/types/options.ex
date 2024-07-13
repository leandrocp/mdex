defmodule MDEx.Types.ExtensionOptions do
  @moduledoc false
  defstruct strikethrough: false,
            tagfilter: false,
            table: false,
            autolink: false,
            tasklist: false,
            superscript: false,
            header_ids: nil,
            footnotes: false,
            description_lists: false,
            front_matter_delimiter: nil,
            multiline_block_quotes: false,
            math_dollars: false,
            math_code: false,
            shortcodes: false,
            wikilinks_title_after_pipe: false,
            wikilinks_title_before_pipe: false,
            underline: false,
            spoiler: false,
            greentext: false
end

defmodule MDEx.Types.ParseOptions do
  @moduledoc false
  defstruct smart: false,
            default_info_string: nil,
            relaxed_tasklist_matching: false,
            relaxed_autolinks: true
end

defmodule MDEx.Types.RenderOptions do
  @moduledoc false
  defstruct hardbreaks: false,
            github_pre_lang: false,
            full_info_string: false,
            width: 0,
            unsafe_: false,
            escape: false,
            list_style: :dash,
            sourcepos: false,
            experimental_inline_sourcepos: false,
            escaped_char_spans: false,
            ignore_setext: false,
            ignore_empty_links: false,
            gfm_quirks: false,
            prefer_fenced: false
end

defmodule MDEx.Types.FeaturesOptions do
  @moduledoc false
  defstruct sanitize: false,
            syntax_highlight_theme: "onedark",
            syntax_highlight_inline_style: true
end

defmodule MDEx.Types.Options do
  @moduledoc false
  defstruct extension: %MDEx.Types.ExtensionOptions{},
            parse: %MDEx.Types.ParseOptions{},
            render: %MDEx.Types.RenderOptions{},
            features: %MDEx.Types.FeaturesOptions{}
end
