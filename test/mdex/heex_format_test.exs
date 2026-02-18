defmodule MDEx.HeexFormatTest do
  use ExUnit.Case

  @opts [
    extension: [phoenix_heex: true],
    render: [unsafe: true]
  ]

  def assert_format(document) do
    assert_format(document, document)
  end

  def assert_format(document, expected) do
    assert {:ok, doc} = MDEx.parse_document(document, @opts)
    assert {:ok, html} = MDEx.to_html(doc, @opts)

    assert html == String.trim(expected)
  end

  describe "function components" do
    test "self-closing" do
      assert_format("<.button text=\"Save\" />\n")
    end

    test "nested different names" do
      assert_format("""
      <.form>
        <.input field={@form[:name]} />
      </.form>
      """)
    end

    test "nested same name" do
      assert_format("""
      <.list>
        <.li>
          content
          <.list>
            <.li>nested</.li>
          </.list>
        </.li>
      </.list>
      """)
    end
  end

  describe "module components" do
    test "self-closing" do
      assert_format("<MyComponent.btn text=\"Save\" />\n")
    end

    test "with content" do
      assert_format("""
      <Root.render>
        <Grid>
          <Card />
        </Card>
      </Root.render>
      """)
    end

    test "nested same name" do
      assert_format("""
      <MyApp.List.list>
        <MyApp.List.li>
          content
          <MyApp.List.list>
            <MyApp.List.li>nested</MyApp.List.li>
          </MyApp.List.list>
        </MyApp.List.li>
      </MyApp.List.list>
      """)
    end

    test "long module names" do
      assert_format("""
      <MishkaWeb.Components.List.list variant="transparent">
        <MishkaWeb.Components.List.li padding="small">
          First item
          <MishkaWeb.Components.List.list variant="transparent">
            <MishkaWeb.Components.List.li>nested item</MishkaWeb.Components.List.li>
          </MishkaWeb.Components.List.list>
        </MishkaWeb.Components.List.li>
      </MishkaWeb.Components.List.list>
      """)
    end
  end

  describe "slots" do
    test "with content" do
      assert_format("""
      <Component>
        <:subtitle>
          Subtitle content
        </:subtitle>
        <:actions>
          Action buttons
        </:actions>
      </Component>
      """)
    end
  end

  describe "directives" do
    test "inline expression" do
      assert_format("<%= @value %>\n")
    end

    test "block directive" do
      assert_format("""
      <.form>
        <%= if true do %>
          <%= @value %>
        <% end %>
      </.form>
      """)
    end

    test "comment" do
      assert_format("""
      <%!-- a comment --%>
      """)
    end
  end

  describe "expressions" do
    test "block expression" do
      assert_format("""
      {if true do}
        <.button>Click</.button>
      {end}
      """)
    end
  end

  describe "mixed content" do
    test "markdown with heex components" do
      assert_format(
        """
        # Title

        <.link href="/">Home</.link>

        Some **bold** text.
        """,
        """
        <h1>Title</h1>
        <.link href="/">Home</.link>
        <p>Some <strong>bold</strong> text.</p>
        """
      )
    end

    test "headings around components" do
      assert_format(
        """
        # Title

        <.alert>Warning</.alert>

        ## Subtitle

        <.card>Content</.card>

        ### Section
        """,
        """
        <h1>Title</h1>
        <.alert>Warning</.alert>
        <h2>Subtitle</h2>
        <.card>Content</.card>
        <h3>Section</h3>
        """
      )
    end

    test "paragraphs with inline formatting around components" do
      assert_format(
        """
        Some **bold** and *italic* text.

        <.component>
          inner content
        </.component>

        Another paragraph with `code` and [link](https://example.com).
        """,
        """
        <p>Some <strong>bold</strong> and <em>italic</em> text.</p>
        <.component>
          inner content
        </.component>
        <p>Another paragraph with <code>code</code> and <a href="https://example.com">link</a>.</p>
        """
      )
    end

    test "lists and components" do
      assert_format(
        """
        - item one
        - item two

        <.card>
          Card content
        </.card>

        1. first
        2. second
        """,
        """
        <ul>
        <li>item one</li>
        <li>item two</li>
        </ul>
        <.card>
          Card content
        </.card>
        <ol>
        <li>first</li>
        <li>second</li>
        </ol>
        """
      )
    end

    test "blockquote and components" do
      assert_format(
        """
        > A wise quote

        <.callout type="info">
          Important note
        </.callout>

        > Another quote
        """,
        """
        <blockquote>
        <p>A wise quote</p>
        </blockquote>
        <.callout type="info">
          Important note
        </.callout>
        <blockquote>
        <p>Another quote</p>
        </blockquote>
        """
      )
    end

    test "self-closing component between paragraphs" do
      assert_format(
        """
        First paragraph.

        <.divider />

        Second paragraph.
        """,
        """
        <p>First paragraph.</p>
        <.divider />
        <p>Second paragraph.</p>
        """
      )
    end

    test "markdown syntax inside component stays raw" do
      assert_format("""
      <.raw>
        # Not a heading
        **not bold**
        - not a list
      </.raw>
      """)
    end

    test "horizontal rules and components" do
      assert_format(
        """
        Above the line.

        ---

        <.section>Middle</.section>

        ---

        Below the line.
        """,
        """
        <p>Above the line.</p>
        <hr />
        <.section>Middle</.section>
        <hr />
        <p>Below the line.</p>
        """
      )
    end

    test "nested same-name components with markdown around" do
      assert_format(
        """
        # Header

        <MyApp.List.list>
          <MyApp.List.li>
            content
            <MyApp.List.list>
              <MyApp.List.li>nested</MyApp.List.li>
            </MyApp.List.list>
          </MyApp.List.li>
        </MyApp.List.list>

        Some **closing** thoughts.
        """,
        """
        <h1>Header</h1>
        <MyApp.List.list>
          <MyApp.List.li>
            content
            <MyApp.List.list>
              <MyApp.List.li>nested</MyApp.List.li>
            </MyApp.List.list>
          </MyApp.List.li>
        </MyApp.List.list>
        <p>Some <strong>closing</strong> thoughts.</p>
        """
      )
    end

    test "image and components" do
      assert_format(
        """
        ![Alt text](image.png)

        <.figure>
          <img src="photo.jpg" />
          <figcaption>A photo</figcaption>
        </.figure>

        More text after.
        """,
        """
        <p><img src="image.png" alt="Alt text" /></p>
        <.figure>
          <img src="photo.jpg" />
          <figcaption>A photo</figcaption>
        </.figure>
        <p>More text after.</p>
        """
      )
    end
  end

  describe "nesting edge cases" do
    test "self-closing same-name inside block" do
      assert_format("""
      <MyApp.List.list>
        <MyApp.List.list />
      </MyApp.List.list>
      """)
    end

    test "inline open and close same-name inside block" do
      assert_format("""
      <.list>
        <.list>inner</.list>
      </.list>
      """)
    end

    test "sequential same-name blocks" do
      assert_format(
        """
        <.list>
          first
        </.list>

        <.list>
          second
        </.list>
        """,
        """
        <.list>
          first
        </.list>
        <.list>
          second
        </.list>
        """
      )
    end

    test "sibling same-name modals with nested forms" do
      assert_format(
        """
        <.modal id="rename-modal">
          <.form for={@rename_form} phx-submit="rename">
            <.input field={@rename_form[:name]} />
            <.button type="submit">Rename</.button>
          </.form>
        </.modal>

        <.modal id="delete-modal">
          <.form for={@delete_form} phx-submit="delete">
            <.input field={@delete_form[:name]} />
            <.button type="submit">Delete</.button>
          </.form>
        </.modal>
        """,
        """
        <.modal id="rename-modal">
          <.form for={@rename_form} phx-submit="rename">
            <.input field={@rename_form[:name]} />
            <.button type="submit">Rename</.button>
          </.form>
        </.modal>
        <.modal id="delete-modal">
          <.form for={@delete_form} phx-submit="delete">
            <.input field={@delete_form[:name]} />
            <.button type="submit">Delete</.button>
          </.form>
        </.modal>
        """
      )
    end

    test "sibling same-name dropdowns" do
      assert_format("""
      <.card>
        <.dropdown id="app-dropdown" label="App">
          <.dropdown_item value="a" label="A" />
          <.dropdown_item value="b" label="B" />
        </.dropdown>
        <.dropdown id="branch-dropdown" label="Branch">
          <.dropdown_item value="main" label="main" />
        </.dropdown>
        <.dropdown id="type-dropdown" label="Type">
          <.dropdown_item value="any" label="Any" />
        </.dropdown>
      </.card>
      """)
    end

    test "same-name accordion items with slots" do
      assert_format("""
      <.accordion>
        <.accordion_item>
          <:header>Question 1</:header>
          <:panel>Answer 1</:panel>
        </.accordion_item>
        <.accordion_item>
          <:header>Question 2</:header>
          <:panel>Answer 2</:panel>
        </.accordion_item>
        <.accordion_item>
          <:header>Question 3</:header>
          <:panel>Answer 3</:panel>
        </.accordion_item>
      </.accordion>
      """)
    end

    test "sibling inputs_for blocks inside form" do
      assert_format("""
      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.inputs_for :let={creds} field={@form[:credentials]}>
          <.input field={creds[:username]} type="text" label="Username" />
          <.input field={creds[:password]} type="password" label="Password" />
        </.inputs_for>
        <.inputs_for :let={config} field={@form[:stream_config]}>
          <.input field={config[:stream_uri]} type="text" label="URI" />
        </.inputs_for>
      </.simple_form>
      """)
    end

    test "form with case directive and multiple branches" do
      assert_format("""
      <.form for={@changeset} phx-submit="save">
        <.input field={@changeset[:name]} />
        <%= case @step do %>
          <% :first -> %>
            <.input field={@changeset[:email]} />
          <% :second -> %>
            <.input field={@changeset[:phone]} />
        <% end %>
        <.button type="submit">Save</.button>
      </.form>
      """)
    end

    test "deeply nested component tree" do
      assert_format("""
      <.card>
        <.form for={@form} phx-submit="save">
          <.modal id="confirm">
            <:footer>
              <.modal_footer>
                <:action>
                  <.button type="submit">Confirm</.button>
                </:action>
              </.modal_footer>
            </:footer>
          </.modal>
        </.form>
      </.card>
      """)
    end

    test "dropdown with if/else directive inside" do
      assert_format("""
      <.dropdown>
        <%= if @role == :owner do %>
          <.dropdown_item disabled={true}>Owner</.dropdown_item>
        <% else %>
          <.dropdown_item>Editor</.dropdown_item>
          <.dropdown_item>Viewer</.dropdown_item>
        <% end %>
      </.dropdown>
      """)
    end

    test "module component inside function component" do
      assert_format("""
      <.form_item field={@form[:upload_dir]} label="Upload directory">
        <Input.input field={@form[:upload_dir]} placeholder="/public/assets" />
      </.form_item>
      <.form_item field={@form[:serve_at]} label="Serve at">
        <Input.input field={@form[:serve_at]} placeholder="/static" />
      </.form_item>
      """)
    end

    test "for comprehension with same-name components" do
      assert_format("""
      <.dropdown id="app-dropdown" label="App">
        <%= for app <- @apps do %>
          <.dropdown_item value={app} label={app} />
        <% end %>
      </.dropdown>
      """)
    end

    test "component with :if directive" do
      assert_format("""
      <.alert :if={@show} status="error">
        Something went wrong
      </.alert>
      """)
    end

    test "component with :for directive" do
      assert_format("""
      <.item :for={item <- @items} value={item}>
        <%= item %>
      </.item>
      """)
    end

    test "component with spread attributes" do
      assert_format("""
      <.button {@rest} class={@class}>
        Click
      </.button>
      """)
    end

    test "multiple same-name slot entries" do
      assert_format("""
      <.table rows={@users}>
        <:col :let={user} label="Name"><%= user.name %></:col>
        <:col :let={user} label="Email"><%= user.email %></:col>
        <:action :let={user}>
          <.link href={"/users/\#{user}"}>Show</.link>
        </:action>
        <:action :let={user}>
          <.link href={"/users/\#{user}/edit"}>Edit</.link>
        </:action>
      </.table>
      """)
    end

    test "default slot mixed with named slots" do
      assert_format("""
      <.component>
        top content
        <:header>The header</:header>
        middle content
        <:footer>The footer</:footer>
        bottom content
      </.component>
      """)
    end

    test "html comments inside component" do
      assert_format("""
      <.card>
        <!-- visible comment -->
        <.button>Click</.button>
      </.card>
      """)
    end
  end
end
