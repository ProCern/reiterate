-- Just collects all the iterator values into a key-value pair set of just the
-- first and second items.
return function(...)
  local output <const> = {}
  for k, v in ... do
    output[k] = v
  end
  return output
end
