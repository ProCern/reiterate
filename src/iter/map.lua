local pack = table.pack
local unpack = table.unpack

local function map(self, cv)
  local state = self.state
  local values = pack(self.iter(state, self.control))
  self.control = values[1]
  if self.control == nil then
    return
  end

  values = pack(self.func(unpack(values, 1, values.n)))

  -- Filter, do next iteration.
  if values[1] == nil then
    return map(self)
  else
    return unpack(values, 1, values.n)
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
  return map, self, 'cv', ...
end
