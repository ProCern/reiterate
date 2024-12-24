local map <const> = require 'iter.map'

-- Return a filter, which will use a function that should return a truthy value
-- to keep values in and a falsey one to filter them out.
return function(filter, ...)
  return map(function(...)
    if filter(...) then
      return ...
    end
  end, ...)
end
