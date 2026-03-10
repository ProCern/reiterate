local map <const> = require 'reiterate.map'

-- Folds the iterator into an accumulator, which is eventually returned.
-- Like functional fold.  Takes init to be the initial value of the accumulator.
-- Calls fun(accumulator, ...), assigning the result to accumulator on every
-- iteration.
return function(init, fun, ...)
  local accumulator = init

  for element in map(table.pack, ...) do
    accumulator = fun(accumulator, table.unpack(element, 1, element.n))
  end

  return accumulator
end
