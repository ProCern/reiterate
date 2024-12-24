local MaybeClose = require 'iter._maybe_close'
local chain = require 'iter.chain'
local once = require 'iter.once'

-- Take an incoming iterator and skip while the predicate is true for the
-- values. This operates immediately when called.  If the end is reached early,
-- this will return a no-op iterator and forward the closing.
return function(predicate, iter, state, control, ...)
  -- Emergency closer, in case the iter method throws an error, we still want to
  -- opportunistically close as early as possible.
  local closer <close> = MaybeClose(...)
  while true do
    local values <const> = table.pack(iter(state, control))
    control = values[1]
    if values[1] == nil then
      closer.close = false
      return function() end, nil, nil, ...
    end
    if not predicate(table.unpack(values, 1, values.n)) then
      closer.close = false
      return chain(
        table.pack(once(table.unpack(values, 1, values.n))),
        table.pack(iter, state, control, ...))
    end
  end
end
