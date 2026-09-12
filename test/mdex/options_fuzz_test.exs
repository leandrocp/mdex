defmodule MDEx.OptionsFuzzTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MDEx.Document

  @max_runs if System.get_env("CI"), do: 500, else: 100

  @feature_rich_markdown """
  ---
  title: Fuzz
  ---

  # Heading {#custom .wide}

  [link](https://example.com) and ![image](https://example.com/image.png)

  ~~strike~~ ~subscript~ ^superscript^ ==highlight== ++insert++ ||spoiler||

  - [x] task

  | column | value |
  | :----- | ----: |
  | row    | data  |

  [^note]: footnote

  Term
  : Description

  > [!NOTE]
  > alert

  ::: details
  block directive
  :::

  ```elixir {.example key=value}
  IO.puts("hello")
  ```
  """

  property "Comrak-backed option combinations survive every MDEx parser and renderer" do
    check all(
            markdown <- markdown(),
            options <- options(),
            max_runs: @max_runs,
            max_generation_size: 30
          ) do
      document = MDEx.parse_document!(markdown, options)

      assert %Document{} = document
      assert is_binary(MDEx.to_html!(markdown, options))
      assert is_binary(MDEx.to_html!(document, options))
      assert is_binary(MDEx.to_xml!(markdown, options))
      assert is_binary(MDEx.to_xml!(document, options))

      rendered_markdown = MDEx.to_markdown!(document, options)
      assert %Document{} = MDEx.parse_document!(rendered_markdown, options)
    end
  end

  defp markdown do
    gen all(
          suffix <- string(:utf8, max_length: 128),
          shape <- member_of([:plain, :heading, :feature_rich])
        ) do
      case shape do
        :plain -> suffix
        :heading -> "# " <> suffix
        :feature_rich -> @feature_rich_markdown <> "\n" <> suffix
      end
    end
  end

  defp options do
    fixed_map(%{
      extension: extension_options(),
      parse: parse_options(),
      render: render_options()
    })
    |> map(&Map.to_list/1)
  end

  defp extension_options do
    optional_keyword(Document.default_extension_options())
  end

  defp parse_options do
    optional_keyword(Document.default_parse_options())
  end

  defp render_options do
    optional_keyword(Document.default_render_options())
  end

  defp option_value(:header_ids, nil), do: constant(nil)
  defp option_value(:list_style, :dash), do: member_of([:dash, :plus, :star])
  defp option_value(:alert_style, :specific), do: member_of([:specific, :semantic])
  defp option_value(_key, default) when is_boolean(default), do: boolean()
  defp option_value(_key, default) when is_integer(default) and default >= 0, do: integer(0..100)
  defp option_value(_key, nil), do: one_of([constant(nil), string(:utf8, max_length: 24)])

  defp optional_keyword(defaults) do
    defaults
    |> Map.new(fn {key, default} -> {key, option_value(key, default)} end)
    |> optional_map()
    |> map(&Map.to_list/1)
  end
end
