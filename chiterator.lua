local map <const> = require 'map'
local filter <const> = require 'filter'
local enumerate <const> = require 'enumerate'
local skip <const> = require 'skip'
local take <const> = require 'take'
local collect <const> = require 'collect'
local reduce <const> = require 'reduce'
local fold <const> = require 'fold'

---@class iter.Chiterator
-- A chainable iterator, which allows chaining iterator transformations for more
-- reasonable functional-style programming.
--
---@field n integer
---@overload fun(...): iter.Chiterator
local Chiterator <const> = {}

function Chiterator:iter()
  return table.unpack(self, 1, self.n)
end

-- Wrap the chiterator's contained iterator with an iterator transformer.
---@param func fun(...): iter.Chiterator, ...
---@return iter.Chiterator
function Chiterator:wrap(func, ...)
  local args <const> = table.pack(...)
  table.move(self, 1, self.n, args.n + 1, args)
  args.n = args.n + self.n

  local wrapped <const> = table.pack(func(table.unpack(args, 1, args.n)))
  table.move(wrapped, 1, wrapped.n, 1, self)
  table.move(wrapped, wrapped.n + 1, self.n, wrapped.n + 1, self)
  self.n = wrapped.n

  return self, table.unpack(self, 2, self.n)
end

-- Wrap the iterator using a mapping function.
-- This is a flat map that will skip any elements for which a nil is returned.
---@param func fun(...) A function that takes all the parameters of each iteration.
--- @return iter.Chiterator
function Chiterator:map(func)
  return self:wrap(map, func)
end

-- Wrap with a filter, which will use a function that should return a truthy value
-- to keep values in and a falsey one to filter them out.
---@param func fun(...) A function that takes all the parameters of each iteration.
--- @return iter.Chiterator
function Chiterator:filter(func)
  return self:wrap(filter, func)
end

-- Prepend the iterator results with an enumeration from 1.
--- @return iter.Chiterator
function Chiterator:enumerate()
  return self:wrap(enumerate)
end

-- Skip n items immediately.
-- Unlike most other wrappers, this doesn't wait until iteration has started
-- to start working.  This immediately skips the items from the contained
-- iterator.
---@param n integer The number of iterations to skip.
--- @return iter.Chiterator
function Chiterator:skip(n)
  return self:wrap(skip, n)
end

-- Stop after n items.
---@param n integer The number of iterations to take.
--- @return iter.Chiterator
function Chiterator:take(n)
  return self:wrap(take, n)
end

-- Fold the iterator into an accumulator (initiated with init) using function fun.
---@generic T
---@param init `T` The initial value for the accumulator
---@param fun fun(T, ...): T A function that takes the accumulator and all the parameters of each iteration.
---@return T
function Chiterator:fold(init, fun)
  return fold(init, fun, self:iter())
end

-- Collect into a new table with the key and value being set from the first
-- two variables of each iteration of the iterator.
function Chiterator:collect()
  return collect(self:iter())
end

-- Reduce the iterator using the function binary operation.  On the first two
-- iterations, the items are the first two iteration items (packed with
-- table.pack).  On all following iterations, the first item is the result of
-- the previous call, and the following items are each following iteration.
-- Returns the unpacked result from the last call.  If there is only one
-- element, returns that element.  Otherwise returns nothing.
---@param fun fun(a: any[], b: any[]): ... A function that takes the first two iterations as packed tables, and then the returned values and all the following elements as packed tables.
---@return ...
function Chiterator:reduce(fun)
  return reduce(fun, self:iter())
end

local metatable <const> = {
  __call = function(self, state, control)
    -- Allow updating self.control.  This shouldn't usually be necessary, but
    -- will allow for interruptible and resumable chiterators.
    local values = table.pack(self.iter(state, control))
    self.control = values[1]
    return table.unpack(values, 1, values.n)
  end,

  __index = Chiterator,

  __name = 'Chiterator',
}

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(Chiterator, {
  __call = function(_, ...)
    local self <const> = table.pack(...)
    return setmetatable(self, metatable), table.unpack(self, 2, self.n)
  end
})
