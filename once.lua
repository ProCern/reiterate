local function once(values, control)
  if control == nil then
    return table.unpack(values, 1, values.n)
  end
end

-- Just gives the supplied values once.
return function(...)
  return once, table.pack(...)
end
