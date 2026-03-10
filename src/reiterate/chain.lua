local close_stack = require('close-stack').close_stack

-- Wraps iterators into a chaining iterator, which will iterate all given
-- iterators in turn.  Because of the way Lua iterators work, each iterator
-- needs to be packed either via table.pack or as a plain array table.
---@class iter.Chain
---@field n integer
---@field current integer
---@field [integer] table
local metatable <const> = {}

function metatable:__close()
  local stack <close> = close_stack()
  for i=self.current, self.n do
    stack:push(self[i][4])
  end
end

---@param chain iter.Chain
local function call(chain)
  if chain.current <= chain.n then
    local current <const> = chain[chain.current]
    local fun <const>, state <const>, cv <const>, closeable <const> = table.unpack(current, 1, 4)
    local values <const> = table.pack(fun(state, cv))
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
      local _ <close> = closeable
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
