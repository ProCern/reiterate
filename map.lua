local function map(self)
  local values = table.pack(self.iter(self.state, self.control))
  self.control = values[1]
  if self.control == nil then
    return
  end

  values = table.pack(self.func(table.unpack(values, 1, values.n)))

  -- Filter, do next iteration.
  if values[1] == nil then
    return map(self)
  else
    return table.unpack(values, 1, values.n)
  end
end

-- Get a map function.  This actually acts as a filter map, and turning input
-- non-nils into nils will actually just skip that iteration.
return function(func, iter, state, control, ...)
  local self <const> = {
    func = func,
    iter = iter,
    state = state,
    control = control,
  }
  return map, self, nil, ...
end
