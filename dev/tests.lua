local tests = require 'testing.tests'
local assert = require 'testing.assert'

local Chiterator <const> = require 'chiterator'
local counter <const> = require 'counter'
local once <const> = require 'once'
local coro <const> = require 'coro'
local collect <const> = require 'collect'
local enumerate <const> = require 'enumerate'

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

-- Just yields each input, returning the last one.
local function yield_all(...)
  local count = select('#', ...)
  for i=1, count - 1 do
    coroutine.yield(select(i, ...))
  end
  if count > 0 then
    return select(count, ...)
  end
end

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

  assert.eq(Chiterator.counter()
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

  assert.eq(Chiterator.counter()
    :skip(500)
    :take(1337)
    :reduce(function(a, b) return a[1] + b[1] end),
    Chiterator(counter())
    :skip(500)
    :take(1337)
    :fold(0, function(accumulator, element) return accumulator + element end))

  assert.eq(Chiterator.counter()
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
  assert.eq(Chiterator(once(17)):chain(once(24)):chain(once(false)):enumerate():collect(), {17, 24, false})
end

function tests.coro()
  assert.eq(collect(enumerate(coro(yield_all, 'foo', 'bar', 'baz'))), {'foo', 'bar', 'baz'})
  assert.eq(Chiterator.coro(yield_all, 'foo', 'bar', 'baz'):enumerate():collect(), {'foo', 'bar', 'baz'})
end
