deps = [
  {:req, "~> 0.6"},
  {:benchee, "~> 1.5"},
  {:earmark, "~> 1.4"},
  {:md, "~> 0.12"},
  {:cmark, "~> 0.10"},
  {:mdex, "~> 0.13"},
  {:mdex_native, "~> 0.2"},
  {:markdown, github: "WhatsApp/erlang-markdown", subdir: "apps/markdown", manager: :rebar3}
]

Mix.install(deps)

defmodule Benchmark do
  @markdown Req.get!("https://raw.githubusercontent.com/leandrocp/mdex/main/README.md").body

  def run do
    benchmarks = %{
      "earmark" => fn -> Earmark.as_html(@markdown) end,
      "md" => fn -> Md.generate(@markdown) end,
      "cmark" => fn -> Cmark.to_html(@markdown) end,
      "mdex" => fn -> MDEx.to_html(@markdown, syntax_highlight: nil) end,
      "mdex_native" => fn -> MDExNative.Comrak.markdown_to_html(@markdown) end,
      "erlang-markdown" => fn -> :markdown.to_html(@markdown) end
    }

    Benchee.run(
      benchmarks,
      memory_time: 2,
      reduction_time: 2,
      formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
    )
  end
end

Benchmark.run()
