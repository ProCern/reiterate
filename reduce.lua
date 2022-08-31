local map <const> = require 'map'

-- Similar to fold, but applies an operation to successive iterations of the
-- iterator, passing packed tables as arguments to the function.
return function(fun, ...)
  local accumulator

  for element in map(table.pack, ...) do
    if accumulator then
      accumulator = table.pack(fun(accumulator, element))
    else
      accumulator = element
    end
  end

  return table.unpack(accumulator, 1, accumulator.n)
end
