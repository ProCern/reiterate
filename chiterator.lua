local map <const> = require 'map'
local filter <const> = require 'filter'
local enumerate <const> = require 'enumerate'
local skip <const> = require 'skip'
local take <const> = require 'take'
local collect <const> = require 'collect'
local reduce <const> = require 'reduce'
local fold <const> = require 'fold'

---@class Chiterator
local Chiterator <const> = {
  iter = function(self)
    return table.unpack(self, 1, self.n)
  end,

  -- Wrap the chiterator's contained iterator with an iterator transformer.
  ---@return Chiterator
  wrap = function(self, func, ...)
    local args <const> = table.pack(...)
    table.move(self, 1, self.n, args.n + 1, args)
    args.n = args.n + self.n

    local wrapped <const> = table.pack(func(table.unpack(args, 1, args.n)))
    table.move(wrapped, 1, wrapped.n, 1, self)
    table.move(wrapped, wrapped.n + 1, self.n, wrapped.n + 1, self)
    self.n = wrapped.n

    return self, table.unpack(self, 2, self.n)
  end,

  -- Wrap the iterator using a mapping function.
  -- This is a flat map that will skip any elements for which a nil is returned.
  ---@return Chiterator
  map = function(self, func)
    return self:wrap(map, func)
  end,

  -- Wrap with a filter, which will use a function that should return a truthy value
  -- to keep values in and a falsey one to filter them out.
  ---@return Chiterator
  filter = function(self, func)
    return self:wrap(filter, func)
  end,

  -- Prepend the iterator results with an enumeration from 1.
  ---@return Chiterator
  enumerate = function(self)
    return self:wrap(enumerate)
  end,

  -- Skip n items immediately.
  -- Unlike most other wrappers, this doesn't wait until iteration has started
  -- to start working.  This immediately skips the items from the contained
  -- iterator.
  ---@return Chiterator
  skip = function(self, n)
    return self:wrap(skip, n)
  end,

  -- Stop after n items.
  ---@return Chiterator
  take = function(self, n)
    return self:wrap(take, n)
  end,

  -- Fold the iterator into an accumulator (initiated with init) using function fun.
  fold = function(self, init, fun)
    return fold(init, fun, self:iter())
  end,

  -- Collect into a new table with the key and value being set from the first
  -- two variables of each iteration of the iterator.
  collect = function(self)
    return collect(self:iter())
  end,

  -- Reduce the iterator using the function binary operation.  On the first two
  -- iterations, the items are the first two iteration items (packed with
  -- table.pack).  On all following iterations, the first item is the result of
  -- the previous call, and the following items are each following iteration.
  -- Returns the unpacked result from the last call.  If there is only one
  -- element, returns that element.  Otherwise returns nothing.
  reduce = function(self, fun)
    return reduce(fun, self:iter())
  end,
}

local metatable <const> = {
  __call = function(self, state, control)
    -- Allow updating self.control.  This shouldn't usually be necessary, but
    -- will allow for interruptible and resumable chiterators.
    local values = table.pack(self.iter(state, control))
    self.control = values[1]
    return table.unpack(values, 1, values.n)
  end,

  __index = Chiterator,
}

-- Make an iterator into a chainable iterator, which allows creating iterators
-- from others in a natural way.
---@return Chiterator
return function(...)
  local self <const> = table.pack(...)
  return setmetatable(self, metatable), table.unpack(self, 2, self.n)
end
