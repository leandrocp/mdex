defmodule MDEx.InspectTreeTest do
  use ExUnit.Case, async: false
  import MDEx.Sigil

  describe "Inspect protocol" do
    test "inspect with :struct format" do
      Application.put_env(:mdex, :inspect_format, :struct)

      on_exit(fn ->
        Application.put_env(:mdex, :inspect_format, :tree)
      end)

      assert inspect(~MD[# Test]) =~ "%MDEx.Document{"
    end

    test "inspect with :tree format" do
      Application.put_env(:mdex, :inspect_format, :tree)
      assert inspect(~MD[# Test]) =~ "#MDEx.Document(2 nodes)"
    end
  end
end

