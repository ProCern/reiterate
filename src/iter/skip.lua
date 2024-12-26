local function skip(state, control)
  local n = state.n
  local iter = state.iter
  local inner = state.state

  while n > 0 do
    n = n - 1
    state.n = n
    control = iter(inner, control)
    if control == nil then
      return
    end
  end
  return iter(inner, control)
end

-- Take an incoming iterator and skip the first n values.
return function(n, iter, state, control, ...)
  local state = {
    iter = iter,
    state = state,
    n = n,
  }
  return skip, state, control, ...
end
