# iter8

Iter8 is a small Lua library
which provides an iterator object.
The library is heavily inspired by [Rust's iterators].

[Rust's iterators]: https://doc.rust-lang.org/std/iter/

## Example
```lua
local Iter8 = require "iter8"

for c, n in Iter8.chars("hello"):zip(Iter8.range(5)) do
    print(c .. " is letter number " .. tostring(n))
end

-- Print the primes up to 100
Iter8.range(100):filter(isPrime):foreach(print)
```

## Installation
TODO

### Semver
TODO

## Documentation
TODO

## Contributing
TODO

### Running the test suite
TODO

### Building the documentation
TODO
