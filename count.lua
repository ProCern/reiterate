local function count(_, last)
  return last + 1
end

-- Just count from 1.
return function()
  return count, nil, 0
end
