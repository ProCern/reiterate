# reiterate

A functional-style iterator library for Lua, inspired by Rust's iterators.

It provides a `Chiterator` object that allows for chaining iterator transformations.

## Principles

This library is written to be as thin and modular as possible.  Most adapters
take a Lua iterator (i.e. a function, state, cv, closeable set) and return
the same.  They don't try to encapsulate things like the state and cv within
themselves where they don't need to.  If they can operate on the same CV as the
iterator they wrap (like `take` and `skip`) then they will do so, and not keep
the CV within themselves.  If they can't (such as `enumerate`, which changes the
CV), only then will they take the CV into themselves.

Even if they do take the CV into themselves, they often return a function,
state, and CV as separate components that are needed for iteration, matching Lua
semantics as closely as possible.

This extends to `Chiterator`, which, when used as an iterator directly, will use
the `for` loop's CV and even state.  It takes the CV and state into itself, but
these are only used for chaining.

This means that you can't simply assign an iterator or `Chiterator` to a
variable and use it. Like Lua iterators, if you want to store them as a
variable, you must `table.pack` and `table.unpack` them:

```lua
local counter = require 'reiterate.counter'
local take = require 'reiterate.take'
local stored_counter = table.pack(counter())
for i in take(5, table.unpack(stored_counter, 1, stored_counter.n)) do
    -- Operate on iterator here
end
```

Yes, this is unwieldy.  I don't like this, but I consider it more important to
align to Lua's semantics than to present an ideal interface that doesn't conform
to the language or work with other Lua-native iterators.

## Features

*   Chainable iterator adapters (`map`, `filter`, `take`, etc.).
*   Consuming iterators into collections (`collect`, `fold`).
*   Works with standard Lua iterators.
*   Lazy evaluation.

## Usage

```lua
local Chiterator = require 'reiterate.chiterator'

-- Find the first 5 even square numbers
local result =
    Chiterator.counter()
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

-- The same as the above, but less efficient.
-- This demonstrates lazy evaluation, as it will check every even number
-- until it finds 5 that are also square numbers.
local function is_square(n)
  local root = math.sqrt(n)
  return root == math.floor(root)
end

local result =
    Chiterator.counter()
    :zip(
        Chiterator.counter()
        :filter(is_square)
        :filter(function(n) return n % 2 == 0 end)
    )
    :take(5)
    :map(function(i, s) return i[1], s[1] end)
    :collect()

-- result is {4, 16, 36, 64, 100}
for i, v in ipairs(result) do
  print(i, v)
end
```

## API

All modules under `reiterate` are considered public API. While `reiterate.chiterator` is a common entry point for method chaining, each iterator function can be used on its own.

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

### Standalone Iterator Functions

The following modules provide iterator functions that can be used directly with Lua's `for` loop:

*   `reiterate.all(predicate, ...)`
*   `reiterate.any(predicate, ...)`
*   `reiterate.chain(...)`
*   `reiterate.collect(...)`
*   `reiterate.coro(func, ...)`
*   `reiterate.count(...)`
*   `reiterate.counter()`
*   `reiterate.enumerate(...)`
*   `reiterate.filter(func, ...)`
*   `reiterate.fold(init, func, ...)`
*   `reiterate.map(func, ...)`
*   `reiterate.once(...)`
*   `reiterate.reduce(func, ...)`
*   `reiterate.skip(n, ...)`
*   `reiterate.skip_while(predicate, ...)`
*   `reiterate.take(n, ...)`
*   `reiterate.take_while(predicate, ...)`
*   `reiterate.zip(...)`
