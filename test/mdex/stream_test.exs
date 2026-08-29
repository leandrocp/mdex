defmodule MDEx.StreamTest do
  use ExUnit.Case, async: true

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

  test "uses parser metadata to hold unresolved reference links without holding task items" do
    reference_events =
      Enum.to_list(
        MDEx.stream([
          "Stable paragraph.\n\nRead [the docs].\n\n",
          "[the docs]: https://example.com\n"
        ])
      )

    assert [{0, stable}, {1, unresolved}, {1, linked}, {1, final_linked}] = reference_events
    assert MDEx.to_html!(stable) == "<p>Stable paragraph.</p>"
    assert MDEx.to_html!(unresolved) == "<p>Read [the docs].</p>"
    assert MDEx.to_html!(linked) =~ ~s(<a href="https://example.com">the docs</a>)
    assert MDEx.to_html!(final_linked) == MDEx.to_html!(linked)

    task_events =
      Enum.to_list(MDEx.stream(["- [x] done\n\nNext"], extension: [tasklist: true]))

    assert [{0, task}, {1, next}, {1, final_next}] = task_events
    assert MDEx.to_html!(task) =~ ~s(type="checkbox" checked="")
    assert MDEx.to_html!(next) == "<p>Next</p>"
    assert MDEx.to_html!(final_next) == "<p>Next</p>"
  end

  defp final_html(events) do
    {ids, documents} =
      Enum.reduce(events, {[], %{}}, fn {id, document}, {ids, documents} ->
        ids = if Map.has_key?(documents, id), do: ids, else: ids ++ [id]
        {ids, Map.put(documents, id, document)}
      end)

    Enum.map_join(ids, "\n", fn id -> documents |> Map.fetch!(id) |> MDEx.to_html!() end)
  end
end
