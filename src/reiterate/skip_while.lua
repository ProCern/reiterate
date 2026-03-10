local pack = table.pack
local unpack = table.unpack

local function skip(state, control)
  local predicate = state.predicate
  local iter = state.iter
  local inner = state.state

  if predicate == nil then
    return iter(inner, control)
  end
  local output = pack(iter(inner, control))

  while predicate ~= nil and output[1] ~= nil do
    if predicate(unpack(output, 1, output.n)) then
      output = pack(iter(inner, output[1]))
    else
      predicate = nil
      state.predicate = nil
    end
  end
  return unpack(output, 1, output.n)
end

-- Take an incoming iterator and skip while the predicate is true.
return function(predicate, iter, state, control, ...)
  local sw_state = {
    iter = iter,
    state = state,
    predicate = predicate,
  }
  return skip, sw_state, control, ...
end
