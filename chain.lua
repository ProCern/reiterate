-- Wraps iterators into a chaining iterator, which will iterate all given
-- iterators in turn.  Because of the way Lua iterators work, each iterator
-- needs to be packed either via table.pack or as a plain array table.
---@class iter.Chain
---@field n integer
---@field current integer
---@overload fun(...): iter.Chain
local Chain <const> = {}

local metatable <const> = {
  __close = function(self)
    -- Close remaining unclosed iterators
    for i=self.current, self.n do
      local _ <close> = self[i][4]
    end
  end,
}

---@param self iter.Chain
local function call(self)
  if self.current <= self.n then
    local current <const> = self[self.current]
    local values <const> = table.pack(current[1](current[2], current[3]))
    current[3] = values[1]
    if values[1] ~= nil then
      return table.unpack(values, 1, values.n)
    else
      -- Proceed to the next one, closing this one first in a way that allows
      -- proper tail calls.
      do
        local _ <close> = current[4]
        self[self.current] = nil
      end
      self.current = self.current + 1
      return call(self)
    end
  end
end

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(Chain, {
  __call = function(_, ...)
    local self <const> = table.pack(...)
    self.current = 1
    setmetatable(self, metatable)
    return call, self, nil, self
  end,
})
