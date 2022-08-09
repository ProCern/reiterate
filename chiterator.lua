local map <const> = require 'map'
local filter <const> = require 'filter'
local enumerate <const> = require 'enumerate'
local skip <const> = require 'skip'
local take <const> = require 'take'
local collect <const> = require 'collect'

local metatable <const> = {
  __call = function(self, state, control)
    -- Allow updating self.control.  This shouldn't usually be necessary, but
    -- will allow for interruptible and resumable chiterators.
    local values = table.pack(self.iter(state, control))
    self.control = values[1]
    return table.unpack(values, 1, values.n)
  end,

  __index = {
    -- Wrap the chiterator's contained iterator with an iterator transformer.
    wrap = function(self, func, ...)
      local args <const> = table.pack(...)
      args[args.n + 1] = self.iter
      args[args.n + 2] = self.state
      args[args.n + 3] = self.control
      args[args.n + 4] = self.closing
      args.n = args.n + 4

      self.iter, self.state, self.control, self.closing = func(table.unpack(args, 1, args.n))
      return self, self.state, self.control, self.closing
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

    collect = function(self)
      return collect(self.iter, self.state, self.control, self.closing)
    end,
  }
}

-- Make an iterator into a chainable iterator, which allows creating iterators
-- from others in a natural way.
return function(iter, state, control, closing)
  local self <const> = {
    iter = iter,
    state = state,
    control = control,
    closing = closing,
  }
  return setmetatable(self, metatable), state, control, closing
end
