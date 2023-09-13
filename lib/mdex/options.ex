defmodule MDEx.ExtensionOptions do
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
            front_matter_delimiter: nil
end

defmodule MDEx.ParseOptions do
  @moduledoc false
  defstruct smart: false,
            default_info_string: nil,
            relaxed_tasklist_matching: false
end

defmodule MDEx.RenderOptions do
  @moduledoc false
  defstruct hardbreaks: false,
            github_pre_lang: false,
            full_info_string: false,
            width: 0,
            unsafe_: false,
            escape: false,
            list_style: :dash,
            sourcepos: false
end

defmodule MDEx.FeaturesOptions do
  @moduledoc false
  defstruct sanitize: false,
            syntax_highlight_theme: "Dracula"
end

defmodule MDEx.Options do
  @moduledoc false
  defstruct extension: %MDEx.ExtensionOptions{},
            parse: %MDEx.ParseOptions{},
            render: %MDEx.RenderOptions{},
            features: %MDEx.FeaturesOptions{}
end
