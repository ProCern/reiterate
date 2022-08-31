local sard <const> = require 'sard'
local json <const> = require 'sard.json'
local cbor <const> = require 'sard.cbor'

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

  assert(chiterator(count())
      :take(4)
      :reduce(function(a, b) return a[1] + b[1] end) == 10)

  assert(cbor.dump(chiterator(count())
      :take(5)
      :fold({}, function(accumulator, element)
        accumulator[10 - element] = element * element
        return accumulator
      end))
      == cbor.dump{
        [9] = 1,
        [8] = 4,
        [7] = 9,
        [6] = 16,
        [5] = 25,
      })

  assert(chiterator(count())
    :skip(500)
    :take(1337)
    :reduce(function(a, b) return a[1] + b[1] end)
    == chiterator(count())
    :skip(500)
    :take(1337)
    :fold(0, function(accumulator, element) return accumulator + element end))

  assert(cbor.dump(chiterator(pairs{
    aLpHa = 'FiRsT',
    BeTa = 'sEcOnD',
    gAmMa = 'ThIrD',
  }):map(function(key, value) return key:lower(), value:upper() end)

  :collect()) == cbor.dump{
    alpha = 'FIRST',
    beta = 'SECOND',
    gamma = 'THIRD',
  })
end)
