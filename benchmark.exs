# The benchmark lives in benchmarks/benchmark.exs (inputs and results are in
# benchmarks/ too). This file runs it from the repository root:
#
#     elixir benchmark.exs
#
Code.eval_file(Path.join([__DIR__, "benchmarks", "benchmark.exs"]))
