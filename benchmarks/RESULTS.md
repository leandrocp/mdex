# MDEx benchmark results

Run on Sunday, November 1, 2026 (America/Toronto) with [`benchmarks/benchmark.exs`](benchmark.exs).

|  | Before | After |
|---|---|---|
| MDEx commit | `fad697a` (main) | `e03df40` (perf: cut MDEx overhead around native calls) |
| Started | 2026-11-01 11:12 EST | 2026-11-01 11:41 EST |
| JSON | [`results-baseline.json`](results-baseline.json) | [`results.json`](results.json) |

Both runs used the same machine, inputs, and settings:

- Amp orb (cloud VM): Intel(R) Xeon(R) Processor @ 2.60GHz, 2 logical CPUs, 3 GB RAM, Linux 6.1.158+ x86_64
- Elixir 1.20.5, Erlang/OTP 29 (erts 17.1.1, JIT)
- mdex 0.14.6 (local checkout), mdex_native 0.3.1 (Lumis build), lumis_wasm_elixir 0.26.8, Benchee 1.5.1
- cmark 0.10.0, md 0.15.1, earmark 1.4.49, erlang-markdown (`markdown` 1.0.0, WhatsApp/erlang-markdown main)
- Benchee: 2 s warmup, 5 s run time, 1 s memory, 1 s reductions per row

This is a shared 2-vCPU VM, so absolute numbers are slower than on a laptop, and rows that didn't change moved by up to ±10% between runs (see the mdex_native, cmark, md, and earmark rows). Compare MDEx with mdex_native **within the same run**. "Memory" is what Benchee measures on the BEAM process heap; it does not see memory the Rust NIF allocates, so it understates NIF rows.

## Inputs

Vendored in [`inputs/`](inputs), nothing is fetched at run time.

| Input | Size | Content |
|---|---:|---|
| small | 540 B | Handwritten release note: headings, list, task item, link, autolink, code block, table, quote |
| medium | 13,339 B | MDEx `README.md` at `fad697a` (a typical README) |
| large | 205,025 B | [CommonMark Spec 0.31.2](https://spec.commonmark.org/0.31.2/) `spec.txt`, by John MacFarlane, CC BY-SA 4.0 |

## Rows

Each MDEx row has an mdex_native row with **the same options**, computed with the same function MDEx uses before calling the NIF (`MDEx.Document.rust_options!/1` on MDEx's defaults). Before benchmarking, the script checks that each pair renders the same HTML (MDEx trims the trailing newline).

| Row | What it runs |
|---|---|
| mdex_native markdown_to_html (comrak defaults) | `MDExNative.Comrak.markdown_to_html(md)`: the raw engine with Comrak's defaults, the call the old benchmark used |
| mdex_native markdown_to_html / MDEx.to_html | Markdown → HTML, MDEx defaults (no highlighting, no sanitizing) |
| … + highlight | Lumis syntax highlighting, `syntax_highlight: [engine: :lumis]` |
| … + sanitize | `sanitize: MDEx.default_sanitize_options()` |
| mdex_native parse_document / MDEx.parse_document | Markdown → AST (`MDExNative.Comrak.Document` / `MDEx.Document`) |
| mdex_native document_to_html / MDEx.to_html(document) | AST → HTML from an already parsed document |
| MDEx.stream + to_html each | `MDEx.stream/2` over the input in 128-byte chunks, rendering every emitted document to HTML, as a LiveView rendering an LLM response would |
| ~MD sigil expansion (HTML) | Expanding `~MD"..."HTML`, the work done at compile time. At runtime the sigil is a string literal and costs nothing |
| cmark, md, earmark, erlang-markdown | Other Elixir/Erlang Markdown libraries with their defaults. cmark is a C NIF, the others are pure Elixir/Erlang |

The script also times compiling a module that holds `~MD"..."HTML` (median of 5 runs). Most of that time is the Elixir compiler: 4.5/5.8/34.8 ms before and 4.7/6.1/36.3 ms after for small/medium/large.

## Summary

MDEx's overhead around the engine was mostly fixed per-call work in Elixir (option validation and defaults rebuilt on every call), plus a slow AST conversion. Now `MDEx.to_html/2` runs within 4% of mdex_native on a README-sized document and larger, and `MDEx.parse_document/2` and `MDEx.to_html/2` on an `MDEx.Document` are 1.7–8x faster (the smaller the document, the bigger the gain).

MDEx compared with mdex_native using the same options, within each run (median times; throughput is MDEx ips ÷ mdex_native ips):

| Input | Operation | before: MDEx / mdex_native | before: MDEx throughput vs engine | after: MDEx / mdex_native | after: MDEx throughput vs engine |
|---|---|---:|---:|---:|---:|
| small | to_html | 346.7 µs / 17.6 µs | 5% | 22.8 µs / 20.1 µs | 83% |
| small | to_html + highlight | 568.4 µs / 158.5 µs | 31% | 168.0 µs / 155.2 µs | 92% |
| small | to_html + sanitize | 608.5 µs / 99.1 µs | 17% | 110.6 µs / 97.6 µs | 85% |
| small | parse_document | 373.2 µs / 30.4 µs | 9% | 49.0 µs / 28.7 µs | 56% |
| small | Document → HTML | 385.7 µs / 31.5 µs | 8% | 45.9 µs / 31.1 µs | 67% |
| medium | to_html | 546.1 µs / 238.6 µs | 43% | 248.3 µs / 241.0 µs | 96% |
| medium | to_html + highlight | 3.81 ms / 3.29 ms | 89% | 3.53 ms / 3.45 ms | 98% |
| medium | to_html + sanitize | 1.45 ms / 1.03 ms | 70% | 1.03 ms / 1.01 ms | 99% |
| medium | parse_document | 1.43 ms / 417.4 µs | 29% | 478.4 µs / 414.6 µs | 87% |
| medium | Document → HTML | 1.18 ms / 360.9 µs | 29% | 459.2 µs / 355.8 µs | 76% |
| large | to_html | 4.65 ms / 3.87 ms | 79% | 4.24 ms / 4.24 ms | 99% |
| large | to_html + highlight | 52.54 ms / 46.46 ms | 87% | 49.63 ms / 50.62 ms | 102% |
| large | to_html + sanitize | 14.15 ms / 12.88 ms | 95% | 12.62 ms / 12.54 ms | 100% |
| large | parse_document | 13.57 ms / 4.45 ms | 35% | 6.25 ms / 5.09 ms | 85% |
| large | Document → HTML | 9.72 ms / 4.44 ms | 43% | 5.85 ms / 4.67 ms | 78% |

## Before and after, every row

"crashed": the row raised in the before run (see below). "skipped": not run, see [What's left](#whats-left).

### small (540 bytes)

| Row | before ips | after ips | change | before median | after median | before memory | after memory | before reductions | after reductions |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mdex_native markdown_to_html (comrak defaults) | 57,491 | 58,054 | 1.01x | 15.4 µs | 15.7 µs | 112 B | 112 B | 67 | 71 |
| mdex_native markdown_to_html | 50,782 | 46,993 | 0.93x | 17.6 µs | 20.1 µs | 688 B | 496 B | 121 | 142 |
| MDEx.to_html | 2,528 | 38,966 | 15.41x | 346.7 µs | 22.8 µs | 179.2 KB | 2.2 KB | 42,245 | 300 |
| mdex_native markdown_to_html + highlight | 5,395 | 5,795 | 1.07x | 158.5 µs | 155.2 µs | 856 B | 856 B | 675 | 712 |
| MDEx.to_html + highlight | 1,683 | 5,351 | 3.18x | 568.4 µs | 168.0 µs | 197.0 KB | 3.9 KB | 47,020 | 1,290 |
| mdex_native markdown_to_html + sanitize | 9,227 | 9,564 | 1.04x | 99.1 µs | 97.6 µs | 2.8 KB | 2.8 KB | 603 | 586 |
| MDEx.to_html + sanitize | 1,583 | 8,094 | 5.11x | 608.5 µs | 110.6 µs | 317.4 KB | 5.5 KB | 63,384 | 1,221 |
| mdex_native parse_document | 29,087 | 30,084 | 1.03x | 30.4 µs | 28.7 µs | 1016 B | 2.6 KB | 438 | 444 |
| MDEx.parse_document | 2,631 | 16,801 | 6.39x | 373.2 µs | 49.0 µs | 237.1 KB | 10.2 KB | 47,533 | 1,152 |
| mdex_native document_to_html | 28,870 | 29,808 | 1.03x | 31.5 µs | 31.1 µs | 1.9 KB | 1.9 KB | 181 | 181 |
| MDEx.to_html(document) | 2,443 | 19,888 | 8.14x | 385.7 µs | 45.9 µs | 224.2 KB | 11.1 KB | 47,675 | 1,324 |
| MDEx.stream + to_html each | 188 | 1,274 | 6.78x | 4.86 ms | 724.3 µs | 2.11 MB | 205.8 KB | 467,190 | 19,228 |
| ~MD sigil expansion (HTML) | 1,520 | 5,478 | 3.60x | 629.1 µs | 177.9 µs | 349.2 KB | 54.6 KB | 79,058 | 8,271 |
| cmark | 19,692 | 49,111 | 2.49x | 47.6 µs | 15.0 µs | 64 B | 64 B | 54 | 54 |
| md | 2,440 | 2,435 | 1.00x | 386.2 µs | 383.5 µs | 683.2 KB | 683.2 KB | 15,459 | 15,459 |
| earmark | 428 | 396 | 0.92x | 2.21 ms | 2.47 ms | 528.0 KB | 528.0 KB | 51,387 | 51,387 |
| erlang-markdown | 315 | 297 | 0.94x | 3.16 ms | 3.32 ms | 6.92 MB | 6.92 MB | 314,812 | 314,812 |

### medium (13,339 bytes)

| Row | before ips | after ips | change | before median | after median | before memory | after memory | before reductions | after reductions |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mdex_native markdown_to_html (comrak defaults) | 4,122 | 4,108 | 1.00x | 230.5 µs | 234.2 µs | 112 B | 112 B | 815 | 827 |
| mdex_native markdown_to_html | 3,934 | 4,034 | 1.03x | 238.6 µs | 241.0 µs | 688 B | 496 B | 869 | 902 |
| MDEx.to_html | 1,699 | 3,893 | 2.29x | 546.1 µs | 248.3 µs | 179.2 KB | 2.2 KB | 43,164 | 1,063 |
| mdex_native markdown_to_html + highlight | 281 | 282 | 1.00x | 3.29 ms | 3.45 ms | 856 B | 856 B | 13,463 | 13,788 |
| MDEx.to_html + highlight | 250 | 275 | 1.10x | 3.81 ms | 3.53 ms | 197.0 KB | 3.9 KB | 59,836 | 14,627 |
| mdex_native markdown_to_html + sanitize | 940 | 971 | 1.03x | 1.03 ms | 1.01 ms | 2.8 KB | 2.8 KB | 4,067 | 3,930 |
| MDEx.to_html + sanitize | 662 | 962 | 1.45x | 1.45 ms | 1.03 ms | 317.4 KB | 5.5 KB | 66,573 | 4,572 |
| mdex_native parse_document | 2,300 | 2,311 | 1.00x | 417.4 µs | 414.6 µs | 1016 B | 2.6 KB | 3,529 | 3,543 |
| MDEx.parse_document | 673 | 2,009 | 2.99x | 1.43 ms | 478.4 µs | 712.4 KB | 71.1 KB | 102,261 | 8,132 |
| mdex_native document_to_html | 2,626 | 2,693 | 1.03x | 360.9 µs | 355.8 µs | 21.5 KB | 21.5 KB | 1,329 | 1,365 |
| MDEx.to_html(document) | 766 | 2,055 | 2.68x | 1.18 ms | 459.2 µs | 701.6 KB | 73.1 KB | 100,070 | 8,901 |
| MDEx.stream + to_html each | 5.45 | 14 | 2.52x | 182.02 ms | 72.37 ms | 68.43 MB | 22.22 MB | 11,738,608 | 1,776,376 |
| ~MD sigil expansion (HTML) | 681 | 863 | 1.27x | 1.40 ms | 1.13 ms | 406.4 KB | 111.8 KB | 90,779 | 19,973 |
| cmark | 4,927 | 5,412 | 1.10x | 204.4 µs | 166.6 µs | 64 B | 64 B | 730 | 658 |
| md | 132 | 132 | 1.00x | 7.35 ms | 7.37 ms | 15.91 MB | 15.91 MB | 155,070 | 155,070 |
| earmark | 27 | 29 | 1.10x | 36.06 ms | 34.11 ms | 8.82 MB | 8.82 MB | 861,558 | 861,558 |
| erlang-markdown | 4.26 | 4.22 | 0.99x | 232.72 ms | 232.32 ms | 728.41 MB | 728.46 MB | 32,427,135 | 32,429,087 |

### large (205,025 bytes)

| Row | before ips | after ips | change | before median | after median | before memory | after memory | before reductions | after reductions |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mdex_native markdown_to_html (comrak defaults) | 253 | 231 | 0.91x | 3.87 ms | 4.23 ms | 112 B | 112 B | 15,262 | 16,602 |
| mdex_native markdown_to_html | 256 | 231 | 0.90x | 3.87 ms | 4.24 ms | 688 B | 496 B | 15,113 | 16,707 |
| MDEx.to_html | 201 | 229 | 1.14x | 4.65 ms | 4.24 ms | 179.2 KB | 2.2 KB | 58,665 | 17,038 |
| mdex_native markdown_to_html + highlight | 21 | 20 | 0.92x | 46.46 ms | 50.62 ms | 856 B | 856 B | 184,328 | 203,774 |
| MDEx.to_html + highlight | 19 | 20 | 1.08x | 52.54 ms | 49.63 ms | 197.0 KB | 3.9 KB | 237,452 | 195,705 |
| mdex_native markdown_to_html + sanitize | 71 | 79 | 1.11x | 12.88 ms | 12.54 ms | 2.8 KB | 2.8 KB | 50,363 | 50,031 |
| MDEx.to_html + sanitize | 67 | 79 | 1.17x | 14.15 ms | 12.62 ms | 317.4 KB | 5.5 KB | 116,263 | 51,316 |
| mdex_native parse_document | 208 | 186 | 0.90x | 4.45 ms | 5.09 ms | 1016 B | 2.6 KB | 21,627 | 25,940 |
| MDEx.parse_document | 73 | 159 | 2.16x | 13.57 ms | 6.25 ms | 5.42 MB | 766.9 KB | 686,151 | 76,303 |
| mdex_native document_to_html | 220 | 209 | 0.95x | 4.44 ms | 4.67 ms | 69.4 KB | 69.4 KB | 17,439 | 18,531 |
| MDEx.to_html(document) | 95 | 163 | 1.71x | 9.72 ms | 5.85 ms | 5.47 MB | 835.2 KB | 678,504 | 72,944 |
| MDEx.stream + to_html each | crashed | 0.03 | | | 32206.05 ms | | 4897.16 MB | | 2,756,135,559 |
| ~MD sigil expansion (HTML) | 108 | 131 | 1.21x | 9.19 ms | 7.43 ms | 1.18 MB | 916.5 KB | 148,154 | 80,489 |
| cmark | 307 | 271 | 0.88x | 3.17 ms | 3.40 ms | 64 B | 64 B | 12,335 | 13,263 |
| md | 6.87 | 6.90 | 1.00x | 131.99 ms | 126.24 ms | 243.34 MB | 243.34 MB | 3,688,052 | 3,686,380 |
| earmark | 1.65 | 1.70 | 1.03x | 600.86 ms | 589.76 ms | 214.76 MB | 214.76 MB | 22,791,605 | 22,779,921 |
| erlang-markdown | skipped | skipped | | | | | | | |

## What changed and its effect

All changes are in `e03df40` and were measured together; output and the public API are unchanged (full test suite passes, and the benchmark checks every MDEx/mdex_native pair renders the same HTML). Reductions are per call, from the tables above.

1. **Option schemas and defaults computed once.** `Document.rust_options!/1` called `default_options/0`, which ran `NimbleOptions.validate!([], schema)` on every render. With a keyword schema, NimbleOptions also re-validates the schema itself on every call. Schemas are now compiled with `NimbleOptions.new!/1` and defaults are module attributes. This was most of the fixed cost: `MDEx.to_html` on the small input went from 42,245 to 300 reductions and from 179.2 KB to 2.2 KB of heap.
2. **Native options merged as maps.** The defaults were merged into the document's options with nested `Keyword.merge/2`, which is quadratic, and then converted to maps anyway. Now the maps are merged directly. A scratch check compared the old and new function on 20,000 random option sets (repeated keys, `:unsafe`, the deprecated `:header_ids`) and found identical results; a new test pins those rules.
3. **Validation skips defaults.** `put_*_options/2` validate options but store them as given, so they now validate against schemas without `:default` entries. NimbleOptions no longer re-validates every default (the sanitize allowlists are hundreds of strings) on every call. Errors are the same; a new test checks the unknown-option message still lists every option. `sanitize: MDEx.default_sanitize_options()`, the documented way to turn sanitizing on, skips validation since the defaults are known to be valid. `MDEx.to_html + sanitize` on the small input: 63,384 → 1,221 reductions, 1,583 → 8,094 ips.
4. **AST conversion with one map update per node.** `MDEx.ComrakConverter` rebuilt every node with `Map.from_struct/1` and `struct/2`. Now a clause per node type swaps `__struct__` and converts `nodes`/`sourcepos`/`attrs` in a single map update when the node has exactly the fields of a target with the same fields (every node but the root). Other shapes, such as a NIF built against different structs, keep the old `struct/2` path. `MDEx.parse_document` on the large input: 686,151 → 76,303 reductions, 5.42 MB → 767 KB, 73 → 159 ips.
5. **Faster scans in `MDEx.FragmentParser`.** Streaming re-scans the buffered source on every chunk; counting `$` and finding the last `<` walked the source byte by byte in Elixir. They now use `:binary.matches/2`. A scratch check against the old functions on 200,000 random strings found identical results. This, with the changes above, took `MDEx.stream` on the medium input from 11.7 M to 1.8 M reductions and 5.45 to 14 ips.

Also fixed in this work, in its own commit (`8254b4d`): `MDEx.stream/2` raised `FunctionClauseError` in `MDEx.FragmentParser.closes_open_fence?/2` when an open fence contained a fence line it didn't close (`~~~` inside a backtick fence) or was closed by a fence with a different indent. The CommonMark spec has such fences, which is why the "before" run has no stream row for the large input.

### What's left

- **Small documents.** `MDEx.to_html` costs about 3 µs over the NIF call on the small input (22.8 vs 20.1 µs median). That's building the `MDEx.Document`, merging options, and trimming the output.
- **AST paths.** `MDEx.parse_document` and `MDEx.to_html(document)` are 76–87% of the engine on medium and large inputs. About half of that gap is converting nodes between `MDExNative.Comrak.*` and `MDEx.*` structs (see the follow-up below). The rest is likely the extra garbage from the second copy of the tree; that part wasn't measured on its own.
- **Streaming.** `MDEx.stream/2` re-parses the whole buffer for every chunk, by design, because later Markdown (such as a link reference definition) can change earlier blocks. Cost grows with the square of the document size: the 205 KB spec in 128-byte chunks is 1,602 chunks and takes 32.2 s per run, with 4,897 MB allocated on the BEAM heap. It's meant for chat-sized responses; the medium input (105 chunks) takes 72 ms.
- **~MD sigil.** Expansion is 3.6x faster on the small input, but compiling a module with `~MD` is dominated by the Elixir compiler and didn't change measurably.
- **erlang-markdown** was not run on the large input: one call took 100 s (measured once with `:timer.tc`).

## mdex_native follow-up

Not required: Markdown → HTML through MDEx is already at parity with the engine. The one remaining Elixir-side cost that only mdex_native can remove is the AST conversion, which matters to `MDEx.parse_document/2`, `MDEx.to_html/2` on a `MDEx.Document`, plugins and pipelines that work on the AST, and `MDEx.stream/2` (which parses on every chunk).

**What.** Let the NIF build and read `MDEx.*` node structs directly:

- `parse_document/2` gains an option such as `node_namespace: MDEx` (default `MDExNative.Comrak`), so the NIF builds `%MDEx.Heading{}` and friends instead of `%MDExNative.Comrak.Heading{}`. Every node except the root has the same fields in both namespaces today (`test/mdex/comrak_converter_test.exs` checks this).
- `document_to_html/2`, `document_to_xml/2`, and `document_to_commonmark/2` accept nodes from either namespace, by decoding the node kind from the module name's last segment, and accept a root that has extra fields (`%MDEx.Document{}` also carries options, pipeline steps, and other state).

**Why.** MDEx converts every node twice per parse-then-render: `MDEx.ComrakConverter.to_mdex/1` after `parse_document`, and `from_mdex/1` before `document_to_*`. After `e03df40` the conversion is a single map update per node, so this is the floor without NIF changes.

**Evidence.** Median of 60 runs on the same machine, `MIX_ENV=prod`, MDEx `e03df40`, mdex_native 0.3.1:

| Input | Nodes | native `parse_document` | `to_mdex` | native `document_to_html` | `from_mdex` |
|---|---:|---:|---:|---:|---:|
| small | 53 | 60 µs | 2 µs | 62 µs | 3 µs |
| medium | 538 | 422 µs | 36 µs | 433 µs | 38 µs |
| large | 6,465 | 4,876 µs | 489 µs | 4,889 µs | 501 µs |

Each conversion costs about 10% of the native call it wraps, and builds a full second copy of the tree.

**Expected effect.** In the "after" run, `MDEx.parse_document` on the large input takes 6.25 ms against 5.09 ms for the native call, and `MDEx.to_html(document)` 5.85 ms against 4.67 ms. Removing the conversion should cut about 0.5 ms from each of those 1.2 ms gaps, plus the garbage from the second tree, which wasn't measured separately. `MDEx.stream/2` would save one conversion per chunk. MDEx would keep `MDEx.ComrakConverter` as a fallback for older mdex_native versions.

## Numbers for the website

Positioning: **mdex_native is the engine** (raw speed, minimal API); **MDEx is the engine plus batteries** (Document AST, pipeline and plugins, sigils, streaming, syntax highlighting, sanitizing). The numbers should show that choosing MDEx doesn't cost speed: they used to suggest MDEx was about 17x slower (395 vs 6,561 ops/s on the old site), which was an artifact of per-call overhead that's now gone.

Use the **medium** input (MDEx's README, 13 KB) as the headline, because it's what most people render. Use ops/s from the "after" run and say they're from a 2-vCPU cloud VM; the old site's numbers came from a different machine and older versions, so don't put them side by side with these.

1. **Engine vs batteries, same options** (the headline): mdex_native `markdown_to_html` 4,034 ops/s (241 µs); `MDEx.to_html` 3,893 ops/s (248 µs). Message: MDEx is within a few percent of its own engine on a typical README, and identical on large documents (231 vs 229 ops/s on the 205 KB spec).
2. **Batteries, each with its engine equivalent**: syntax highlighting 275 ops/s (engine 282), sanitizing 962 ops/s (engine 971). Message: the features cost what the engine charges for them, nothing extra.
3. **MDEx-only features** (no engine row): `MDEx.parse_document` 2,009 ops/s and `MDEx.Document` → HTML 2,055 ops/s; `MDEx.stream/2` 14 ops/s for the whole README streamed in 128-byte chunks with every update rendered (about 72 ms total, or 0.7 ms per chunk); `~MD` costs nothing at runtime because it compiles to a string.
4. **Ecosystem comparison**, Markdown → HTML on the README: MDEx 3,893 ops/s, md 132, earmark 29, erlang-markdown 4.22. Show cmark (5,412 ops/s, a C NIF for CommonMark only) for honesty, or leave it out with a note; MDEx supports GFM and the extensions listed above, and cmark doesn't.

Don't publish the memory column for NIF rows (it doesn't include memory the NIF allocates), or the "comrak defaults" row as MDEx's speed (it's a different set of options).

## Reproduce

```sh
elixir benchmarks/benchmark.exs                  # or: elixir benchmark.exs
BENCH_INPUTS=small BENCH_ROWS="MDEx.to_html" BENCH_QUICK=1 elixir benchmarks/benchmark.exs
BENCH_PROFILE=tprof BENCH_ROWS="MDEx.parse_document" elixir benchmarks/benchmark.exs
```

`BENCH_OUTPUT` sets the JSON path (default `benchmarks/results.json`). Quick runs are for iterating; don't publish their numbers.
