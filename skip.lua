local MaybeClose = require '_maybe_close'

-- Take an incoming iterator and skip the first n values.
-- This operates immediately when called.  If the end is reached early, this
-- will return a no-op iterator and forward the closing.
return function(n, iter, state, control, ...)
  -- Emergency closer, in case the iter method throws an error, we still want to
  -- opportunistically close as early as possible.
  local closer <close> = MaybeClose(...)
  for _=1, n do
    control = iter(state, control)
    if control == nil then
      closer.close = false
      return function() end, nil, nil, ...
    end
  end
  closer.close = false
  return iter, state, control, ...
end
