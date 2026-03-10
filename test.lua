local Chiterator <const> = require 'reiterate.chiterator'
local counter <const> = require 'reiterate.counter'
local take <const> = require 'reiterate.take'
local once <const> = require 'reiterate.once'
local coro <const> = require 'reiterate.coro'
local map <const> = require 'reiterate.map'
local collect <const> = require 'reiterate.collect'
local enumerate <const> = require 'reiterate.enumerate'
local all <const> = require 'reiterate.all'
local any <const> = require 'reiterate.any'
local chain <const> = require 'reiterate.chain'
local count <const> = require 'reiterate.count'
local filter <const> = require 'reiterate.filter'
local fold <const> = require 'reiterate.fold'
local reduce <const> = require 'reiterate.reduce'
local skip <const> = require 'reiterate.skip'
local skip_while <const> = require 'reiterate.skip_while'
local take_while <const> = require 'reiterate.take_while'
local zip <const> = require 'reiterate.zip'

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

local FailableCloseable = (function()
  local metatable <const> = {
    __close = function(self)
      self.closed = true
      if self.fail then
        error('close failed')
      end
    end
  }

  return function(fail)
    return setmetatable({
      closed = false,
      fail = fail,
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

function tests.standalone_iterators()
  -- all
  assert(all(function(_, v) return v < 4 end, ipairs{1, 2, 3}))
  assert(not all(function(_, v) return v < 3 end, ipairs{1, 2, 3}))
  assert(all(function() return true end, ipairs{}))

  -- any
  assert(any(function(_, v) return v == 2 end, ipairs{1, 2, 3}))
  assert(not any(function(_, v) return v == 4 end, ipairs{1, 2, 3}))
  assert(not any(function() return true end, ipairs{}))

  -- chain
  do
    local result = {}
    local iter1 = {map(function(_, v) return v end, ipairs{1, 2})}
    local iter2 = {map(function(_, v) return v end, ipairs{3, 4})}
    for v in chain(iter1, iter2) do
      result[#result+1] = v
    end
    assert_eq(result, {1, 2, 3, 4})
  end
  do
    local result = {}
    local iter1 = {map(function(_, v) return v end, ipairs{})}
    local iter2 = {map(function(_, v) return v end, ipairs{3, 4})}
    for v in chain(iter1, iter2) do
      result[#result+1] = v
    end
    assert_eq(result, {3, 4})
  end
  do
    local result = {}
    local iter1 = {map(function(_, v) return v end, ipairs{1, 2})}
    local iter2 = {map(function(_, v) return v end, ipairs{})}
    for v in chain(iter1, iter2) do
      result[#result+1] = v
    end
    assert_eq(result, {1, 2})
  end
  do
    local c1 = Closeable()
    local c2 = Closeable()
    local count1 = table.pack(counter())
    local count2 = table.pack(counter())
    count1[4] = c1
    count1.n = math.max(count1.n, 4)
    count2[4] = c2
    count2.n = math.max(count2.n, 4)
    for _ in chain({take(1, table.unpack(count1, 1, count1.n))}, {take(1, table.unpack(count2, 1, count2.n))}) do end
    assert(c1.closed)
    assert(c2.closed)
  end
  do
    local c1 = FailableCloseable(true)
    local c2 = Closeable()
    local count1 = table.pack(counter())
    local count2 = table.pack(counter())
    count1[4] = c1
    count1.n = math.max(count1.n, 4)
    count2[4] = c2
    count2.n = math.max(count2.n, 4)
    local success, err = pcall(function()
      for _ in chain({take(1, table.unpack(count1, 1, count1.n))}, {take(1, table.unpack(count2, 1, count2.n))}) do end
    end)
    assert(not success)
    assert(c1.closed)
    assert(c2.closed)
  end

  -- count
  assert_eq(count(take(5, counter())), 5)
  assert_eq(count(ipairs{}), 0)

  -- filter
  assert_eq(collect(enumerate(filter(function(i) return i % 2 == 0 end, take(5, counter())))), {2, 4})

  -- fold
  assert_eq(fold(10, function(acc, i) return acc - i end, take(4, counter())), 10 - 1 - 2 - 3 - 4)
  assert_eq(fold('a', function(acc, i) return acc .. i end, map(function(_, v) return v end, ipairs{'b', 'c'})), 'abc')
  assert_eq(fold('init', function() end, ipairs{}), 'init')

  -- reduce
  assert_eq(reduce(function(a, b) return a[1] + b[1] end, take(4, counter())), 10)
  assert_eq(reduce(function() end, take(1, counter())), 1)
  assert_eq(reduce(function() end, ipairs{}), nil)

  -- skip
  assert_eq(collect(enumerate(skip(2, take(5, counter())))), {3, 4, 5})
  assert_eq(collect(enumerate(skip(5, take(5, counter())))), {})
  assert_eq(collect(enumerate(skip(10, take(5, counter())))), {})
  assert_eq(collect(enumerate(skip(0, take(5, counter())))), {1, 2, 3, 4, 5})

  -- skip_while
  assert_eq(collect(enumerate(skip_while(function(i) return i < 3 end, take(5, counter())))), {3, 4, 5})
  assert_eq(collect(enumerate(skip_while(function() return false end, take(5, counter())))), {1, 2, 3, 4, 5})
  assert_eq(collect(enumerate(skip_while(function() return true end, take(5, counter())))), {})

  -- take_while
  assert_eq(collect(enumerate(take_while(function(i) return i < 4 end, counter()))), {1, 2, 3})
  assert_eq(collect(enumerate(take_while(function() return false end, counter()))), {})
  assert_eq(collect(enumerate(take_while(function(i) return i < 10 end, take(5, counter())))), {1, 2, 3, 4, 5})

  -- zip
  do
    local result = {}
    local letters = table.pack(map(function(_, v) return v end, ipairs{'a', 'b', 'c'}))
    for pack1, pack2 in zip({take(3, counter())}, letters) do
      result[#result+1] = {pack1[1], pack2[1]}
    end
    assert_eq(result, {{1, 'a'}, {2, 'b'}, {3, 'c'}})
  end
  do
    local count = 0
    for _ in zip({take(2, counter())}, {ipairs{'a', 'b', 'c', 'd', 'e'}}) do
      count = count + 1
    end
    assert_eq(count, 2)
  end
  do
    local count = 0
    for _ in zip({take(5, counter())}, {ipairs{'a', 'b'}}) do
      count = count + 1
    end
    assert_eq(count, 2)
  end
  do
    local c1 = Closeable()
    local c2 = Closeable()
    local count1 = table.pack(counter())
    local count2 = table.pack(counter())
    count1[4] = c1
    count1.n = math.max(count1.n, 4)
    count2[4] = c2
    count2.n = math.max(count2.n, 4)
    for _ in zip({take(1, table.unpack(count1, 1, count1.n))}, {take(1, table.unpack(count2, 1, count2.n))}) do end
    assert(c1.closed)
    assert(c2.closed)
  end
  do
    local c1 = FailableCloseable(true)
    local c2 = Closeable()
    local count1 = table.pack(counter())
    local count2 = table.pack(counter())
    count1[4] = c1
    count1.n = math.max(count1.n, 4)
    count2[4] = c2
    count2.n = math.max(count2.n, 4)
    local success, err = pcall(function()
      for _ in zip({take(1, table.unpack(count1, 1, count1.n))}, {take(1, table.unpack(count2, 1, count2.n))}) do end
    end)
    assert(not success)
    assert(c1.closed)
    assert(c2.closed)
  end
end


local function msgh(error)
  return debug.traceback(error, 2)
end

local total = 0
local failures = 0
for _, v in ipairs(tests) do
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

