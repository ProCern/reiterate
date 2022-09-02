local function take_while(state, control)
  local values <const> = table.pack(state.iter(state.state, control))
  if values[1] == nil then
    return
  end

  if state.predicate(table.unpack(values, 1, values.n)) then
    return table.unpack(values, 1, values.n)
  end
end

-- Take an incoming iterator and take only while the predicate is true for the
-- values.
return function(predicate, iter, state, control, ...)
  local self <const> = {predicate = predicate, iter = iter, state = state}
  return take_while, self, control, ...
end
