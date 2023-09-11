Mix.install([:req, :benchee, :earmark, :md, :mdex])

defmodule Benchmark do
  @markdown Req.get!("https://raw.githubusercontent.com/BeaconCMS/live_monaco_editor/main/README.md").body

  def run do
    Benchee.run(%{
      "earmark" => fn -> Earmark.as_html(@markdown) end,
      "md" => fn -> Md.generate(@markdown) end,
      "mdex" => fn -> MDEx.to_html(@markdown) end
    })
  end
end

Benchmark.run()
