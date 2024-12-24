local Chiterator <const> = require 'iter.chiterator'
local counter <const> = require 'iter.counter'
local take <const> = require 'iter.take'
local once <const> = require 'iter.once'
local coro <const> = require 'iter.coro'
local map <const> = require 'iter.map'
local collect <const> = require 'iter.collect'
local enumerate <const> = require 'iter.enumerate'

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

local tests <const> = setmetatable({}, {
  __newindex = function(table, key, value)
    rawset(table, #table + 1, {name = key, test = value})
  end
})

local function table_len(t)
  local len = 0
  for k in pairs(t) do
    len = len + 1
  end
  return len
end

local function deep_eq(left, right)
  if type(left) ~= type(right) then
    return false
  end
  local type = type(left)
  if type == 'table' then
    if table_len(left) ~= table_len(right) then
      return false
    end
    for key, value in pairs(left) do
      if not deep_eq(value, right[key]) then
        return false
      end
    end
    return true
  else
    return left == right
  end
end

local function inspect(value, indent)
  indent = indent or 0
  if type(value) == 'table' then
    local parts = {'{'}
    for k, v in pairs(value) do
      parts[#parts + 1] = ('%s[%s] = %s'):format((' '):rep(indent + 1), inspect(k, indent + 1), inspect(v, indent + 1))
    end
    parts[#parts + 1] = ('%s}'):format((' '):rep(indent))
    return table.concat(parts, '\n')
  else
    return ('%q'):format(value)
  end
end

local function assert_eq(left, right)
  if not deep_eq(left, right) then
    error(('%s is not the same as %s'):format(inspect(left), inspect(right)), 2)
  end
end

function tests.iterator_methods()
  do
    local count = 0
    for i in counter() do
      count = count + i
      if i == 5 then
        break
      end
    end
    assert_eq(count, 1 + 2 + 3 + 4 + 5)
  end
  do
    local count = 0
    for i in take(5, counter()) do
      count = count + i
    end
    assert_eq(count, 1 + 2 + 3 + 4 + 5)
  end
  assert_eq(
    collect(
      map(
        function(i)
          return i, i
        end,
        take(10, counter())
      )
    ),
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
  )
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

  assert_eq(mapped, {{10,"25"},{12,"36"},{14,"49"},{16,"64"},{18,"81"},{20,"100"},{22,"121"}})
  assert(closeable.closed)

  assert_eq(Chiterator(counter())
      :take(4)
      :reduce(function(a, b) return a[1] + b[1] end), 10)

  assert_eq(Chiterator.counter()
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

  assert_eq(Chiterator.counter()
    :skip(500)
    :take(1337)
    :reduce(function(a, b) return a[1] + b[1] end),
    Chiterator(counter())
    :skip(500)
    :take(1337)
    :fold(0, function(accumulator, element) return accumulator + element end))

  assert_eq(Chiterator.counter()
    :skip(500)
    :take(1337)
    :reduce(function(a, b) return a[1] + b[1] end), 1562953)

  assert_eq(Chiterator(pairs{
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
  assert_eq(Chiterator(once(17)):chain(once(24)):chain(once(false)):enumerate():collect(), {17, 24, false})

  do
    local count = 0
    for i in Chiterator.counter() do
      count = count + i
      if i >= 5 then
        break
      end
    end
    assert_eq(count, 1 + 2 + 3 + 4 + 5)
  end
  do
    local count = 0
    for i in Chiterator.counter():take(5) do
      count = count + i
    end
    assert_eq(count, 1 + 2 + 3 + 4 + 5)
  end

  assert_eq(Chiterator.counter()
    :take(10)
    :map(function(i) return i, i end)
    :collect(), { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, })

  assert_eq(Chiterator.counter()
    :map(function(i) return i * i end)
    :skip(9)
    :enumerate()
    :map(function(i, v) return 100 - i, v end)
    :take(5)
    :collect(), {
      [99] = 10 * 10,
      [98] = 11 * 11,
      [97] = 12 * 12,
      [96] = 13 * 13,
      [95] = 14 * 14,
    })

  assert_eq(Chiterator.counter()
    :map(function(i) return i * i end)
    :skip(9)
    :enumerate()
    :map(function(i, v) return 100 - i, v end)
    :take(10)
    :zip(Chiterator.counter()
      :skip(10)
      :enumerate()
      :take(5))
    :enumerate()
    :map(function(i, k, v) return i, {k, v} end)
    :collect(), {
      {{ 99, 100, n = 2 }, { 1, 11, n = 2 }},
      {{ 98, 121, n = 2 }, { 2, 12, n = 2 }},
      {{ 97, 144, n = 2 }, { 3, 13, n = 2 }},
      {{ 96, 169, n = 2 }, { 4, 14, n = 2 }},
      {{ 95, 196, n = 2 }, { 5, 15, n = 2 }},
    })

  assert_eq(Chiterator.counter()
    :map(function(i) return i * i end)
    :skip(9)
    :enumerate()
    :map(function(i, v) return 100 - i, v end)
    :zip(Chiterator.counter()
      :skip(10)
      :enumerate()
      :take(5))
    :map(function(a, b) return {a, b} end)
    :enumerate()
    :collect(), {
      { { 99, 100, n = 2 }, { 1, 11, n = 2 } },
      { { 98, 121, n = 2 }, { 2, 12, n = 2 } },
      { { 97, 144, n = 2 }, { 3, 13, n = 2 } },
      { { 96, 169, n = 2 }, { 4, 14, n = 2 } },
      { { 95, 196, n = 2 }, { 5, 15, n = 2 } },
    })

  assert_eq(Chiterator.counter()
    :skip_while(function(i) return i < 15 end)
    :take_while(function(i) return i < 20 end)
    :enumerate()
    :collect(), {15, 16, 17, 18, 19})
end

function tests.coro()
  assert_eq(collect(enumerate(coro(yield_all, 'foo', 'bar', 'baz'))), {'foo', 'bar', 'baz'})
  assert_eq(Chiterator.coro(yield_all, 'foo', 'bar', 'baz'):enumerate():collect(), {'foo', 'bar', 'baz'})
end


local function msgh(error)
  return debug.traceback(error, 2)
end

local total = 0
local failures = 0
for i, v in ipairs(tests) do
  total = total + 1
  local success, message = xpcall(v.test, msgh)
  if not success then
    failures = failures + 1
    io.stderr:write('failure in ', v.name, ': ', message, '\n')
  end
end

print(('Tests: %d'):format(total))
print(('Failures: %d'):format(failures))
if failures > 0 then
  os.exit(1)
end

