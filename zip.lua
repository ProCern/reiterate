-- Wraps iterators into a zipping iterator, which will iterate all given
-- iterators at once, giving all their values in table.pack bunches.  Because of
-- the way Lua iterators work, each iterator needs to be packed either via
-- table.pack or as a plain array table.
-- This stops as soon as any zipped iterator contained stops.
---@class iter.Zip
---@field n integer
---@field current integer
---@overload fun(...): iter.Zip
local Zip <const> = {}

local metatable <const> = {
  __close = function(self)
    -- Close all iterators
    for i=1, self.n do
      local _ <close> = self[i][4]
    end
  end,
}

---@param self iter.Zip
local function call(self)
  local output <const> = {}
  for i=1, self.n do
    local current <const> = self[i]
    local values <const> = table.pack(current[1](current[2], current[3]))
    if values[1] == nil then
      -- An iterator returned nil; we're done.
      return
    end
    current[3] = values[1]

    output[#output+1] = values
  end
  return table.unpack(output)
end

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(Zip, {
  __call = function(_, ...)
    local self <const> = table.pack(...)
    setmetatable(self, metatable)
    return call, self, nil, self
  end,
})
