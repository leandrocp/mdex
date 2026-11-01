# MDEx benchmark.
#
#     elixir benchmarks/benchmark.exs
#
# Benchmarks the MDEx checkout this file lives in (a path dependency) against
# mdex_native, the Rust engine underneath it, and other Elixir/Erlang Markdown
# libraries. Inputs are vendored in benchmarks/inputs, so nothing is fetched at
# run time apart from the dependencies.
#
# Environment variables:
#
#   BENCH_OUTPUT  JSON results path. Defaults to benchmarks/results.json.
#   BENCH_INPUTS  Comma-separated inputs to run, e.g. "small,medium". Defaults to all.
#   BENCH_ROWS    Comma-separated substrings; only rows whose name contains one run.
#   BENCH_QUICK   "1" for short runs while iterating. Don't publish quick numbers.
#   BENCH_PROFILE Profiler for Benchee's profile_after, e.g. "tprof" or "eprof".

repo_root = Path.expand("..", __DIR__)

Mix.install(
  [
    {:mdex, path: repo_root},
    {:lumis_wasm_elixir, "~> 0.26"},
    {:benchee, "~> 1.5"},
    {:earmark, "~> 1.4"},
    {:md, "~> 0.10"},
    {:cmark, "~> 0.10"},
    {:markdown, github: "WhatsApp/erlang-markdown", subdir: "apps/markdown", manager: :rebar3}
  ],
  # Syntax highlighting needs the Lumis build of the NIF, as in MDEx's own config.
  config: [mdex_native: [syntax_highlighter: :lumis]]
)

defmodule Bench do
  @inputs_dir Path.join(__DIR__, "inputs")
  @inputs [
    {"small", "small.md", "Handwritten release note: headings, list, task item, link, autolink, code block, table, quote"},
    {"medium", "medium.md", "MDEx README.md snapshot (commit fad697a)"},
    {"large", "large.md", "CommonMark Spec 0.31.2 (spec.txt), CC BY-SA 4.0, John MacFarlane"}
  ]

  # Rows that can't run on an input, with the reason recorded in the results.
  @skip %{
    "large" => %{
      "erlang-markdown" => "One call took 100 s on this input (measured once with :timer.tc), too slow to benchmark"
    }
  }

  # Chunk size for MDEx.stream/2, roughly what an LLM response or a socket delivers.
  @stream_chunk_size 128

  def run do
    quick? = System.get_env("BENCH_QUICK") == "1"
    selected_inputs = env_list("BENCH_INPUTS")
    row_filter = env_list("BENCH_ROWS")
    output = System.get_env("BENCH_OUTPUT") || Path.join(__DIR__, "results.json")

    inputs =
      for {name, file, description} <- @inputs, selected_inputs == [] or name in selected_inputs do
        markdown = File.read!(Path.join(@inputs_dir, file))
        %{name: name, file: file, description: description, bytes: byte_size(markdown), markdown: markdown}
      end

    environment = environment()
    print_environment(environment)

    config =
      if quick? do
        [warmup: 0.5, time: 1, memory_time: 0.2, reduction_time: 0.2]
      else
        [warmup: 2, time: 5, memory_time: 1, reduction_time: 1]
      end

    results =
      for input <- inputs do
        skipped = Map.get(@skip, input.name, %{})
        jobs = input |> jobs() |> Map.drop(Map.keys(skipped)) |> filter_rows(row_filter)
        check_outputs!(input)

        IO.puts("\n## #{input.name} (#{input.file}, #{input.bytes} bytes)\n")

        suite =
          Benchee.run(
            jobs,
            config ++
              [
                title: "#{input.name} (#{input.bytes} bytes)",
                formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
              ] ++ profile()
          )

        %{
          input: Map.delete(input, :markdown),
          rows: Enum.map(suite.scenarios, &scenario_json/1),
          skipped: skipped
        }
      end

    sigil = sigil_compile_time(inputs)

    json = %{
      environment: environment,
      benchee_config: Map.new(config),
      stream_chunk_size: @stream_chunk_size,
      results: results,
      sigil_compile: sigil
    }

    File.write!(output, Jason.encode_to_iodata!(json, pretty: true))
    IO.puts("\nWrote #{output}")
  end

  # Options shared by both sides of each MDEx vs mdex_native pair: MDEx's
  # defaults converted with the same function MDEx uses before calling the NIF.
  defp native_options(opts), do: MDEx.Document.rust_options!(MDEx.new(opts).options)

  @highlight [syntax_highlight: [engine: :lumis]]
  @sanitize [sanitize: MDEx.Document.default_sanitize_options()]

  defp jobs(%{markdown: md}) do
    plain = native_options([])
    highlight = native_options(@highlight)
    sanitize = native_options(@sanitize)

    {:ok, mdex_doc} = MDEx.parse_document(md)
    {:ok, native_doc} = MDExNative.Comrak.parse_document(md, plain)

    chunks = chunk(md, @stream_chunk_size)

    [
      # Raw engine with Comrak's defaults, the call people compare against.
      {"mdex_native markdown_to_html (comrak defaults)", fn -> MDExNative.Comrak.markdown_to_html(md) end},

      # Same options on both sides.
      {"mdex_native markdown_to_html", fn -> MDExNative.Comrak.markdown_to_html(md, plain) end},
      {"MDEx.to_html", fn -> MDEx.to_html(md) end},
      {"mdex_native markdown_to_html + highlight", fn -> MDExNative.Comrak.markdown_to_html(md, highlight) end},
      {"MDEx.to_html + highlight", fn -> MDEx.to_html(md, @highlight) end},
      {"mdex_native markdown_to_html + sanitize", fn -> MDExNative.Comrak.markdown_to_html(md, sanitize) end},
      {"MDEx.to_html + sanitize", fn -> MDEx.to_html(md, @sanitize) end},
      {"mdex_native parse_document", fn -> MDExNative.Comrak.parse_document(md, plain) end},
      {"MDEx.parse_document", fn -> MDEx.parse_document(md) end},
      {"mdex_native document_to_html", fn -> MDExNative.Comrak.document_to_html(native_doc, plain) end},
      {"MDEx.to_html(document)", fn -> MDEx.to_html(mdex_doc) end},

      # MDEx-only features.
      {"MDEx.stream + to_html each", fn -> chunks |> MDEx.stream() |> Stream.map(fn {id, doc} -> {id, MDEx.to_html!(doc)} end) |> Stream.run() end},
      {"~MD sigil expansion (HTML)", fn -> expand_sigil(md) end},

      # Other libraries.
      {"earmark", fn -> Earmark.as_html(md) end},
      {"md", fn -> Md.generate(md) end},
      {"cmark", fn -> Cmark.to_html(md) end},
      {"erlang-markdown", fn -> :markdown.to_html(md) end}
    ]
    |> Map.new()
  end

  defp filter_rows(jobs, []), do: jobs

  defp filter_rows(jobs, filters) do
    Map.filter(jobs, fn {name, _} -> Enum.any?(filters, &String.contains?(name, &1)) end)
  end

  # Fails fast when a pair doesn't produce the same output, so the comparison
  # stays apples to apples. MDEx trims the trailing newline Comrak emits.
  defp check_outputs!(%{markdown: md, name: name}) do
    pairs = [
      {MDEx.to_html!(md), MDExNative.Comrak.markdown_to_html!(md, native_options([]))},
      {MDEx.to_html!(md, @highlight), MDExNative.Comrak.markdown_to_html!(md, native_options(@highlight))},
      {MDEx.to_html!(md, @sanitize), MDExNative.Comrak.markdown_to_html!(md, native_options(@sanitize))}
    ]

    for {{mdex, native}, index} <- Enum.with_index(pairs) do
      if mdex != String.trim_trailing(native) do
        raise "#{name}: MDEx and mdex_native outputs differ for pair #{index}"
      end
    end

    :ok
  end

  defp chunk(binary, size) do
    case binary do
      <<chunk::binary-size(^size), rest::binary>> -> [chunk | chunk(rest, size)]
      rest -> [rest]
    end
  end

  # What `~MD"..."HTML` does at compile time, without the Elixir compiler
  # around it. `module: nil` is a caller outside a module (no `use MDEx` options).
  import MDEx.Sigil, warn: false

  defp expand_sigil(markdown) do
    env = %{__ENV__ | module: nil, function: nil}
    Macro.expand_once({:sigil_MD, [], [{:<<>>, [], [markdown]}, ~c"HTML"]}, env)
  end

  # Compiling a module that holds `~MD"..."HTML`, which includes the Elixir
  # compiler's own work. Measured with :timer.tc, median of 5 runs.
  defp sigil_compile_time(inputs) do
    for %{name: name, markdown: md} <- inputs do
      times =
        for i <- 1..5 do
          module = Module.concat(BenchSigil, "#{name}#{i}")

          quoted =
            quote do
              defmodule unquote(module) do
                import MDEx.Sigil
                def html, do: unquote({:sigil_MD, [], [{:<<>>, [], [md]}, ~c"HTML"]})
              end
            end

          {us, _} = :timer.tc(fn -> Code.compile_quoted(quoted) end)
          :code.purge(module)
          :code.delete(module)
          us
        end

      median = times |> Enum.sort() |> Enum.at(2)
      IO.puts("~MD compile (#{name}): median #{median} µs over 5 runs")
      %{input: name, median_us: median, runs_us: times}
    end
  end

  defp scenario_json(scenario) do
    run = scenario.run_time_data.statistics
    memory = scenario.memory_usage_data.statistics
    reductions = scenario.reductions_data.statistics

    %{
      name: scenario.name,
      ips: run.ips,
      average_ns: run.average,
      median_ns: run.median,
      p99_ns: run.percentiles[99],
      deviation_pct: run.std_dev_ratio * 100,
      sample_size: run.sample_size,
      memory_bytes: memory.median,
      reductions: reductions.median
    }
  end

  defp profile do
    case System.get_env("BENCH_PROFILE") do
      nil -> []
      profiler -> [profile_after: String.to_atom(profiler)]
    end
  end

  defp environment do
    {date, 0} = System.cmd("date", ["+%Y-%m-%d %H:%M %Z"], env: [{"TZ", "America/Toronto"}])
    {commit, _} = System.cmd("git", ["-C", Path.expand("..", __DIR__), "rev-parse", "HEAD"])
    {dirty, _} = System.cmd("git", ["-C", Path.expand("..", __DIR__), "status", "--porcelain", "lib"])
    {uname, _} = System.cmd("uname", ["-srm"])

    cpu =
      case File.read("/proc/cpuinfo") do
        {:ok, info} -> info |> String.split("\n") |> Enum.find_value(&cpu_model/1)
        _ -> nil
      end

    memory_gb =
      case File.read("/proc/meminfo") do
        {:ok, "MemTotal:" <> rest} -> rest |> String.split() |> hd() |> String.to_integer() |> div(1024 * 1024)
        _ -> nil
      end

    versions =
      Map.new([:mdex, :mdex_native, :lumis_wasm_elixir, :benchee, :earmark, :md, :cmark, :markdown], fn app ->
        {app, app |> Application.spec(:vsn) |> to_string()}
      end)

    %{
      date: String.trim(date),
      mdex_commit: String.trim(commit),
      mdex_lib_dirty: dirty != "",
      elixir: System.version(),
      otp: System.otp_release(),
      erts: to_string(:erlang.system_info(:version)),
      jit: :erlang.system_info(:emu_flavor) == :jit,
      os: String.trim(uname),
      cpu: cpu,
      logical_cpus: :erlang.system_info(:logical_processors),
      memory_gb: memory_gb,
      versions: versions
    }
  end

  defp cpu_model("model name" <> rest), do: rest |> String.split(":", parts: 2) |> List.last() |> String.trim()
  defp cpu_model(_), do: nil

  defp print_environment(env) do
    IO.puts("# MDEx benchmark — #{env.date}")
    IO.puts("mdex commit #{env.mdex_commit}#{if env.mdex_lib_dirty, do: " (lib/ has uncommitted changes)"}")
    IO.puts("Elixir #{env.elixir}, OTP #{env.otp} (erts #{env.erts}, jit: #{env.jit})")
    IO.puts("#{env.os}, #{env.cpu}, #{env.logical_cpus} logical CPUs, #{env.memory_gb} GB")
    IO.puts(env.versions |> Enum.map(fn {k, v} -> "#{k} #{v}" end) |> Enum.join(", "))
  end

  defp env_list(var) do
    case System.get_env(var) do
      nil -> []
      value -> value |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
    end
  end
end

Bench.run()
