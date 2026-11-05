defmodule MDEx.UsageRulesTest do
  use ExUnit.Case, async: true

  test "usage-rules.md is skills/mdex/SKILL.md without its frontmatter" do
    [_, _frontmatter, body] = String.split(File.read!("skills/mdex/SKILL.md"), ~r/^---$/m, parts: 3)

    assert File.read!("usage-rules.md") == String.trim_leading(body),
           "usage-rules.md is out of sync with skills/mdex/SKILL.md, run `mise run sync-usage-rules`"
  end
end
