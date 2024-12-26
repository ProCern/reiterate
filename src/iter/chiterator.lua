local all <const> = require 'iter.all'
local any <const> = require 'iter.any'
local chain <const> = require 'iter.chain'
local collect <const> = require 'iter.collect'
local coro <const> = require 'iter.coro'
local count <const> = require 'iter.count'
local counter <const> = require 'iter.counter'
local enumerate <const> = require 'iter.enumerate'
local filter <const> = require 'iter.filter'
local fold <const> = require 'iter.fold'
local map <const> = require 'iter.map'
local reduce <const> = require 'iter.reduce'
local skip <const> = require 'iter.skip'
local skip_while <const> = require 'iter.skip_while'
local take <const> = require 'iter.take'
local take_while <const> = require 'iter.take_while'
local zip <const> = require 'iter.zip'

local table_pack <const> = table.pack
local table_unpack <const> = table.unpack
local setmetatable <const> = setmetatable

-- global protection
local _ENV <const> = nil

---@class iter.Chiterator
-- A chainable iterator, which allows chaining iterator transformations for more
-- reasonable functional-style programming.
--
---@field n integer
---@overload fun(...): iter.Chiterator
local Chiterator <const> = {}

local metatable <const> = {
  __index = Chiterator,

  __name = 'Chiterator',
}

function metatable:__call(state, control)
  return self[1](state, control)
end

local function construct(iter, ...)
  local self <const> = table_pack(iter, ...)
  -- Construct a chiterator, wrapping with the metatable, and unpacking the
  -- rest and returning them so they can be auto-closed and the like properly.
  return setmetatable(self, metatable), ...
end

local class_metatable = {
  __name = 'class Chiterator',
}

function class_metatable:__call(...)
  return construct(...)
end

setmetatable(Chiterator, class_metatable)

--- @return iter.Chiterator
function Chiterator.counter()
  return construct(counter())
end

--- @return iter.Chiterator
function Chiterator.coro(...)
  return construct(coro(...))
end

function Chiterator:iter()
  return table_unpack(self, 1, self.n)
end

-- Wraps the iterator into a chaining iterator, which will iterate all given
-- iterators in turn.
--- @return iter.Chiterator
function Chiterator:chain(...)
  return construct(chain(table_pack(self:iter()), table_pack(...)))
end

-- Wraps this and the iterator into a zipping iterator, which will iterate all
-- given iterators at once, giving all their values in table.pack bunches.
-- Because of the way Lua iterators work, each iterator needs to be packed
-- either via table.pack or as a plain array table. This stops as soon as any
-- zipped iterator contained stops.
--- @return iter.Chiterator
function Chiterator:zip(...)
  return construct(zip(table_pack(self:iter()), table_pack(...)))
end

-- Wrap the iterator using a mapping function.
-- This is a flat map that will skip any elements for which a nil is returned.
---@param func fun(...) A function that takes all the parameters of each iteration.
--- @return iter.Chiterator
function Chiterator:map(func)
  return construct(map(func, table_unpack(self, 1, self.n)))
end

-- Wrap with a filter, which will use a function that should return a truthy value
-- to keep values in and a falsey one to filter them out.
---@param func fun(...) A function that takes all the parameters of each iteration.
--- @return iter.Chiterator
function Chiterator:filter(func)
  return construct(filter(func, table_unpack(self, 1, self.n)))
end

-- Prepend the iterator results with an enumeration from 1.
--- @return iter.Chiterator
function Chiterator:enumerate()
  return construct(enumerate(table_unpack(self, 1, self.n)))
end

-- Skip n items immediately.
-- Unlike most other wrappers, this doesn't wait until iteration has started
-- to start working.  This immediately skips the items from the contained
-- iterator.
---@param n integer The number of iterations to skip.
--- @return iter.Chiterator
function Chiterator:skip(n)
  return construct(skip(n, table_unpack(self, 1, self.n)))
end

-- Skip items immediately while the predicate is true.
-- Unlike most other wrappers, this doesn't wait until iteration has started
-- to start working.  This immediately skips the items from the contained
-- iterator.
---@param predicate fun(...): boolean
--- @return iter.Chiterator
function Chiterator:skip_while(predicate)
  return construct(skip_while(predicate, table_unpack(self, 1, self.n)))
end

-- Stop after n items.
---@param n integer The number of iterations to take.
--- @return iter.Chiterator
function Chiterator:take(n)
  return construct(take(n, table_unpack(self, 1, self.n)))
end

-- Stop when the predicate is false
---@param predicate fun(...): boolean
--- @return iter.Chiterator
function Chiterator:take_while(predicate)
  return construct(take_while(predicate, table_unpack(self, 1, self.n)))
end

-- Fold the iterator into an accumulator (initiated with init) using function fun.
---@generic T
---@param init `T` The initial value for the accumulator
---@param fun fun(T, ...): T A function that takes the accumulator and all the parameters of each iteration.
---@return T
function Chiterator:fold(init, fun)
  return fold(init, fun, self:iter())
end

-- Collect into a construct table with the key and value being set from the first
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

local function default_predicate(...)
  return ...
end

-- Returns true if the predicate evaluates true for all iterations.
-- If the predicate is absent, the iterator control variable is just checked
-- for truthiness.
-- An empty iterator evaluates true.
function Chiterator:all(predicate)
  return all(predicate or default_predicate, self:iter())
end

-- Returns true if the predicate evaluates true for any iteration.
-- If the predicate is absent, the iterator control variable is just checked
-- for truthiness.
-- An empty iterator evaluates false.
function Chiterator:any(predicate)
  return any(predicate or default_predicate, self:iter())
end

-- Consumes and counts iterations of this iterator.
function Chiterator:count()
  return count(self:iter())
end

return Chiterator
