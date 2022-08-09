local function noop()
end

-- Take an incoming iterator and skip the first n values.
-- This operates immediately when called.  If the end is reached early, this
-- will return a no-op iterator and forward the closing.
return function(n, iter, state, control, ...)
  for _=1, n do
    control = iter(state, control)
    if control == nil then
      return noop, nil, nil, ...
    end
  end
  return iter, state, control, ...
end
