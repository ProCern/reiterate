-- Wraps a coroutine or a function in an iterator, so that every yield (and any
-- returns with values) is treated as the iterator return values.
-- The values passed in are passed into the first call of coroutine.resume.
---@class iter.Coro
---@field coroutine thread
---@field n integer?
---@overload fun(...): iter.Coro
local Coro <const> = {}

local coroutine_close <const> = coroutine.close
local coroutine_status <const> = coroutine.status
local coroutine_resume <const> = coroutine.resume
local coroutine_create <const> = coroutine.create
local table_pack <const> = table.pack
local table_unpack <const> = table.unpack
local table_move <const> = table.move

local metatable <const> = {
  __close = function(self)
    coroutine_close(self.coroutine)
  end,
}

-- Check the coroutine return values.
local function check(success, ...)
  if success then
    return ...
  else
    error((...), 2)
  end
end

local function call(self)
  local status <const> = coroutine_status(self.coroutine)
  assert(status == 'dead' or status == 'suspended', 'Coroutine must be dead or suspended')
  if status == 'suspended' then
    if self.n then
      local args <const> = table_move(self, 1, self.n, 1, {})
      args.n = self.n

      -- Clear out now-unnecessary values
      table_move({}, 1, self.n, 1, self)
      self.n = nil

      return check(coroutine_resume(self.coroutine, table_unpack(args, 1, args.n)))
    else
      return check(coroutine_resume(self.coroutine))
    end
  end
end

return setmetatable(Coro, {
  __call = function(_, coro, ...)
    if type(coro) ~= 'thread' then
      coro = coroutine_create(coro)
    end
    local self <const> = table_pack(...)
    self.coroutine = coro
    setmetatable(self, metatable)
    return call, self, nil, self
  end,
})
