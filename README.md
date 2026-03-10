# reiterate

A functional-style iterator library for Lua 5.4+, inspired by Rust's iterators.

It provides standalone iterator adapter functions that work directly with Lua's
`for` loop, and a `Chiterator` object that allows chaining them together.

## Install

```
luarocks install reiterate
```

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

You can require individual modules (`require 'reiterate.map'`), the chainable
interface (`require 'reiterate.chiterator'`), or everything at once:

```lua
local iter = require 'reiterate'

-- All submodules are available as fields:
-- iter.map, iter.filter, iter.take, iter.chiterator, etc.

for i in iter.take(3, iter.counter()) do
    print(i)
end
```

## Quick Start

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
```

The same thing using standalone functions:

```lua
local counter = require 'reiterate.counter'
local map = require 'reiterate.map'
local filter = require 'reiterate.filter'
local take = require 'reiterate.take'
local fold = require 'reiterate.fold'

local result = fold({}, function(acc, val)
    acc[#acc+1] = val
    return acc
end,
    take(5,
        filter(function(n) return n % 2 == 0 end,
            map(function(i) return i * i end,
                counter()))))
```

### Lazy Evaluation

All adapters are lazy -- they don't consume elements until something drives
iteration (a `for` loop or a consumer like `fold`).  This means you can compose
transformations over infinite iterators and only pull what you need:

```lua
local Chiterator = require 'reiterate.chiterator'

local function is_square(n)
  local root = math.sqrt(n)
  return root == math.floor(root)
end

-- Zip a plain counter with an infinite stream of even squares,
-- then take only the first 5 pairs.
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
```

## API

All modules under `reiterate` are considered public API.  `reiterate.chiterator`
is the main entry point for method chaining, but every iterator function can
also be used standalone.

In the signatures below, `...` after a standalone function's own parameters
represents the iterator tuple `(iter, state, control [, closeable])`, i.e. the
return values of another iterator constructor or of `ipairs`/`pairs`.

---

### Chiterator

A chainable iterator object.

```lua
local Chiterator = require 'reiterate.chiterator'
```

#### `Chiterator(iter, state, control, ...)`

Wraps an existing Lua iterator into a `Chiterator`.  The extra return values
(e.g. a to-be-closed value) are passed through.

```lua
local ch = Chiterator(ipairs{'a', 'b', 'c'})
for i, v in ch do print(i, v) end
-- 1  a
-- 2  b
-- 3  c
```

#### `Chiterator.counter()`

Creates an infinite iterator that yields successive integers starting from 1.

```lua
for i in Chiterator.counter():take(3) do
    print(i)
end
-- 1
-- 2
-- 3
```

#### `Chiterator.coro(func, ...)`

Creates an iterator from a coroutine or function.  Each `coroutine.yield()`
(and the final return) produces one iteration.  Extra arguments are passed to
the first resume.

```lua
local ch = Chiterator.coro(function(start)
    for i = start, start + 2 do
        coroutine.yield(i, i * 10)
    end
end, 5)

for a, b in ch do print(a, b) end
-- 5   50
-- 6   60
-- 7   70
```

#### `:iter()`

Extracts the raw iterator components `(iter, state, control, ...)` from the
`Chiterator`.  Useful when you need to pass the iterator to a standalone
function or store it.

```lua
local iter, state, control = Chiterator.counter():take(3):iter()
```

---

### Adapters (chainable)

Adapters return a new `Chiterator`.  They are lazy -- no iteration happens until
the chain is consumed.

#### `:map(func)`

Transforms each iteration's values through `func`.  If `func` returns `nil` as
its first value, that iteration is skipped (flat-map / filter-map behavior).

```lua
Chiterator(ipairs{1, 2, 3})
    :map(function(i, v) return i, v * 10 end)
    :collect()
-- {10, 20, 30}

-- Returning nil skips the element:
Chiterator.counter():take(6)
    :map(function(n)
        if n % 2 == 0 then return n end
        -- odd numbers return nil and are skipped
    end)
    :enumerate():collect()
-- {2, 4, 6}
```

#### `:filter(func)`

Keeps only iterations where `func(...)` returns a truthy value.  Implemented
via `map`, so it has the same lazy skip behavior.

```lua
Chiterator.counter():take(10)
    :filter(function(n) return n % 3 == 0 end)
    :enumerate():collect()
-- {3, 6, 9}
```

#### `:take(n)`

Yields at most the first `n` iterations, then stops.

```lua
Chiterator.counter():take(3):enumerate():collect()
-- {1, 2, 3}
```

#### `:take_while(predicate)`

Yields iterations while `predicate(...)` returns true.  Stops permanently on
the first false.

```lua
Chiterator.counter()
    :take_while(function(i) return i < 4 end)
    :enumerate():collect()
-- {1, 2, 3}
```

#### `:skip(n)`

Immediately consumes and discards the first `n` iterations, then yields the
rest.  Unlike most adapters, this is eager -- the skipped elements are consumed
at construction time, not when iteration begins.

```lua
Chiterator.counter():skip(3):take(3):enumerate():collect()
-- {4, 5, 6}
```

#### `:skip_while(predicate)`

Consumes and discards iterations while `predicate(...)` returns true, then
yields all remaining iterations (even if later ones would match the predicate
again).

```lua
Chiterator.counter()
    :skip_while(function(i) return i < 15 end)
    :take_while(function(i) return i < 20 end)
    :enumerate():collect()
-- {15, 16, 17, 18, 19}
```

#### `:enumerate()`

Prepends a 1-based counter to each iteration's values.

```lua
Chiterator(ipairs{'a', 'b', 'c'})
    :map(function(_, v) return v end)
    :enumerate()
    :collect()
-- {[1] = 'a', [2] = 'b', [3] = 'c'}
```

#### `:zip(...)`

Combines this iterator with one or more other iterators, yielding one
`table.pack`'d value set from each on every iteration.  Stops as soon as any
iterator is exhausted.

Each argument should be a `Chiterator` (which is auto-packed) or a packed
iterator table.

```lua
local letters = Chiterator(ipairs{'a', 'b', 'c'})
    :map(function(_, v) return v end)

Chiterator.counter()
    :zip(letters)
    :take(3)
    :map(function(nums, strs) return nums[1], strs[1] end)
    :collect()
-- {[1] = 'a', [2] = 'b', [3] = 'c'}
```

#### `:chain(...)`

Concatenates this iterator with one or more other iterators, yielding all
elements from each in sequence.

Each argument should be a `Chiterator` (which is auto-packed) or a packed
iterator table.

```lua
Chiterator(once(1))
    :chain(once(2))
    :chain(once(3))
    :enumerate():collect()
-- {1, 2, 3}
```

---

### Consumers (end the chain)

Consumers drive iteration to completion and return a result.

#### `:fold(init, func)`

Reduces the iterator into a single accumulated value.  Calls
`func(accumulator, ...)` on each iteration, where `...` are the iteration's
values.  Returns the final accumulator.

```lua
Chiterator.counter():take(5)
    :fold(0, function(sum, n) return sum + n end)
-- 15

Chiterator.counter():take(5)
    :fold({}, function(acc, n)
        acc[10 - n] = n * n
        return acc
    end)
-- {[9]=1, [8]=4, [7]=9, [6]=16, [5]=25}
```

#### `:reduce(func)`

Like `fold`, but with no initial value.  The first iteration becomes the
starting accumulator.  Both the accumulator and each subsequent iteration are
passed as `table.pack`'d tables, so `func` receives `(packed_acc, packed_elem)`.
Returns the unpacked final result.  Returns nothing for an empty iterator, or
the single element unpacked for a one-element iterator.

```lua
Chiterator.counter():take(4)
    :reduce(function(a, b) return a[1] + b[1] end)
-- 10
```

#### `:collect()`

Consumes the iterator into a table.  The first two values of each iteration are
used as key and value.

```lua
Chiterator(pairs{x = 1, y = 2})
    :map(function(k, v) return k, v * 10 end)
    :collect()
-- {x = 10, y = 20}

-- With enumerate, builds a sequence:
Chiterator.counter():take(3):enumerate():collect()
-- {1, 2, 3}
```

#### `:count()`

Consumes the entire iterator, returning the number of iterations.

```lua
Chiterator.counter():take(100):filter(function(n) return n % 7 == 0 end):count()
-- 14
```

#### `:all(predicate)`

Returns `true` if `predicate(...)` is truthy for every iteration.  An empty
iterator returns `true`.  Short-circuits on the first `false`.  If `predicate`
is omitted, checks the first return value for truthiness.

```lua
Chiterator(ipairs{2, 4, 6}):all(function(_, v) return v % 2 == 0 end)
-- true

Chiterator(ipairs{}):all(function() return false end)
-- true  (vacuous truth)
```

#### `:any(predicate)`

Returns `true` if `predicate(...)` is truthy for any iteration.  An empty
iterator returns `false`.  Short-circuits on the first `true`.  If `predicate`
is omitted, checks the first return value for truthiness.

```lua
Chiterator(ipairs{1, 2, 3}):any(function(_, v) return v == 2 end)
-- true

Chiterator(ipairs{}):any()
-- false
```

---

### Standalone Functions

Every adapter and consumer is also available as a standalone module.  They
accept the iterator tuple directly, so they compose naturally with Lua's `for`
loop and with each other (though nesting gets verbose -- that's what
`Chiterator` is for).

#### `reiterate.counter()`

Returns an iterator that yields 1, 2, 3, ...

```lua
local counter = require 'reiterate.counter'
for i in counter() do
    if i > 3 then break end
    print(i)
end
```

#### `reiterate.once(...)`

Returns an iterator that yields the given values exactly once.

```lua
local once = require 'reiterate.once'
for v in once('hello') do print(v) end
-- hello
```

#### `reiterate.coro(func, ...)`

Wraps a function (or existing coroutine thread) as an iterator.  Each
`coroutine.yield()` and the final return produce one iteration.  Extra arguments
are passed on first resume.  The returned closeable will close the coroutine
if iteration ends early.

```lua
local coro = require 'reiterate.coro'
for line in coro(function() coroutine.yield('a'); return 'b' end) do
    print(line)
end
-- a
-- b
```

#### `reiterate.map(func, ...)`

Applies `func` to each iteration's values.  Returns `nil` to skip (filter-map).

```lua
local map = require 'reiterate.map'
local counter = require 'reiterate.counter'
local take = require 'reiterate.take'
for v in map(function(n) return n * n end, take(4, counter())) do
    print(v)
end
-- 1, 4, 9, 16
```

#### `reiterate.filter(func, ...)`

Keeps iterations where `func(...)` is truthy.

```lua
local filter = require 'reiterate.filter'
for v in filter(function(n) return n > 2 end, take(5, counter())) do
    print(v)
end
-- 3, 4, 5
```

#### `reiterate.take(n, ...)`

Yields at most `n` iterations.

```lua
local take = require 'reiterate.take'
for i in take(3, counter()) do print(i) end
-- 1, 2, 3
```

#### `reiterate.take_while(predicate, ...)`

Yields while `predicate(...)` is true.

```lua
local take_while = require 'reiterate.take_while'
for i in take_while(function(n) return n < 4 end, counter()) do print(i) end
-- 1, 2, 3
```

#### `reiterate.skip(n, ...)`

Consumes the first `n` iterations, then yields the rest.

```lua
local skip = require 'reiterate.skip'
for i in take(3, skip(2, counter())) do print(i) end
-- 3, 4, 5
```

#### `reiterate.skip_while(predicate, ...)`

Consumes iterations while `predicate(...)` is true, then yields the rest.

```lua
local skip_while = require 'reiterate.skip_while'
for i in take(3, skip_while(function(n) return n < 5 end, counter())) do
    print(i)
end
-- 5, 6, 7
```

#### `reiterate.enumerate(...)`

Prepends a 1-based index to each iteration's values.

```lua
local enumerate = require 'reiterate.enumerate'
for i, v in enumerate(map(function(_, v) return v end, ipairs{'a', 'b'})) do
    print(i, v)
end
-- 1  a
-- 2  b
```

#### `reiterate.zip(...)`

Combines packed iterator tables, yielding one `table.pack`'d result from each
per iteration.  Stops when any iterator is exhausted.  Each argument must be a
packed table (e.g. `{counter()}` or `table.pack(counter())`).

```lua
local zip = require 'reiterate.zip'
for nums, letters in zip({take(3, counter())}, {map(function(_, v) return v end, ipairs{'a', 'b', 'c'})}) do
    print(nums[1], letters[1])
end
-- 1  a
-- 2  b
-- 3  c
```

#### `reiterate.chain(...)`

Concatenates packed iterator tables sequentially.  Each argument must be a
packed table.

```lua
local chain = require 'reiterate.chain'
local once = require 'reiterate.once'
for v in chain({once(1)}, {once(2)}, {once(3)}) do print(v) end
-- 1
-- 2
-- 3
```

#### `reiterate.fold(init, func, ...)`

Consumes the iterator, reducing to a single value via
`func(accumulator, ...)`.

```lua
local fold = require 'reiterate.fold'
fold(0, function(sum, n) return sum + n end, take(5, counter()))
-- 15
```

#### `reiterate.reduce(func, ...)`

Like `fold` but uses the first iteration as the initial accumulator.  Both the
accumulator and subsequent iterations are passed as `table.pack`'d tables.
Returns the unpacked final result, or nothing for an empty iterator.

```lua
local reduce = require 'reiterate.reduce'
reduce(function(a, b) return a[1] + b[1] end, take(4, counter()))
-- 10
```

#### `reiterate.collect(...)`

Consumes the iterator into a key-value table from the first two values of each
iteration.

```lua
local collect = require 'reiterate.collect'
collect(enumerate(take(3, counter())))
-- {1, 2, 3}
```

#### `reiterate.count(...)`

Consumes the iterator, returning the total number of iterations.

```lua
local count = require 'reiterate.count'
count(take(100, counter()))
-- 100
```

#### `reiterate.all(predicate, ...)`

Returns `true` if `predicate(...)` is truthy for every iteration.  Empty
iterators return `true`.

```lua
local all = require 'reiterate.all'
all(function(_, v) return v < 4 end, ipairs{1, 2, 3})
-- true
```

#### `reiterate.any(predicate, ...)`

Returns `true` if `predicate(...)` is truthy for any iteration.  Empty
iterators return `false`.

```lua
local any = require 'reiterate.any'
any(function(_, v) return v == 2 end, ipairs{1, 2, 3})
-- true
```
