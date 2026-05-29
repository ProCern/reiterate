local all <const> = require 'reiterate.all'
local any <const> = require 'reiterate.any'
local chain <const> = require 'reiterate.chain'
local collect <const> = require 'reiterate.collect'
local reiterate_coroutine <const> = require 'reiterate.coroutine'
local count <const> = require 'reiterate.count'
local counter <const> = require 'reiterate.counter'
local enumerate <const> = require 'reiterate.enumerate'
local filter <const> = require 'reiterate.filter'
local fold <const> = require 'reiterate.fold'
local map <const> = require 'reiterate.map'
local reduce <const> = require 'reiterate.reduce'
local skip <const> = require 'reiterate.skip'
local skip_while <const> = require 'reiterate.skip_while'
local take <const> = require 'reiterate.take'
local take_while <const> = require 'reiterate.take_while'
local zip <const> = require 'reiterate.zip'

-- A chainable iterator, which allows chaining iterator transformations for more
-- reasonable functional-style programming.
---@class iter.Chiterator
---@field n integer
---@overload fun(...): iter.Chiterator
local methods <const> = {}

local metatable <const> = {
  __index = methods,

  __name = 'Chiterator',
}

function metatable:__call(state, control)
  -- This intentionally uses the state and control from the iteration rather
  -- than the internally stored ones.  We only store them so we can properly
  -- chain, but otherwise we want to avoid leaning on the stored state too much.
  -- This is chainable iterators, not fully-encapsulated iterators.
  return self[1](state, control)
end

---@return iter.Chiterator, ...
local function construct(iter, ...)
  local self <const> = table.pack(iter, ...)
  -- Construct a chiterator, wrapping with the metatable, and unpacking the
  -- rest and returning them so they can be auto-closed and the like properly.
  return setmetatable(self, metatable), ...
end

local M = setmetatable({}, {
  __call = function(_, ...)
    return construct(...)
  end,
})

--- @return iter.Chiterator, ...
function M.counter()
  return construct(counter())
end

--- @return iter.Chiterator, ...
function M.coroutine(...)
  return construct(reiterate_coroutine(...))
end

function methods:iter()
  return table.unpack(self, 1, self.n)
end

-- Wraps the iterator into a chaining iterator, which will iterate all given
-- iterators in turn.
--- @return iter.Chiterator
function methods:chain(...)
  return construct(chain(self, table.pack(...)))
end

-- Wraps this and the iterator into a zipping iterator, which will iterate both
-- given iterators at once, giving all their values in table.pack bunches.
-- This stops as soon as either zipped iterator contained stops.
--- @return iter.Chiterator
function methods:zip(...)
  return construct(zip(self, table.pack(...)))
end

-- Wrap the iterator using a mapping function.
-- This is a flat map that will skip any elements for which a nil is returned.
---@param func fun(...): ... A function that takes all the parameters of each iteration.
--- @return iter.Chiterator
function methods:map(func)
  return construct(map(func, self:iter()))
end

-- Wrap with a filter, which will use a function that should return a truthy value
-- to keep values in and a falsey one to filter them out.
---@param func fun(...) A function that takes all the parameters of each iteration.
--- @return iter.Chiterator
function methods:filter(func)
  return construct(filter(func, self:iter()))
end

-- Prepend the iterator results with an enumeration from 1.
--- @return iter.Chiterator
function methods:enumerate()
  return construct(enumerate(self:iter()))
end

-- Skip n items immediately.
-- Unlike most other wrappers, this doesn't wait until iteration has started
-- to start working.  This immediately skips the items from the contained
-- iterator.
---@param n integer The number of iterations to skip.
--- @return iter.Chiterator
function methods:skip(n)
  return construct(skip(n, self:iter()))
end

-- Skip items immediately while the predicate is true.
-- Unlike most other wrappers, this doesn't wait until iteration has started
-- to start working.  This immediately skips the items from the contained
-- iterator.
---@param predicate fun(...): boolean
--- @return iter.Chiterator
function methods:skip_while(predicate)
  return construct(skip_while(predicate, self:iter()))
end

-- Stop after n items.
---@param n integer The number of iterations to take.
--- @return iter.Chiterator
function methods:take(n)
  return construct(take(n, self:iter()))
end

-- Stop when the predicate is false
---@param predicate fun(...): boolean
--- @return iter.Chiterator
function methods:take_while(predicate)
  return construct(take_while(predicate, self:iter()))
end

-- Fold the iterator into an accumulator (initiated with init) using function fun.
---@generic T
---@param init `T` The initial value for the accumulator
---@param fun fun(T, ...): T A function that takes the accumulator and all the parameters of each iteration.
---@return T
function methods:fold(init, fun)
  return fold(init, fun, self:iter())
end

-- Collect into a construct table with the key and value being set from the first
-- two variables of each iteration of the iterator.
function methods:collect()
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
function methods:reduce(fun)
  return reduce(fun, self:iter())
end

local function default_predicate(...)
  return ...
end

-- Returns true if the predicate evaluates true for all iterations.
-- If the predicate is absent, the iterator control variable is just checked
-- for truthiness.
-- An empty iterator evaluates true.
function methods:all(predicate)
  return all(predicate or default_predicate, self:iter())
end

-- Returns true if the predicate evaluates true for any iteration.
-- If the predicate is absent, the iterator control variable is just checked
-- for truthiness.
-- An empty iterator evaluates false.
function methods:any(predicate)
  return any(predicate or default_predicate, self:iter())
end

-- Consumes and counts iterations of this iterator.
function methods:count()
  return count(self:iter())
end

return M
