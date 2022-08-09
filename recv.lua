local sard <const> = require 'sard'

local function iter_forever(state)
  local value, time
  if state.timeout then
    value, time = sard.recv(state.key, state.timeout)
  else
    value, time = sard.recv(state.key)
  end
  return time, value
end

-- Return a possibly-infinite iterator that recvs forever and gives timestamps
-- and values.
-- The order is like this because valid values may be nil, which would stop
-- iteration.
-- If timeout is not specified, then it will iterate forever.
--
-- You can use a timeout of 0 to non-blockingly drain the queue.
return function(key, timeout)
  assert(key)
  local state <const> = {
    key = key,
    timeout = timeout,
  }
  return iter_forever, state
end
