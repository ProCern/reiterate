-- Wraps a coroutine or a function in an iterator, so that every yield (and any
-- returns with values) is treated as the iterator return values.
-- The values passed in are passed into the first call of coroutine.resume.
---@class iter.Coro
---@field coroutine thread
---@field n integer?
---@overload fun(...): iter.Coro
local Coro <const> = {}

local metatable <const> = {
  __close = function(self)
    coroutine.close(self.coroutine)
  end,
}

---@param self iter.Coro
local function call(self)
  local status <const> = coroutine.status(self.coroutine)
  assert(status == 'dead' or status == 'suspended', 'Coroutine must be dead or suspended')
  if status == 'suspended' then
    if self.n then
      local args <const> = table.move(self, 1, self.n, 1, {})
      args.n = self.n

      -- Clear out now-unnecessary values
      table.move({}, 1, self.n, 1, self)
      self.n = nil

      return coroutine.resume(self.coroutine, table.unpack(args, 1, args.n))
    else
      return coroutine.resume(self.coroutine)
    end
  end
end

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(Coro, {
  __call = function(_, coro, ...)
    if type(coro) ~= 'thread' then
      coro = coroutine.create(coro)
    end
    local self <const> = table.pack(...)
    self.coroutine = coro
    setmetatable(self, metatable)
    return call, self, nil, self
  end,
})
