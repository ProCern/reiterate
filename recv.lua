local sard <const> = require 'sard'

local function iter_forever(state)
  local value <const>, time <const> = sard.recv(table.unpack(state, 1, state.n))
  return time, value
end

-- Return a possibly-infinite iterator that recvs forever and gives timestamps
-- and values.
-- The order is like this because valid values may be nil, which would stop
-- iteration.
-- If timeout is not specified, then it will iterate forever.
--
-- You can use a timeout of 0 to non-blockingly drain the queue.
return function(...)
  local state <const> = table.pack(...)
  return iter_forever, state
end
