local function close(value)
  local _ <close> = value
end
---Close an iterator list's iterators in reverse order
---@param list {[integer]: any}[]
---@param from integer
---@param to integer
local function close_list(list, from, to)
  from = from or 1
  to = to or #list
  local failed = false
  local first_error
  for i = from, to do
    local iter_tuple = list[i]
    if iter_tuple then
      local ok, err = pcall(close, iter_tuple[4])
      if not ok and not failed then
        failed = true
        first_error = err
      end
    end
  end

  if failed then
    error(first_error, 2)
  end
end

return close_list
