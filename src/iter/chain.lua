local close_list = require 'iter._close_iterlist'

-- Wraps iterators into a chaining iterator, which will iterate all given
-- iterators in turn.  Because of the way Lua iterators work, each iterator
-- needs to be packed either via table.pack or as a plain array table.
---@class iter.Chain
---@field n integer
---@field current integer
---@field [integer] table
local metatable <const> = {}

-- A recursive solution is nicer than this, but may lead to stack overflow
function metatable:__close()
  close_list(self, self.current, self.n)
end

---@param chain iter.Chain
local function call(chain)
  if chain.current <= chain.n then
    local current <const> = chain[chain.current]
    local values <const> = table.pack(current[1](current[2], current[3]))
    current[3] = values[1]
    if values[1] ~= nil then
      return table.unpack(values, 1, values.n)
    end

    -- Proceed to the next one, closing this one first in a way that allows
    -- proper tail calls.
    local prev_current = chain.current

    -- So the auto-close works even if this throws an error, rather than
    -- re-closing the current.
    chain.current = chain.current + 1
    do
      local _ <close> = current[4]
      chain[prev_current] = nil
    end
    return call(chain)
  end
end

---@return (fun(chain: iter.Chain): any[]), iter.Chain, nil, iter.Chain
return function(...)
  ---@type iter.Chain
  local chain <const> = table.pack(...)
  chain.current = 1
  setmetatable(chain, metatable)
  return call, chain, nil, chain
end
