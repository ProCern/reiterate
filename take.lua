local function take(self, control)
  if self.left > 0 then
    self.left = self.left - 1

    return self.iter(self.state, control)
  end
end

-- Take an incoming iterator that yields only the first n values.
return function(n, iter, state, control, ...)
  local self <const> = {
    iter = iter,
    state = state,
    left = n,
  }
  return take, self, control, ...
end
