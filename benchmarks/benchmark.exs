# Markdown benchmark: MDEx, mdex_native, and every other Elixir/Erlang
# Markdown library, over the vendored inputs in benchmarks/inputs.
#
#     elixir benchmarks/benchmark.exs
#
# Each library is installed and benchmarked in its own `elixir` process, so a
# library that doesn't compile, raises, or hangs is recorded with its status
# instead of stopping the run. Writes benchmarks/results.json and
# benchmarks/RESULTS.md.
#
# Environment variables:
#
#   BENCH_LIBRARIES  Comma-separated libraries to run. Defaults to all.
#   BENCH_INPUTS     Comma-separated inputs to run, e.g. "small,medium". Defaults to all.
#   BENCH_QUICK      "1" for short runs while iterating. Don't publish quick numbers.
#   BENCH_TIMEOUT    Seconds one call may take before the row is marked as a timeout. Defaults to 60.
#   BENCH_OUTPUT     Directory for results.json and RESULTS.md. Defaults to benchmarks/.

defmodule Bench.Spec do
  @moduledoc false

  @repo_root Path.expand("..", __DIR__)

  def repo_root, do: @repo_root

  def inputs do
    [
      %{name: "small", file: "small.md", description: "Handwritten release note: headings, list, task item, links, code block, table, quote"},
      %{name: "medium", file: "medium.md", description: "MDEx README.md (a typical README)"},
      %{name: "large", file: "large.md", description: "CommonMark Spec 0.31.2 spec.txt, by John MacFarlane, CC BY-SA 4.0"}
    ]
  end

  # Every Elixir/Erlang Markdown to HTML library found on hex.pm, plus
  # WhatsApp's erlang-markdown. `deps` are what the library's process installs.
  def libraries do
    [
      %{
        name: "mdex",
        apps: [:mdex, :mdex_native],
        url: "https://hex.pm/packages/mdex",
        implementation: "Elixir on top of mdex_native (Rust NIF)",
        deps: [{:mdex, path: @repo_root}, {:lumis_wasm_elixir, "~> 0.26"}],
        config: [mdex_native: [syntax_highlighter: :lumis]]
      },
      %{
        name: "mdex_native",
        apps: [:mdex_native],
        url: "https://hex.pm/packages/mdex_native",
        implementation: "Rust NIF (comrak, ammonia, lumis)",
        # MDEx is installed to pass its exact options to the NIF.
        deps: [{:mdex, path: @repo_root}, {:lumis_wasm_elixir, "~> 0.26"}],
        config: [mdex_native: [syntax_highlighter: :lumis]]
      },
      %{name: "cmark", apps: [:cmark], url: "https://hex.pm/packages/cmark", implementation: "C NIF (cmark)", deps: [{:cmark, "~> 0.10"}]},
      %{name: "earmark", apps: [:earmark], url: "https://hex.pm/packages/earmark", implementation: "Elixir", deps: [{:earmark, "~> 1.4"}]},
      %{name: "md", apps: [:md], url: "https://hex.pm/packages/md", implementation: "Elixir", deps: [{:md, "~> 0.15"}]},
      %{
        name: "markdownz",
        apps: [:markdownz],
        url: "https://hex.pm/packages/markdownz",
        implementation: "Erlang",
        deps: [{:markdownz, "~> 1.1"}]
      },
      %{
        name: "erlang-markdown",
        apps: [:markdown],
        url: "https://github.com/WhatsApp/erlang-markdown",
        implementation: "Erlang",
        deps: [{:markdown, github: "WhatsApp/erlang-markdown", subdir: "apps/markdown", manager: :rebar3}]
      },
      %{
        name: "markerl",
        apps: [:marker],
        url: "https://hex.pm/packages/markerl",
        implementation: "Erlang",
        # The package's OTP application is named `marker`, so Mix can't find `markerl.app`.
        deps: [{:markerl, "~> 0.1", app: false}]
      },
      %{
        name: "esperanto",
        apps: [:esperanto],
        url: "https://hex.pm/packages/esperanto",
        implementation: "Elixir",
        deps: [{:esperanto, "~> 0.1"}]
      },
      %{
        name: "panpipe",
        apps: [:panpipe],
        url: "https://hex.pm/packages/panpipe",
        implementation: "Elixir wrapper around the pandoc executable",
        deps: [{:panpipe, "~> 0.3"}]
      },
      %{
        name: "pandex",
        apps: [:pandex],
        url: "https://hex.pm/packages/pandex",
        implementation: "Elixir wrapper around the pandoc executable",
        deps: [{:pandex, "~> 0.2"}]
      },
      %{
        name: "markdownif",
        apps: [:markdownif],
        url: "https://hex.pm/packages/markdownif",
        implementation: "Rust NIF (pulldown-cmark)",
        deps: [{:markdownif, "~> 0.9"}]
      },
      %{
        name: "markdown",
        apps: [:markdown],
        url: "https://hex.pm/packages/markdown",
        implementation: "Elixir/Rust (comrak)",
        deps: [{:markdown, "~> 0.1"}]
      },
      %{name: "kramit", apps: [:kramit], url: "https://hex.pm/packages/kramit", implementation: "Elixir", deps: [{:kramit, "~> 0.0.1"}]}
    ]
  end

  # Operations, in the order they're reported.
  def operations do
    [
      {"html", "Markdown → HTML"},
      {"html_mdex_options", "Markdown → HTML, MDEx's options"},
      {"ast", "Markdown → AST"},
      {"ast_html", "AST → HTML"},
      {"highlight", "Markdown → HTML + syntax highlighting"},
      {"sanitize", "Markdown → HTML + sanitizing"},
      {"stream", "Streaming, 128-byte chunks, HTML for every update"},
      {"sigil", "~MD sigil expansion (compile time)"}
    ]
  end
end

defmodule Bench.Orchestrator do
  @moduledoc false

  @compile {:no_warn_undefined, [Jason]}

  def run do
    timeout = String.to_integer(System.get_env("BENCH_TIMEOUT") || "60")
    output_dir = System.get_env("BENCH_OUTPUT") || __DIR__
    selected = env_list("BENCH_LIBRARIES")
    libraries = Enum.filter(Bench.Spec.libraries(), &(selected == [] or &1.name in selected))
    tmp = Path.join(System.tmp_dir!(), "mdex-bench-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    environment = environment(timeout)
    IO.puts("MDEx benchmark — #{environment.date} — mdex #{String.slice(environment.mdex_commit, 0, 7)}")

    libraries =
      for library <- libraries do
        IO.puts("\n== #{library.name}")
        out = Path.join(tmp, "#{library.name}.json")

        {output, status} =
          System.cmd("elixir", [__ENV__.file, "--library", library.name, out],
            stderr_to_stdout: true,
            env: [{"BENCH_TIMEOUT", to_string(timeout)}]
          )

        case File.read(out) do
          {:ok, json} ->
            IO.puts(output |> String.split("\n") |> Enum.filter(&String.starts_with?(&1, "  bench ")) |> Enum.join("\n"))
            library |> Map.merge(Jason.decode!(json, keys: :atoms)) |> Map.put(:status, "ok")

          {:error, _} ->
            error = install_error(output)
            IO.puts("  install failed (exit #{status}): #{error}")
            Map.merge(library, %{status: "install failed", error: error, versions: %{}, rows: []})
        end
      end

    results = %{
      environment: environment,
      inputs: Enum.map(selected_inputs(), &Map.put(&1, :bytes, File.stat!(input_path(&1)).size)),
      operations: Map.new(Bench.Spec.operations()),
      libraries: Enum.map(libraries, &Map.drop(&1, [:deps, :config, :apps]))
    }

    File.write!(Path.join(output_dir, "results.json"), Jason.encode_to_iodata!(results, pretty: true))
    File.write!(Path.join(output_dir, "RESULTS.md"), Bench.Report.render(results))
    File.rm_rf!(tmp)
    IO.puts("\nWrote #{Path.join(output_dir, "results.json")} and RESULTS.md")
  end

  def selected_inputs do
    selected = env_list("BENCH_INPUTS")
    Enum.filter(Bench.Spec.inputs(), &(selected == [] or &1.name in selected))
  end

  def input_path(input), do: Path.join([__DIR__, "inputs", input.file])

  # The most specific reason in a failed install's output.
  defp install_error(output) do
    lines = output |> String.split("\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    reason =
      Enum.find_value(
        [
          &String.starts_with?(&1, "error:"),
          &String.starts_with?(&1, "One of the crate directories"),
          &String.starts_with?(&1, "Unchecked dependencies"),
          &(String.starts_with?(&1, "** (") and not String.contains?(&1, "Can't continue"))
        ],
        fn match? ->
          case Enum.split_while(lines, &(not match?.(&1))) do
            {_, []} -> nil
            {_, [line, next | _]} -> if String.starts_with?(line, "Unchecked"), do: "#{line} #{next}", else: line
            {_, [line]} -> line
          end
        end
      )

    String.slice(reason || List.last(lines) || "", 0, 300)
  end

  defp environment(timeout) do
    {date, 0} = System.cmd("date", ["+%Y-%m-%d %H:%M %Z"], env: [{"TZ", "America/Toronto"}])
    {commit, _} = System.cmd("git", ["-C", Bench.Spec.repo_root(), "rev-parse", "HEAD"])
    {dirty, _} = System.cmd("git", ["-C", Bench.Spec.repo_root(), "status", "--porcelain", "lib"])
    {uname, _} = System.cmd("uname", ["-srm"])

    pandoc =
      case System.find_executable("pandoc") do
        nil -> nil
        path -> path |> System.cmd(["--version"]) |> elem(0) |> String.split("\n") |> hd()
      end

    quick? = System.get_env("BENCH_QUICK") == "1"

    %{
      date: String.trim(date),
      mdex_commit: String.trim(commit),
      mdex_lib_dirty: dirty != "",
      elixir: System.version(),
      otp: System.otp_release(),
      erts: to_string(:erlang.system_info(:version)),
      jit: :erlang.system_info(:emu_flavor) == :jit,
      os: String.trim(uname),
      cpu: cpu(),
      logical_cpus: :erlang.system_info(:logical_processors),
      memory_gb: memory_gb(),
      pandoc: pandoc,
      quick: quick?,
      timeout_s: timeout,
      benchee: Map.new(Bench.Worker.benchee_config(quick?))
    }
  end

  defp cpu do
    with {:ok, info} <- File.read("/proc/cpuinfo") do
      info |> String.split("\n") |> Enum.find_value(&(&1 =~ ~r/^model name/ && &1 |> String.split(":", parts: 2) |> List.last() |> String.trim()))
    else
      _ -> nil
    end
  end

  defp memory_gb do
    case File.read("/proc/meminfo") do
      {:ok, "MemTotal:" <> rest} -> rest |> String.split() |> hd() |> String.to_integer() |> Kernel./(1024 * 1024) |> Float.round(1)
      _ -> nil
    end
  end

  def env_list(var) do
    case System.get_env(var) do
      nil -> []
      value -> value |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
    end
  end
end

defmodule Bench.Worker do
  @moduledoc false

  # Each library is only installed in its own process.
  @compile {:no_warn_undefined,
            [
              MDEx,
              MDEx.Document,
              MDExNative.Comrak,
              Cmark,
              Earmark,
              Earmark.Parser,
              Earmark.Transform,
              Md,
              :markdownz,
              :markdown,
              :marker,
              :render,
              Esperanto.Parser,
              Panpipe,
              Pandex,
              Markdownif,
              Markdown,
              Kramit,
              Benchee,
              Jason
            ]}

  def benchee_config(true = _quick), do: [warmup: 0.5, time: 1, memory_time: 0.2, reduction_time: 0.2]
  def benchee_config(false), do: [warmup: 2, time: 5, memory_time: 1, reduction_time: 1]

  def run(library, out) do
    timeout = String.to_integer(System.get_env("BENCH_TIMEOUT") || "60") * 1000
    config = benchee_config(System.get_env("BENCH_QUICK") == "1")

    rows =
      for input <- Bench.Orchestrator.selected_inputs(),
          markdown <- [File.read!(Bench.Orchestrator.input_path(input))],
          {operation, job} <- jobs(library.name, markdown) do
        row = %{library: library.name, input: input.name, operation: operation}

        case probe(job, timeout) do
          :ok ->
            stats = measure(job, config)
            IO.puts("  bench #{input.name} #{operation}: #{format_ips(stats.ips)} ips, median #{round(stats.median_ns / 1000)} µs")
            row |> Map.merge(stats) |> Map.put(:status, "ok")

          {status, error} ->
            IO.puts("  bench #{input.name} #{operation}: #{status} #{error}")
            Map.merge(row, %{status: status, error: error})
        end
      end

    versions =
      Map.new(library.apps, fn app ->
        Application.load(app)
        {app, app |> Application.spec(:vsn) |> to_string()}
      end)

    File.write!(out, Jason.encode_to_iodata!(%{versions: versions, rows: rows}))
  end

  # One call in a separate process, so a call that hangs or raises marks the row
  # instead of stopping the run. A result shaped like an error is a failure too.
  defp probe(job, timeout) do
    task = Task.async(fn -> try_call(job) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, :ok} -> :ok
      {:ok, {:error, reason}} -> {"error", reason}
      {:exit, reason} -> {"error", Exception.format_exit(reason) |> String.slice(0, 300)}
      nil -> {"timeout", "one call took longer than #{div(timeout, 1000)} s"}
    end
  end

  defp try_call(job) do
    case job.() do
      {:error, reason} -> {:error, "returned an error: " <> String.slice(inspect(reason), 0, 300)}
      {:error, _html, messages} -> {:error, "returned an error: " <> String.slice(inspect(messages), 0, 300)}
      _ -> :ok
    end
  rescue
    exception -> {:error, "raised " <> String.slice(Exception.format_banner(:error, exception), 0, 300)}
  end

  defp measure(job, config) do
    [scenario] =
      Benchee.run(%{"job" => job}, config ++ [formatters: [], print: [benchmarking: false, configuration: false, fast_warning: false]]).scenarios

    run = scenario.run_time_data.statistics

    %{
      ips: run.ips,
      average_ns: run.average,
      median_ns: run.median,
      p99_ns: run.percentiles[99],
      deviation_pct: run.std_dev_ratio * 100,
      sample_size: run.sample_size,
      memory_bytes: scenario.memory_usage_data.statistics.median,
      reductions: scenario.reductions_data.statistics.median
    }
  end

  defp format_ips(ips) when ips >= 10, do: ips |> round() |> Integer.to_string()
  defp format_ips(ips), do: :erlang.float_to_binary(ips, decimals: 2)

  @stream_chunk_size 128
  @highlight [syntax_highlight: [engine: :lumis]]

  # Each library's calls, keyed by operation. Every call is the library's
  # documented default unless the operation says otherwise.
  def jobs("mdex", md) do
    {:ok, document} = MDEx.parse_document(md)
    sanitize = [sanitize: MDEx.Document.default_sanitize_options()]
    chunks = chunk(md, @stream_chunk_size)
    sigil_env = sigil_env()

    [
      {"html", fn -> MDEx.to_html(md) end},
      {"ast", fn -> MDEx.parse_document(md) end},
      {"ast_html", fn -> MDEx.to_html(document) end},
      {"highlight", fn -> MDEx.to_html(md, @highlight) end},
      {"sanitize", fn -> MDEx.to_html(md, sanitize) end},
      {"stream", fn -> chunks |> MDEx.stream() |> Stream.map(fn {id, doc} -> {id, MDEx.to_html!(doc)} end) |> Stream.run() end},
      {"sigil", fn -> Macro.expand_once({:sigil_MD, [], [{:<<>>, [], [md]}, ~c"HTML"]}, sigil_env) end}
    ]
  end

  def jobs("mdex_native", md) do
    # The options MDEx passes to the NIF, from the function MDEx uses.
    options = fn opts -> MDEx.Document.rust_options!(MDEx.new(opts).options) end
    plain = options.([])
    highlight = options.(@highlight)
    sanitize = options.(sanitize: MDEx.Document.default_sanitize_options())
    {:ok, document} = MDExNative.Comrak.parse_document(md, plain)

    [
      {"html", fn -> MDExNative.Comrak.markdown_to_html(md) end},
      {"html_mdex_options", fn -> MDExNative.Comrak.markdown_to_html(md, plain) end},
      {"ast", fn -> MDExNative.Comrak.parse_document(md, plain) end},
      {"ast_html", fn -> MDExNative.Comrak.document_to_html(document, plain) end},
      {"highlight", fn -> MDExNative.Comrak.markdown_to_html(md, highlight) end},
      {"sanitize", fn -> MDExNative.Comrak.markdown_to_html(md, sanitize) end}
    ]
  end

  def jobs("cmark", md), do: [{"html", fn -> Cmark.to_html(md) end}]

  def jobs("earmark", md) do
    ast =
      case Earmark.Parser.as_ast(md) do
        {:ok, ast, _messages} -> ast
        _ -> []
      end

    [
      {"html", fn -> Earmark.as_html(md) end},
      {"ast", fn -> Earmark.Parser.as_ast(md) end},
      {"ast_html", fn -> Earmark.Transform.transform(ast) end}
    ]
  end

  def jobs("md", md) do
    state = Md.parse(md)
    [{"html", fn -> Md.generate(md) end}, {"ast", fn -> Md.parse(md) end}, {"ast_html", fn -> Md.generate(state) end}]
  end

  def jobs("markdownz", md), do: [{"html", fn -> :markdownz.to_binary(md) end}, {"ast", fn -> :markdownz.parse(md) end}]

  def jobs("erlang-markdown", md), do: [{"html", fn -> :markdown.to_html(md) end}]

  def jobs("markerl", md) do
    chars = String.to_charlist(md)

    [
      {"html", fn -> chars |> :marker.markdown() |> elem(1) |> :render.html() |> IO.iodata_to_binary() end},
      {"ast", fn -> :marker.markdown(chars) end}
    ]
  end

  def jobs("esperanto", md), do: [{"html", fn -> Esperanto.Parser.to_xml(md) end}]

  def jobs("panpipe", md), do: [{"html", fn -> Panpipe.to_html(md) end}, {"ast", fn -> Panpipe.ast(md) end}]

  def jobs("pandex", md), do: [{"html", fn -> Pandex.markdown_to_html(md) end}]

  def jobs("markdownif", md), do: [{"html", fn -> Markdownif.to_html(md) end}]

  def jobs("markdown", md), do: [{"html", fn -> Markdown.to_html(md) end}]

  def jobs("kramit", md), do: [{"html", fn -> Kramit.to_html(md) end}]

  defp chunk(binary, size) do
    case binary do
      <<chunk::binary-size(^size), rest::binary>> -> [chunk | chunk(rest, size)]
      rest -> [rest]
    end
  end

  # A caller outside a module that imports MDEx.Sigil, as `~MD` in a script sees it.
  defp sigil_env do
    {env, _binding} = Code.eval_string("import MDEx.Sigil, warn: false; __ENV__")
    %{env | module: nil, function: nil}
  end
end

defmodule Bench.Report do
  @moduledoc false

  @compile {:no_warn_undefined, [Jason]}

  def render(results) do
    env = results.environment
    inputs = results.inputs
    libraries = results.libraries
    rows = Enum.flat_map(libraries, & &1.rows)

    """
    # Markdown benchmark results

    Generated by [`benchmark.exs`](benchmark.exs) on #{env.date} (America/Toronto) at MDEx commit `#{String.slice(env.mdex_commit, 0, 7)}`#{if env.mdex_lib_dirty, do: " with uncommitted changes in lib/", else: ""}#{if env.quick, do: ". **Quick run: don't publish these numbers.**", else: "."}

    - Machine: #{env.cpu}, #{env.logical_cpus} logical CPUs, #{env.memory_gb} GB RAM, #{env.os}
    - Elixir #{env.elixir}, Erlang/OTP #{env.otp} (erts #{env.erts}#{if env.jit, do: ", JIT"})#{if env.pandoc, do: ", #{env.pandoc}"}
    - Benchee per row: #{env.benchee.warmup} s warmup, #{env.benchee.time} s run time, #{env.benchee.memory_time} s memory, #{env.benchee.reduction_time} s reductions. Each library runs in its own BEAM.
    - Before a row is benchmarked, one call runs on its own: a call over #{env.timeout_s} s is a **timeout**, a call that raises or returns an error is an **error**.
    - ips is calls per second (higher is better). Memory is what Benchee measures on the BEAM process heap, so it leaves out memory a NIF or an external program allocates.

    ## Libraries

    | Library | Version | Implementation | Status |
    |---|---|---|---|
    #{Enum.map_join(libraries, "\n", &library_row/1)}

    ## Inputs

    Vendored in [`inputs/`](inputs).

    | Input | Size | Content |
    |---|---:|---|
    #{Enum.map_join(inputs, "\n", &"| #{&1.name} | #{format_int(&1.bytes)} B | #{&1.description} |")}

    ## Operations

    | Operation | Libraries | What runs |
    |---|---|---|
    #{operations_table(libraries, results.operations)}

    #{Enum.map_join(Bench.Spec.operations(), "\n", &operation_section(&1, inputs, rows))}
    ## MDEx and mdex_native with the same options

    MDEx's throughput as a share of mdex_native's, both called with MDEx's options (`mdex_native` rows use `MDEx.Document.rust_options!/1`).

    | Operation | #{Enum.map_join(inputs, " | ", & &1.name)} |
    |---|#{Enum.map_join(inputs, "|", fn _ -> "---:" end)}|
    #{same_options_table(inputs, rows)}
    """
  end

  defp library_row(library) do
    versions = Enum.map_join(library.versions, ", ", fn {app, vsn} -> if map_size(library.versions) > 1, do: "#{app} #{vsn}", else: vsn end)

    status =
      cond do
        library.status != "ok" -> "**#{library.status}**: #{escape(library.error)}"
        Enum.all?(library.rows, &(&1.status != "ok")) -> "installed, **every call failed** (see the tables)"
        true -> "installed"
      end

    "| [#{library.name}](#{library.url}) | #{if versions == "", do: "n/a", else: versions} | #{library.implementation} | #{status} |"
  end

  @calls %{
    "mdex" => %{
      "html" => "`MDEx.to_html(md)`",
      "ast" => "`MDEx.parse_document(md)`",
      "ast_html" => "`MDEx.to_html(document)`",
      "highlight" => "`MDEx.to_html(md, syntax_highlight: [engine: :lumis])`",
      "sanitize" => "`MDEx.to_html(md, sanitize: MDEx.default_sanitize_options())`",
      "stream" => "`MDEx.stream(chunks)`, `MDEx.to_html!/1` on each document",
      "sigil" => "`~MD\"...\"HTML` macro expansion; at runtime the result is a string literal"
    },
    "mdex_native" => %{
      "html" => "`MDExNative.Comrak.markdown_to_html(md)`, Comrak's defaults",
      "html_mdex_options" => "`markdown_to_html(md, options)`",
      "ast" => "`parse_document(md, options)`",
      "ast_html" => "`document_to_html(document, options)`",
      "highlight" => "`markdown_to_html(md, options)` with Lumis",
      "sanitize" => "`markdown_to_html(md, options)` with ammonia"
    }
  }

  defp operations_table(libraries, operations) do
    ok = Enum.filter(libraries, &(&1.status == "ok"))

    Enum.map_join(Bench.Spec.operations(), "\n", fn {key, label} ->
      libs = ok |> Enum.filter(fn lib -> Enum.any?(lib.rows, &(&1.operation == key)) end) |> Enum.map(& &1.name)
      calls = for lib <- ["mdex", "mdex_native"], call = get_in(@calls, [lib, key]), do: "#{lib}: #{call}"
      _ = operations
      "| #{label} | #{Enum.join(libs, ", ")} | #{Enum.join(calls, "; ")} |"
    end)
  end

  defp operation_section({key, label}, inputs, rows) do
    op_rows = Enum.filter(rows, &(&1.operation == key))

    if op_rows == [] do
      ""
    else
      """
      ## #{label}

      #{Enum.map_join(inputs, "\n", &input_table(&1, op_rows))}
      """
    end
  end

  defp input_table(input, op_rows) do
    rows = Enum.filter(op_rows, &(&1.input == input.name))
    {ok, failed} = Enum.split_with(rows, &(&1.status == "ok"))
    ok = Enum.sort_by(ok, & &1.ips, :desc)
    fastest = List.first(ok)

    """
    ### #{input.name} (#{format_int(input.bytes)} B)

    | Library | ips | vs fastest | median | p99 | deviation | memory | reductions |
    |---|---:|---:|---:|---:|---:|---:|---:|
    #{Enum.map_join(ok, "\n", &ok_row(&1, fastest))}#{if failed != [], do: "\n"}#{Enum.map_join(failed, "\n", &"| #{&1.library} | **#{&1.status}** | #{escape(&1.error)} | | | | | |")}
    """
  end

  defp ok_row(row, fastest) do
    relative = if row == fastest, do: "fastest", else: "#{format_float(fastest.ips / row.ips)}x slower"

    "| #{row.library} | #{format_ips(row.ips)} | #{relative} | #{format_time(row.median_ns)} | #{format_time(row.p99_ns)} | ±#{format_float(row.deviation_pct)}% | #{format_bytes(row.memory_bytes)} | #{format_int(round(row.reductions))} |"
  end

  @pairs [{"html", "html_mdex_options"}, {"highlight", "highlight"}, {"sanitize", "sanitize"}, {"ast", "ast"}, {"ast_html", "ast_html"}]

  defp same_options_table(inputs, rows) do
    find = fn lib, op, input -> Enum.find(rows, &(&1.library == lib and &1.operation == op and &1.input == input and &1.status == "ok")) end
    labels = Map.new(Bench.Spec.operations())

    Enum.map_join(@pairs, "\n", fn {mdex_op, native_op} ->
      cells =
        Enum.map_join(inputs, " | ", fn input ->
          with %{} = mdex <- find.("mdex", mdex_op, input.name), %{} = native <- find.("mdex_native", native_op, input.name) do
            "#{round(mdex.ips / native.ips * 100)}% (#{format_time(mdex.median_ns)} vs #{format_time(native.median_ns)})"
          else
            _ -> "n/a"
          end
        end)

      "| #{labels[mdex_op]} | #{cells} |"
    end)
  end

  defp escape(nil), do: ""
  defp escape(text), do: text |> String.replace("|", "\\|") |> String.replace("\n", " ")

  defp format_ips(ips) when ips >= 10, do: format_int(round(ips))
  defp format_ips(ips), do: format_float(ips)

  defp format_time(ns) when ns >= 1_000_000_000, do: "#{format_float(ns / 1_000_000_000)} s"
  defp format_time(ns) when ns >= 1_000_000, do: "#{format_float(ns / 1_000_000)} ms"
  defp format_time(ns), do: "#{format_float(ns / 1000)} µs"

  defp format_bytes(nil), do: "n/a"
  defp format_bytes(b) when b >= 1024 * 1024, do: "#{format_float(b / 1024 / 1024)} MB"
  defp format_bytes(b) when b >= 1024, do: "#{format_float(b / 1024)} KB"
  defp format_bytes(b), do: "#{round(b)} B"

  defp format_float(x) when x >= 100, do: format_int(round(x))
  defp format_float(x), do: :erlang.float_to_binary(x / 1, decimals: 2)

  defp format_int(n), do: n |> Integer.to_string() |> String.replace(~r/\B(?=(\d{3})+$)/, ",")
end

case System.argv() do
  ["--library", name, out] ->
    library = Enum.find(Bench.Spec.libraries(), &(&1.name == name))
    Mix.install(library.deps ++ [{:benchee, "~> 1.5"}, {:jason, "~> 1.4"}], config: Map.get(library, :config, []))
    Bench.Worker.run(library, out)

  _ ->
    Mix.install([{:jason, "~> 1.4"}])
    Bench.Orchestrator.run()
end
