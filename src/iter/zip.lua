local close_list = require 'iter._close_iterlist'

-- Wraps iterators into a zipping iterator, which will iterate all given
-- iterators at once, giving all their values in table.pack bunches.  Because of
-- the way Lua iterators work, each iterator needs to be packed either via
-- table.pack or as a plain array table.
-- This stops as soon as any zipped iterator contained stops.
---@class iter.Zip
---@field n integer
local metatable <const> = {}

function metatable:__close()
  close_list(self, 1, self.n)
end

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

---@return (fun(coro: iter.Zip): any[]), iter.Zip, nil, iter.Zip
return function(...)
  local zip = setmetatable(table.pack(...), metatable)
  return call, zip, nil, zip
end
