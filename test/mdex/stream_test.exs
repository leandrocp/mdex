defmodule MDEx.StreamTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias MDEx.Document

  test "deprecates the MDEx.new streaming option while preserving compatibility" do
    warning =
      capture_io(:stderr, fn ->
        document = MDEx.new(streaming: true) |> Document.put_markdown("**partial")
        assert MDEx.to_html!(document) == "<p><strong>partial</strong></p>"
      end)

    assert warning =~ "the :streaming option is deprecated"
    assert warning =~ "MDEx.stream/2"
  end

  test "returns a native lazy Stream" do
    parent = self()

    chunks =
      Stream.resource(
        fn ->
          send(parent, :started)
          ["# One", "\n\nTwo"]
        end,
        fn
          [chunk | rest] -> {[chunk], rest}
          [] -> {:halt, []}
        end,
        fn _state -> send(parent, :closed) end
      )

    stream = MDEx.stream(chunks)

    assert %Stream{} = stream
    refute_received :started

    assert [{0, %Document{}}] = Enum.take(stream, 1)
    assert_received :started
    assert_received :closed
  end

  test "emits keyed tail replacements and finalizes at EOF" do
    events =
      ["# Hel", "lo\n\nNow **wri", "ting**"]
      |> MDEx.stream()
      |> Enum.map(fn {id, document} -> {id, MDEx.to_html!(document)} end)

    assert events == [
             {0, "<h1>Hel</h1>"},
             {0, "<h1>Hello</h1>"},
             {1, "<p>Now <strong>wri</strong></p>"},
             {1, "<p>Now <strong>writing</strong></p>"},
             {1, "<p>Now <strong>writing</strong></p>"}
           ]
  end

  test "emits no chunks for empty input" do
    assert [] = Enum.to_list(MDEx.stream([]))
    assert [] = Enum.to_list(MDEx.stream([""]))
  end

  test "buffers UTF-8 code points divided across chunks" do
    events = MDEx.stream(["ol", <<0xC3>>, <<0xA1>>, "\n\n# Next"])

    assert final_html(events) == MDEx.to_html!("olá\n\n# Next")
  end

  test "raises lazily for incomplete or invalid UTF-8" do
    incomplete = MDEx.stream(["ol", <<0xC3>>])
    invalid = MDEx.stream([<<0xFF>>])

    assert %Stream{} = incomplete

    assert_raise ArgumentError, ~r/end-of-input with incomplete UTF-8/, fn ->
      Enum.to_list(incomplete)
    end

    assert_raise ArgumentError, ~r/received invalid UTF-8/, fn ->
      Enum.to_list(invalid)
    end
  end

  test "raises lazily when the source emits a non-binary" do
    stream = MDEx.stream(["valid", :not_a_binary])

    assert_raise ArgumentError, ~r/expected a binary chunk/, fn ->
      Enum.to_list(stream)
    end
  end

  test "can be enumerated again when its source is repeatable" do
    stream = MDEx.stream(["# One\n\n", "Two"])

    assert Enum.map(stream, &elem(&1, 0)) == Enum.map(stream, &elem(&1, 0))
    assert final_html(stream) == MDEx.to_html!("# One\n\nTwo")
  end

  test "stops requesting upstream chunks when downstream halts" do
    parent = self()

    chunks =
      Stream.resource(
        fn -> 0 end,
        fn
          0 ->
            {["**fir"], 1}

          1 ->
            send(parent, :requested_unseen_chunk)
            {["st**"], 2}

          2 ->
            {:halt, 2}
        end,
        fn _state -> send(parent, :source_closed) end
      )

    assert [{0, document}] = chunks |> MDEx.stream() |> Enum.take(1)
    assert MDEx.to_html!(document) == "<p><strong>fir</strong></p>"
    refute_received :requested_unseen_chunk
    assert_received :source_closed
  end

  test "propagates upstream failures and closes the source" do
    parent = self()

    chunks =
      Stream.resource(
        fn -> 0 end,
        fn
          0 -> {["# Started"], 1}
          1 -> raise "upstream failed"
        end,
        fn _state -> send(parent, :source_closed) end
      )

    assert_raise RuntimeError, "upstream failed", fn ->
      chunks |> MDEx.stream() |> Enum.to_list()
    end

    assert_received :source_closed
  end

  test "applies parser options and preserves final rendering across chunk boundaries" do
    options = [extension: [strikethrough: true, table: true, tasklist: true]]

    markdown = """
    # Status

    - [x] ~~prototype~~ Stream

    | API | Value |
    | --- | --- |
    | input | Enumerable |
    """

    chunks = ["# Sta", "tus\n\n- [x] ~~proto", "type~~ Stream\n\n| API |", " Value |\n| --- | --- |\n| input | Enumerable |\n"]

    events = MDEx.stream(chunks, options)

    assert final_html(events) == MDEx.to_html!(markdown, options)
    assert Enum.all?(events, fn {_id, document} -> document.buffer == [] end)
  end

  test "matches the final put_markdown document for document-wide constructs" do
    options = [extension: [table: true]]

    cases = [
      ["- one\n\n", "- two\n\n"],
      ["~~~~\nalpha\n\n", "beta\n~~~~\n"],
      ["Read [the docs].\n\nNext paragraph.\n\n", "[the docs]: https://example.com\n"],
      ["| Name | Value |\n| --- | --- |\n|", " mdex | Stream |\n"]
    ]

    for chunks <- cases do
      document =
        Enum.reduce(chunks, MDEx.new(options), fn chunk, document ->
          Document.put_markdown(document, chunk)
        end)
        |> Document.run()

      assert final_html(MDEx.stream(chunks, options)) == MDEx.to_html!(document)
    end
  end

  test "derives blank block boundaries from parser source positions" do
    for separator <- ["\n\n", "\n \t\n", "\r\n\r\n", "\r\n \t\r\n"] do
      events = Enum.to_list(MDEx.stream(["First#{separator}Second"]))

      assert [{0, first}, {1, partial_second}, {1, final_second}] = events
      assert MDEx.to_html!(first) == "<p>First</p>"
      assert MDEx.to_html!(partial_second) == "<p>Second</p>"
      assert MDEx.to_html!(final_second) == "<p>Second</p>"
      refute Enum.any?(events, fn {_id, document} -> Keyword.has_key?(document.options, :streaming) end)
    end

    assert [{0, joined}, {0, finalized}] = Enum.to_list(MDEx.stream(["First\nSecond"]))
    assert MDEx.to_html!(joined) == "<p>First\nSecond</p>"
    assert MDEx.to_html!(finalized) == "<p>First\nSecond</p>"
  end

  test "re-emits an earlier id when document-wide syntax changes its AST" do
    reference_events =
      Enum.to_list(
        MDEx.stream([
          "Read [the docs].\n\nAnother paragraph.\n\nTail.\n\n",
          "[the docs]: https://example.com\n"
        ])
      )

    assert [{0, unresolved}, {1, tail}, {0, linked}, {1, final_tail}] = reference_events
    assert MDEx.to_html!(unresolved) =~ "<p>Read [the docs].</p>"
    assert MDEx.to_html!(linked) =~ ~s(<a href="https://example.com">the docs</a>)
    assert MDEx.to_html!(tail) == "<p>Tail.</p>"
    assert MDEx.to_html!(final_tail) == MDEx.to_html!(tail)

    ids = Enum.map(reference_events, &elem(&1, 0))
    assert ids == [0, 1, 0, 1]
  end

  test "preserves a late footnote definition across keyed documents" do
    chunks = [
      "Fact.[^note]\n\nAnother paragraph.\n\n",
      "[^note]: More context.\n"
    ]

    options = [extension: [footnotes: true]]
    events = Enum.to_list(MDEx.stream(chunks, options))

    assert Enum.count(events, fn {id, _document} -> id == 0 end) == 2
    assert final_html(events) == MDEx.to_html!(Enum.join(chunks), options)
    assert final_html(events) =~ ~s(<section class="footnotes")
  end

  test "does not treat task items as link references" do
    task_events =
      Enum.to_list(MDEx.stream(["- [x] done\n\nNext"], extension: [tasklist: true]))

    assert [{0, task}, {1, next}, {1, final_next}] = task_events
    assert MDEx.to_html!(task) =~ ~s(type="checkbox" checked="")
    assert MDEx.to_html!(next) == "<p>Next</p>"
    assert MDEx.to_html!(final_next) == "<p>Next</p>"
  end

  test "parses the cumulative source once per input chunk and once at EOF" do
    source = "First **bold**\n\nSecond `code`\n\n- Third\n  - nested **strong**"

    {calls, events} =
      trace_parser_calls(fn ->
        Enum.to_list(MDEx.stream([source]))
      end)

    assert calls == [:parse_document, :parse_document]
    assert [{0, stable}, {1, _partial}, {1, final}] = events
    assert stable.nodes == MDEx.parse_document!("First **bold**\n\nSecond `code`\n\n").nodes
    assert MDEx.to_html!(final) == MDEx.to_html!("- Third\n  - nested **strong**")
    assert [%MDEx.List{sourcepos: %{start: {5, 1}}}] = final.nodes
  end

  test "allows each streamed AST to be changed before rendering" do
    chunks = [
      "Intro [site](https://example.com/a",
      ").\n\nRead [the docs].\n\n",
      "[the docs]: https://example.com/docs\n"
    ]

    rewrite_links = fn document ->
      Document.update_nodes(document, MDEx.Link, fn link ->
        %{link | url: "https://proxy.test/?target=" <> URI.encode_www_form(link.url)}
      end)
    end

    transformed_events =
      chunks
      |> MDEx.stream()
      |> Enum.map(fn {id, document} -> {id, rewrite_links.(document)} end)

    expected =
      chunks
      |> Enum.join()
      |> MDEx.parse_document!()
      |> rewrite_links.()
      |> MDEx.to_html!()

    assert final_html(transformed_events) == expected

    assert Enum.any?(transformed_events, fn {_id, document} ->
             MDEx.to_html!(document) =~ "https://proxy.test/?target=https%3A%2F%2Fexample.com%2Fdocs"
           end)
  end

  test "runs document plugins on reused stable and EOF ASTs" do
    rewrite_links = fn document ->
      Document.append_steps(document,
        rewrite_links: fn document ->
          Document.update_nodes(document, MDEx.Link, fn link ->
            %{link | url: "https://proxy.test/?target=" <> URI.encode_www_form(link.url)}
          end)
        end
      )
    end

    events =
      Enum.to_list(
        MDEx.stream(
          ["[one](https://example.com/one)\n\n[two](https://example.com/two)"],
          plugins: [rewrite_links]
        )
      )

    assert [{0, stable}, {1, _partial}, {1, final}] = events
    assert MDEx.to_html!(stable) =~ "target=https%3A%2F%2Fexample.com%2Fone"
    assert MDEx.to_html!(final) =~ "target=https%3A%2F%2Fexample.com%2Ftwo"
  end

  test "attaches plugins once and applies their parser options before parsing" do
    test_process = self()

    plugin = fn document ->
      send(test_process, :plugin_attached)

      document
      |> Document.put_extension_options(table: true)
      |> Document.append_steps(
        plugin_step: fn document ->
          send(test_process, :plugin_step_ran)
          document
        end
      )
    end

    stream =
      MDEx.stream(
        ["| A |\n| --- |\n| B |\n\nTail"],
        plugins: [plugin]
      )

    refute_received :plugin_attached
    events = Enum.to_list(stream)

    assert [{0, stable}, {1, _partial}, {1, final}] = events
    assert MDEx.to_html!(stable) =~ "<table>"
    assert MDEx.to_html!(final) == "<p>Tail</p>"

    assert_received :plugin_attached
    refute_received :plugin_attached

    for _event <- events do
      assert_received :plugin_step_ran
    end

    refute_received :plugin_step_ran
  end

  defp final_html(events) do
    {ids, documents} =
      Enum.reduce(events, {[], %{}}, fn {id, document}, {ids, documents} ->
        ids = if Map.has_key?(documents, id), do: ids, else: ids ++ [id]
        {ids, Map.put(documents, id, document)}
      end)

    Enum.map_join(ids, "\n", fn id -> documents |> Map.fetch!(id) |> MDEx.to_html!() end)
  end

  defp trace_parser_calls(fun) do
    Code.ensure_loaded!(MDExNative.Comrak)
    tracee = self()
    tracer = spawn_link(fn -> collect_parser_calls([]) end)

    :erlang.trace(tracee, true, [:call, {:tracer, tracer}])
    :erlang.trace_pattern({MDExNative.Comrak, :parse_document, 2}, true, [:local])

    try do
      result = fun.()
      reference = :erlang.trace_delivered(tracee)
      assert_receive {:trace_delivered, ^tracee, ^reference}
      send(tracer, {:get_calls, self()})
      assert_receive {:parser_calls, calls}
      {calls, result}
    after
      :erlang.trace(tracee, false, [:call])
      :erlang.trace_pattern({MDExNative.Comrak, :parse_document, 2}, false, [:local])

      if Process.alive?(tracer) do
        Process.exit(tracer, :normal)
      end
    end
  end

  defp collect_parser_calls(calls) do
    receive do
      {:trace, _pid, :call, {MDExNative.Comrak, name, _args}} ->
        collect_parser_calls([name | calls])

      {:get_calls, caller} ->
        send(caller, {:parser_calls, Enum.reverse(calls)})
    end
  end
end
