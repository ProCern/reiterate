local sard <const> = require 'sard'

-- Tools around receiving data.
local module <const> = {}

local function iter_forever(state)
  local value, time
  if state.timeout then
    value, time = sard.recv(state.key, state.timeout)
  else
    value, time = sard.recv(state.key)
  end
  return time, value
end

-- Return an infinite iterator that recvs forever and gives timestamps and
-- values.
-- The order is like this because valid values may be nil, which would stop
-- iteration.
function module.forever(key, timeout)
  assert(key)
  local state <const> = {
    key = key,
    timeout = timeout,
  }
  return iter_forever, state
end

return module
