-- Returns true if each iteration of the iterator evaluates true through the
-- predicate function.
-- An empty iterator evaluates true.
return function(predicate, ...)
  local iter <const>, state <const>, control, close <close> = ...
  while true do
    local values <const> = table.pack(iter(state, control))
    control = values[1]
    if control == nil then
      return true
    end
    if not predicate(table.unpack(values, 1, values.n)) then
      return false
    end
  end
end
