local close_stack = require('close_stack').close_stack

---@class iter.Zip
---@field n integer
local metatable <const> = {
  __name = 'Zip',
}

---@param self iter.Zip
local function call(self)
  local output <const> = {}
  for i=1, self.n do
    local current <const> = self[i]
    local fun <const>, state <const>, cv <const> = table.unpack(current, 1, 3)
    local values <const> = table.pack(fun(state, cv))
    if values[1] == nil then
      -- An iterator returned nil; we're done.
      return
    end

    -- Update the cv
    current[3] = values[1]
    output[i] = values
  end
  return table.unpack(output, 1, self.n)
end

-- Wraps iterators into a zipping iterator, which will iterate all given
-- iterators at once, giving all their values in table.pack bunches.  Because of
-- the way Lua iterators work, each iterator needs to be packed either via
-- table.pack or as a plain array table.
-- This stops as soon as any zipped iterator contained stops.
---@return (fun(state: iter.Zip): any[]), iter.Zip, nil, any
return function(...)
  local zip = setmetatable(table.pack(...), metatable)
  local stack = close_stack()
  for i=1, zip.n do
    stack:push(zip[i][4])
  end
  return call, zip, nil, stack
end
