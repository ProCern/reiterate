local sard <const> = require 'sard'
local json <const> = require 'sard.json'

local chiterator <const> = require 'chiterator'
local count <const> = require 'count'


local Closeable = (function()
  local metatable <const> = {
    __close = function(self)
      self.closed = true
    end
  }

  return function()
    return setmetatable({
      closed = false
    }, metatable)
  end
end)()

sard.test('chiterator', function()
  local closeable = Closeable()

  local iterargs = table.pack(count())
  iterargs.n = 4
  iterargs[4] = closeable

  local mapped <const> = chiterator(table.unpack(iterargs, 1, iterargs.n))
    :map(function(n) return n * n end)
    :enumerate()
    :filter(function(_, value) return value >= 25 end)
    :take(7)
    :map(function(i, value) return {i * 2, tostring(value)} end)
    :enumerate()
    :collect()
  assert(json.dump(mapped) == '[[10,"25"],[12,"36"],[14,"49"],[16,"64"],[18,"81"],[20,"100"],[22,"121"]]')
  assert(closeable.closed)
end)
