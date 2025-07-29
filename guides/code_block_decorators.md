Code block decorators allow you to customize the appearance and behavior of individual code blocks by adding special attributes to the info string (the part after the opening backticks).

### Prerequisites

To use code block decorators, you must enable both `:render` options:

```elixir
render: [
  github_pre_lang: true,
  full_info_string: true
]
```

### Available Decorators

| Decorator | Description | Supported Formatters | Example |
|-----------|-------------|---------------------|---------|
| `theme` | Override the syntax highlighting theme | All | `theme=github_dark` |
| `pre_class` | Add custom CSS classes to `<pre>` element | All | `pre_class="my-class"` |
| `highlight_lines` | Highlight single and/or range of lines | All | `highlight_lines="1,3-5"` |
| `highlight_lines_style` | Custom inline styles for highlighted lines | HTML inline only | `highlight_lines_style="background: yellow"` |
| `highlight_lines_class` | Custom CSS class for highlighted lines | All | `highlight_lines_class="emphasis"` |
| `include_highlights` | Add syntax token names as data attributes | All | `include_highlights` |

### Examples

_Following examples assume `render: [github_pre_lang: true, full_info_string: true]` is set._

#### Override Theme

Change the syntax highlighting theme for a specific code block:

````md
```elixir theme=github_dark
def hello do
  "Hello, world!"
end
```
````

Output: `<pre class="athl" style="color: #c9d1d9; background-color: #0d1117;">...`

#### Add Custom CSS Classes

Add your own CSS classes to the `<pre>` element:

````md
```javascript pre_class="code-example interactive"
console.log("Hello!");
```
````

Output: `<pre class="athl code-example interactive">...`

#### Highlight Specific Lines

Highlight individual lines or ranges (inclusive):

````md
# Highlight lines 1, 4, 5, and 6

```python highlight_lines="1,4-6"
import math

def calculate(x):
    result = x * 2
    # return calculated result
    return math.sqrt(x)
```
````

With `:html_inline` formatter, lines get styles from the theme's highlight color, for eg:

```html
<span style="background-color: #dae9f9;" data-line="1">...
```

With `:html_linked` formatter, the class `highlighted` is added to the highlighted lines, for eg:

```html
<span class="line highlighted" data-line="1">...
```

#### Custom Highlight Styling

Use either `highlight_lines_style` or `highlight_lines_class` to customize the appearance of highlighted lines:

````md
```ruby highlight_lines="2" highlight_lines_style="background: #ffeb3b; font-weight: bold;"
class User
  def initialize(name)
    @name = name
  end
end
```
````

#### Include Syntax Token Information

Add syntax token names in `data-highlight` attributes, useful for debugging or custom styling:

````md
```rust include_highlights
let x: i32 = 42;
```
````

Output: `<span data-highlight="keyword">let</span>`

#### Combine Multiple Decorators

Use multiple decorators together:

````md
```typescript theme=github_light pre_class="example" highlight_lines="2-3" include_highlights
interface User {
  name: string;    // highlighted
  email: string;   // highlighted
  age?: number;
}
```
````

### Important Notes

1. **Formatter Support**: Not all decorators work with all formatters:
   - `highlight_lines_style` only works with `:html_inline` formatter
   - `theme` only works with `:html_inline` formatter

2. **CSS Classes**: The `athl` class is always added to `<pre>` elements when using syntax highlighting

3. **Line Numbers**: The `data-line` attribute is added to each line for reference

4. **Order**: It's expected the first word of the code fence info string to be the language name, followed by decorators.
   - For example, `elixir theme=github_dark` is valid, but `theme=github_dark elixir` is not.

5. **Performance**: Decorators are processed at render time, so using many decorators may impact performance
