local tests = require 'testing.tests'
local assert = require 'testing.assert'

local Chiterator <const> = require 'chiterator'
local counter <const> = require 'counter'

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

function tests.chiterator()
  local closeable = Closeable()

  local iterargs = table.pack(counter())
  iterargs.n = 4
  iterargs[4] = closeable

  local mapped <const> = Chiterator(table.unpack(iterargs, 1, iterargs.n))
    :map(function(n) return n * n end)
    :enumerate()
    :filter(function(_, value) return value >= 25 end)
    :take(7)
    :map(function(i, value) return {i * 2, tostring(value)} end)
    :enumerate()
    :collect()

  assert.eq(mapped, {{10,"25"},{12,"36"},{14,"49"},{16,"64"},{18,"81"},{20,"100"},{22,"121"}})
  assert(closeable.closed)

  assert.eq(Chiterator(counter())
      :take(4)
      :reduce(function(a, b) return a[1] + b[1] end), 10)

  assert.eq(Chiterator(counter())
      :take(5)
      :fold({}, function(accumulator, element)
        accumulator[10 - element] = element * element
        return accumulator
      end),
      {
        [9] = 1,
        [8] = 4,
        [7] = 9,
        [6] = 16,
        [5] = 25,
      })

  assert.eq(Chiterator(counter())
    :skip(500)
    :take(1337)
    :reduce(function(a, b) return a[1] + b[1] end),
    Chiterator(counter())
    :skip(500)
    :take(1337)
    :fold(0, function(accumulator, element) return accumulator + element end))

  assert.eq(Chiterator(counter())
    :skip(500)
    :take(1337)
    :reduce(function(a, b) return a[1] + b[1] end), 1562953)

  assert.eq(Chiterator(pairs{
    aLpHa = 'FiRsT',
    BeTa = 'sEcOnD',
    gAmMa = 'ThIrD',
  }):map(function(key, value) return key:lower(), value:upper() end)
  :collect(), {
    alpha = 'FIRST',
    beta = 'SECOND',
    gamma = 'THIRD',
  })

  assert(Chiterator(ipairs{'fizz', 'buzz'}):any(function(_, v) return v == 'buzz' end))
  assert(Chiterator(ipairs{'buzz', 'buzz'}):any(function(_, v) return v == 'buzz' end))
  assert(not Chiterator(ipairs{'fizz', 'fizz'}):any(function(_, v) return v == 'buzz' end))
  assert(not Chiterator(ipairs{}):any(function(_, v) return v == 'buzz' end))

  assert(not Chiterator(ipairs{'fizz', 'buzz'}):all(function(_, v) return v == 'buzz' end))
  assert(Chiterator(ipairs{'buzz', 'buzz'}):all(function(_, v) return v == 'buzz' end))
  assert(not Chiterator(ipairs{'fizz', 'fizz'}):all(function(_, v) return v == 'buzz' end))
  assert(Chiterator(ipairs{}):all(function(_, v) return v == 'buzz' end))
end
