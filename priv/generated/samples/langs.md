# Language Syntax Highlight Demo

## Elixir

```elixir
defmodule HelloModule do
  # A "Hello world" function
  def some_fun do
    IO.puts("Hello world!")
  end

  # This one works only with lists
  def some_fun(list) when is_list(list) do
    IO.inspect(list)
  end

  # A private function
  defp priv do
    :secret_info
  end
end
```

## Ruby

```ruby
module Notes
  attr  :concertA
  def tuning(amt)
    @concertA = 440.0 + amt
  end
end

class Trumpet
  include Notes
  def initialize(tune)
    tuning(tune)
    puts "Instance method returns #{concertA}"
    puts "Instance variable is #{@concertA}"
  end
end

# The piano is a little flat, so we'll match it
Trumpet.new(-5.3)
```

## Rust

```rust
struct User {
    active: bool,
    username: String,
    email: String,
    sign_in_count: u64,
}

fn main() {
    let user1 = User {
        active: true,
        username: String::from("someusername123"),
        email: String::from("someone@example.com"),
        sign_in_count: 1,
    };
}
```

## Swift

```swift
import SwiftUI

@main
struct DatePlannerApp: App {
    @StateObject private var eventData = EventData()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                EventList()
                Text("Select an Event")
                    .foregroundStyle(.secondary)
            }
            .environmentObject(eventData)
        }
    }
}
```

## Python

```python
from abc import ABC

class MyABC(ABC):
    pass

MyABC.register(tuple)

assert issubclass(tuple, MyABC)
assert isinstance((), MyABC)
```

## CSS

```css
/* At the top level of your code */
@media screen and (min-width: 900px) {
  article {
    padding: 1rem 3rem;
  }
}

/* Nested within another conditional at-rule */
@supports (display: flex) {
  @media screen and (min-width: 900px) {
    article {
      display: flex;
    }
  }
}
```

## JavaScript (WIP)

```js
const bigDay = new Date(2019, 6, 19);
console.log(bigDay.toLocaleDateString());
if (bigDay.getTime() < Date.now()) {
  console.log("Once upon a time...");
}
```
