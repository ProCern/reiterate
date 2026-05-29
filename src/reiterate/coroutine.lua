-- Wraps a coroutine or a function in an iterator, so that every yield (and any
-- returns with values) is treated as the iterator return values.
-- The values passed in are passed into the first call of coroutine.resume.
---@class iter.Coroutine
---@field coroutine thread
---@field args? {n: integer, [integer]: any}
local metatable <const> = {}

function metatable:__close()
  coroutine.close(self.coroutine)
end

-- Check the coroutine return values.
local function check(success, ...)
  if success then
    return ...
  else
    error((...), 0)
  end
end

---@param self iter.Coroutine
local function call(self)
  local status <const> = coroutine.status(self.coroutine)
  assert(status == 'dead' or status == 'suspended', 'Coroutine must be dead or suspended')
  if status == 'suspended' then
    local args = self.args
    if args then
      self.args = nil

      return check(coroutine.resume(self.coroutine, table.unpack(args, 1, args.n)))
    else
      return check(coroutine.resume(self.coroutine))
    end
  end
end

---@return (fun(coro: iter.Coroutine): any[]), iter.Coroutine, nil, iter.Coroutine
return function(coro, ...)
  if type(coro) ~= 'thread' then
    coro = coroutine.create(coro)
  end

  ---@type iter.Coroutine
  local self <const> = setmetatable({coroutine = coro}, metatable)
  self.args = table.pack(...)
  return call, self, nil, self
end
