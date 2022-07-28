local sard <const> = require 'sard'

-- Tools around receiving data.
local module <const> = {}

-- Return an infinite iterator that recvs forever and gives timestamps and
-- values.
-- The order is like this because valid values may be nil, which would stop
-- iteration.
function module.forever(key, interval)
  assert(key)
  return function()
    local value, time
    if interval then
      value, time = sard.recv(key, interval)
    else
      value, time = sard.recv(key)
    end
    return time, value
  end
end

return module
