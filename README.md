# lua-iter

A functional-style iterator library for Lua, inspired by Rust's iterators.

It provides a `Chiterator` object that allows for chaining iterator transformations.

## Features

*   Chainable iterator adapters (`map`, `filter`, `take`, etc.).
*   Consuming iterators into collections (`collect`, `fold`).
*   Works with standard Lua iterators.
*   Lazy evaluation.

## Usage

```lua
local Chiterator = require 'iter.chiterator'

-- Find the first 5 even square numbers
local result = Chiterator.counter()
    :map(function(i) return i * i end)
    :filter(function(n) return n % 2 == 0 end)
    :take(5)
    :fold({}, function(acc, val)
        acc[#acc+1] = val
        return acc
    end)

-- result is {4, 16, 36, 64, 100}
for i, v in ipairs(result) do
  print(i, v)
end
```

## API

The main entry point is `iter.chiterator`.

### Chiterator

A chainable iterator object.

#### Creation

*   `Chiterator(iter, state, control, ...)`: Wraps an existing iterator.
*   `Chiterator.counter()`: Creates an infinite iterator that counts up from 1.
*   `Chiterator.coro(func, ...)`: Creates an iterator from a coroutine.

#### Adapters (chainable)

*   `:map(func)`
*   `:filter(func)`
*   `:take(n)`
*   `:take_while(predicate)`
*   `:skip(n)`
*   `:skip_while(predicate)`
*   `:enumerate()`
*   `:zip(...)`
*   `:chain(...)`

#### Consumers (ends the chain)

*   `:fold(init, func)`
*   `:reduce(func)`
*   `:collect()`
*   `:count()`
*   `:all(predicate)`
*   `:any(predicate)`
*   `:iter()`: Returns the raw iterator components.
