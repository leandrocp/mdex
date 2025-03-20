defmodule MDEx.Pipe do
  @moduledoc """
  MDEx.Pipe is a Req-like API to transform Markdown documents.

  In short, plugins:

      mdex = MDEx.new() |> MDExMermaid.attach(version: "11")

      MDEx.to_html(mdex, markdown: ~s|
      # Project Diagram

      \`\`\`mermaid
      graph TD
          A[Enter Chart Definition] --> B(Preview)
          B --> C{decide}
          C --> D[Keep]
          C --> E[Edit Definition]
          E --> B
          D --> F[Save Image and Code]
          F --> B
      \`\`\`
      |)

  So let's write the MermaidJS plugin as example:

  ## Writing plugins


  
  """

  defstruct document: nil

  @type t :: %__MODULE__{
          document: MDEx.Types.Document.t
        }


  @doc false
  def new(opts) do
    %__MODULE__{}
  end
end
