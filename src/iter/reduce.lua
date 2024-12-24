local map <const> = require 'iter.map'

-- Similar to fold, but applies an operation to successive iterations of the
-- iterator, passing packed tables as arguments to the function.
-- One major difference from fold is that the final return may be multiple
-- values.
return function(fun, ...)
  local accumulator

  for element in map(table.pack, ...) do
    if accumulator then
      accumulator = table.pack(fun(accumulator, element))
    else
      accumulator = element
    end
  end

  if accumulator then
    return table.unpack(accumulator, 1, accumulator.n)
  end
end
