local function once(value, control)
  if control == nil then
    return value
  end
end

-- Just gives the supplied value once.
return function(value)
  return once, value
end
