Mix.install([:req, :benchee, :earmark, :md, :mdex])

defmodule Benchmark do
  @markdown Req.get!("https://raw.githubusercontent.com/leandrocp/mdex/main/README.md").body

  def run do
    Benchee.run(
      %{
        "earmark" => fn -> Earmark.as_html(@markdown) end,
        "md" => fn -> Md.generate(@markdown) end,
        "mdex" => fn -> MDEx.to_html(@markdown, syntax_highlight: nil) end
      },
      memory_time: 2,
      reduction_time: 2,
      formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
    )
  end
end

Benchmark.run()
