local metatable <const> = {
  __close = function(self)
    if self.close then
      local _ <close> = self.value
    end
  end,
}

-- Close the value only if the `close` attribute is true.
-- `close` is true by default.
return function(value)
  return setmetatable({
    value = value,
    close = true,
  }, metatable)
end
