local map <const> = require 'map'
local filter <const> = require 'filter'
local enumerate <const> = require 'enumerate'
local skip <const> = require 'skip'
local take <const> = require 'take'
local collect <const> = require 'collect'
local reduce <const> = require 'reduce'
local fold <const> = require 'fold'

local metatable <const> = {
  __call = function(self, state, control)
    -- Allow updating self.control.  This shouldn't usually be necessary, but
    -- will allow for interruptible and resumable chiterators.
    local values = table.pack(self.iter(state, control))
    self.control = values[1]
    return table.unpack(values, 1, values.n)
  end,

  __index = {
    iter = function(self)
      return table.unpack(self, 1, self.n)
    end,

    -- Wrap the chiterator's contained iterator with an iterator transformer.
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

    map = function(self, func)
      return self:wrap(map, func)
    end,

    filter = function(self, func)
      return self:wrap(filter, func)
    end,

    enumerate = function(self)
      return self:wrap(enumerate)
    end,

    skip = function(self, n)
      return self:wrap(skip, n)
    end,

    take = function(self, n)
      return self:wrap(take, n)
    end,

    fold = function(self, init, fun)
      return fold(init, fun, self:iter())
    end,

    collect = function(self)
      return collect(self:iter())
    end,

    reduce = function(self, fun)
      return reduce(fun, self:iter())
    end,
  }
}

-- Make an iterator into a chainable iterator, which allows creating iterators
-- from others in a natural way.
return function(...)
  local self <const> = table.pack(...)
  return setmetatable(self, metatable), table.unpack(self, 2, self.n)
end
