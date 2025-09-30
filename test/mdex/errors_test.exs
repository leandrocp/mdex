defmodule MDEx.ErrorsTest do
  use ExUnit.Case, async: true

  describe "InvalidInputError" do
    test "raises with custom message" do
      error = %MDEx.InvalidInputError{found: :invalid}

      assert Exception.message(error) =~ "expected either a Markdown string or a MDEx.Document struct"
      assert Exception.message(error) =~ ":invalid"
    end
  end

  describe "InvalidSelector" do
    test "raises with custom message" do
      error = %MDEx.InvalidSelector{selector: :bad_selector}

      assert Exception.message(error) =~ "invalid Access key selector"
      assert Exception.message(error) =~ ":bad_selector"
    end
  end
end
