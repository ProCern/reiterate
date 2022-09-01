-- Returns true if all the iterator control values evaluate true.
-- An empty iterator evaluates true.
return function(...)
  for cv in ... do
    if not cv then
      return false
    end
  end
  return true
end
