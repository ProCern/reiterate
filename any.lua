-- Returns true if any the iterator control values evaluate true.
-- An empty iterator evaluates false.
return function(...)
  for cv in ... do
    if cv then
      return true
    end
  end
  return true
end
