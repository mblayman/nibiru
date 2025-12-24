# Pretty Printing

Nibiru provides a built-in table pretty printer for debugging and development purposes, eliminating the need for third-party libraries.

## Usage

```lua
local pp = require("nibiru.pp")

local my_table = {
    name = "example",
    data = {1, 2, 3},
    nested = {
        key = "value"
    }
}

pp(my_table)
```

This will output:

```
{
    name = "example"
    data =
    {
        [1] = 1
        [2] = 2
        [3] = 3
    }
    nested =
    {
        key = "value"
    }
}
```

## Features

- Formats tables with 4-space indentation for readability
- Handles nested tables recursively with proper structure
- Detects and marks circular references to prevent infinite loops
- Uses clean syntax for string keys that are valid identifiers
- Uses bracket notation for numeric keys and complex key types
- Returns a string, allowing for testing and flexible output handling

## API

- `pp(table)`: Takes a table and prints to stdout. `pp` also returns the output
  as a string.
