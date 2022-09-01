-- Returns true if any iteration of the iterator evaluates true through the
-- predicate function.
-- An empty iterator evaluates false.
return function(predicate, ...)
  local iter <const>, state <const>, control, close <close> = ...
  while true do
    local values <const> = table.pack(iter(state, control))
    if values[1] == nil then
      return false
    end
    control = values[1]
    if predicate(table.unpack(values, 1, values.n)) then
      return true
    end
  end
end
