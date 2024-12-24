local function enumerate(self, control)
  local values = table.pack(self.iter(self.state, self.control))
  self.control = values[1]
  if self.control == nil then
    return
  end

  return control + 1, table.unpack(values, 1, values.n)
end

-- Take an incoming iterator and stick an enumeration from 1 to the left of it.
return function(iter, state, control, ...)
  local self <const> = {
    iter = iter,
    state = state,
    control = control,
  }
  return enumerate, self, 0, ...
end
