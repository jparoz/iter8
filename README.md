# iter8

**iter8** is a lazy iterator library for Lua 5.1+ and LuaJIT, heavily inspired by
[Rust's iterators](https://doc.rust-lang.org/std/iter/).

Iterators are first-class objects: you can chain, transform, and consume them
without evaluating until you actually need the values.

## Example

```lua
local Iter8 = require "iter8"

-- Sum the squares of the first 10 integers
local result = Iter8.range(10)
    :map(function(n) return n * n end)
    :sum()
-- result == 385

-- Collect every other word from a string
local words = Iter8.gmatch("a b c d e f", "%S+")
    :step_by(2)
    :collect()
-- words == {"a", "c", "e"}

-- Slide a 3-element window over a list
Iter8.ivalues({1, 2, 3, 4, 5})
    :windows(3)
    :foreach(function(w) print(table.concat(w, ", ")) end)
-- 1, 2, 3
-- 2, 3, 4
-- 3, 4, 5
```

## Installation

Copy `iter8.lua` into your project.

### Semver

iter8 follows [Semantic Versioning](https://semver.org/).
The current version is **0.1.0** — the API may change before 1.0.

## Documentation

Full API reference: <https://jparoz.github.io/iter8/>

## Contributing

Pull requests and issues are welcome.

### Running the test suite

Requires [busted](https://lunarmodules.github.io/busted/):

```
luarocks install busted
busted spec/
```

### Building the documentation

Requires [uv](https://docs.astral.sh/uv/):

```
uv run python docs/extract.py   # regenerate docs/api.md from source
uv run mkdocs serve             # preview at http://localhost:8000
```
