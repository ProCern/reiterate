-- Consumes the iterator, returning the number of iterations it yielded.
return function(...)
  local i = 0
  for _ in ... do
    i = i + 1
  end
  return i
end
