package.path = package.path .. ';./src/?.lua;./src/?/init.lua'

local iter <const> = require 'reiterate'

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
    for i in iter.counter() do
      count = count + i
      if i == 5 then
        break
      end
    end
    assert_eq(count, 1 + 2 + 3 + 4 + 5)
  end
  do
    local count = 0
    for i in iter.take(5, iter.counter()) do
      count = count + i
    end
    assert_eq(count, 1 + 2 + 3 + 4 + 5)
  end
  assert_eq(
    iter.collect(
      iter.map(
        function(i)
          return i, i
        end,
        iter.take(10, iter.counter())
      )
    ),
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
  )
end

function tests.chiterator()
  local closeable = Closeable()

  local iterargs = table.pack(iter.counter())
  iterargs.n = 4
  iterargs[4] = closeable

  local mapped <const> = iter.chiterator(table.unpack(iterargs, 1, iterargs.n))
    :map(function(n) return n * n end)
    :enumerate()
    :filter(function(_, value) return value >= 25 end)
    :take(7)
    :map(function(i, value) return {i * 2, tostring(value)} end)
    :enumerate()
    :collect()

  assert_eq(mapped, {{10,"25"},{12,"36"},{14,"49"},{16,"64"},{18,"81"},{20,"100"},{22,"121"}})
  assert(closeable.closed)

  assert_eq(iter.chiterator(iter.counter())
      :take(4)
      :reduce(function(a, b) return a[1] + b[1] end), 10)

  assert_eq(iter.chiterator.counter()
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

  assert_eq(iter.chiterator.counter()
    :skip(500)
    :take(1337)
    :reduce(function(a, b) return a[1] + b[1] end),
    iter.chiterator(iter.counter())
    :skip(500)
    :take(1337)
    :fold(0, function(accumulator, element) return accumulator + element end))

  assert_eq(iter.chiterator.counter()
    :skip(500)
    :take(1337)
    :reduce(function(a, b) return a[1] + b[1] end), 1562953)

  assert_eq(iter.chiterator(pairs{
    aLpHa = 'FiRsT',
    BeTa = 'sEcOnD',
    gAmMa = 'ThIrD',
  }):map(function(key, value) return key:lower(), value:upper() end)
  :collect(), {
    alpha = 'FIRST',
    beta = 'SECOND',
    gamma = 'THIRD',
  })

  assert(iter.chiterator(ipairs{'fizz', 'buzz'}):any(function(_, v) return v == 'buzz' end))
  assert(iter.chiterator(ipairs{'buzz', 'buzz'}):any(function(_, v) return v == 'buzz' end))
  assert(not iter.chiterator(ipairs{'fizz', 'fizz'}):any(function(_, v) return v == 'buzz' end))
  assert(not iter.chiterator(ipairs{}):any(function(_, v) return v == 'buzz' end))

  assert(not iter.chiterator(ipairs{'fizz', 'buzz'}):all(function(_, v) return v == 'buzz' end))
  assert(iter.chiterator(ipairs{'buzz', 'buzz'}):all(function(_, v) return v == 'buzz' end))
  assert(not iter.chiterator(ipairs{'fizz', 'fizz'}):all(function(_, v) return v == 'buzz' end))
  assert(iter.chiterator(ipairs{}):all(function(_, v) return v == 'buzz' end))
  assert_eq(iter.chiterator(iter.once(17)):chain(iter.once(24)):chain(iter.once(false)):enumerate():collect(), {17, 24, false})

  do
    local count = 0
    for i in iter.chiterator.counter() do
      count = count + i
      if i >= 5 then
        break
      end
    end
    assert_eq(count, 1 + 2 + 3 + 4 + 5)
  end
  do
    local count = 0
    for i in iter.chiterator.counter():take(5) do
      count = count + i
    end
    assert_eq(count, 1 + 2 + 3 + 4 + 5)
  end

  assert_eq(iter.chiterator.counter()
    :take(10)
    :map(function(i) return i, i end)
    :collect(), { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, })

  assert_eq(iter.chiterator.counter()
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

  assert_eq(iter.chiterator.counter()
    :map(function(i) return i * i end)
    :skip(9)
    :enumerate()
    :map(function(i, v) return 100 - i, v end)
    :take(10)
    :zip(iter.chiterator.counter()
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

  assert_eq(iter.chiterator.counter()
    :map(function(i) return i * i end)
    :skip(9)
    :enumerate()
    :map(function(i, v) return 100 - i, v end)
    :zip(iter.chiterator.counter()
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

  assert_eq(iter.chiterator.counter()
    :skip_while(function(i) return i < 15 end)
    :take_while(function(i) return i < 20 end)
    :enumerate()
    :collect(), {15, 16, 17, 18, 19})
end

function tests.coroutine()
  assert_eq(iter.collect(iter.enumerate(iter.coroutine(yield_all, 'foo', 'bar', 'baz'))), {'foo', 'bar', 'baz'})
  assert_eq(iter.chiterator.coroutine(yield_all, 'foo', 'bar', 'baz'):enumerate():collect(), {'foo', 'bar', 'baz'})
end

function tests.standalone_iterators()
  -- all
  assert(iter.all(function(_, v) return v < 4 end, ipairs{1, 2, 3}))
  assert(not iter.all(function(_, v) return v < 3 end, ipairs{1, 2, 3}))
  assert(iter.all(function() return true end, ipairs{}))

  -- any
  assert(iter.any(function(_, v) return v == 2 end, ipairs{1, 2, 3}))
  assert(not iter.any(function(_, v) return v == 4 end, ipairs{1, 2, 3}))
  assert(not iter.any(function() return true end, ipairs{}))

  -- chain
  do
    local result = {}
    local iter1 = {iter.map(function(_, v) return v end, ipairs{1, 2})}
    local iter2 = {iter.map(function(_, v) return v end, ipairs{3, 4})}
    for v in iter.chain(iter1, iter2) do
      result[#result+1] = v
    end
    assert_eq(result, {1, 2, 3, 4})
  end
  do
    local result = {}
    local iter1 = {iter.map(function(_, v) return v end, ipairs{})}
    local iter2 = {iter.map(function(_, v) return v end, ipairs{3, 4})}
    for v in iter.chain(iter1, iter2) do
      result[#result+1] = v
    end
    assert_eq(result, {3, 4})
  end
  do
    local result = {}
    local iter1 = {iter.map(function(_, v) return v end, ipairs{1, 2})}
    local iter2 = {iter.map(function(_, v) return v end, ipairs{})}
    for v in iter.chain(iter1, iter2) do
      result[#result+1] = v
    end
    assert_eq(result, {1, 2})
  end
  do
    local c1 = Closeable()
    local c2 = Closeable()
    local count1 = table.pack(iter.counter())
    local count2 = table.pack(iter.counter())
    count1[4] = c1
    count1.n = math.max(count1.n, 4)
    count2[4] = c2
    count2.n = math.max(count2.n, 4)
    for _ in iter.chain({iter.take(1, table.unpack(count1, 1, count1.n))}, {iter.take(1, table.unpack(count2, 1, count2.n))}) do end
    assert(c1.closed)
    assert(c2.closed)
  end
  do
    local c1 = FailableCloseable(true)
    local c2 = Closeable()
    local count1 = table.pack(iter.counter())
    local count2 = table.pack(iter.counter())
    count1[4] = c1
    count1.n = math.max(count1.n, 4)
    count2[4] = c2
    count2.n = math.max(count2.n, 4)
    local success, err = pcall(function()
      for _ in iter.chain({iter.take(1, table.unpack(count1, 1, count1.n))}, {iter.take(1, table.unpack(count2, 1, count2.n))}) do end
    end)
    assert(not success)
    assert(c1.closed)
    assert(c2.closed)
  end

  -- count
  assert_eq(iter.count(iter.take(5, iter.counter())), 5)
  assert_eq(iter.count(ipairs{}), 0)

  -- filter
  assert_eq(iter.collect(iter.enumerate(iter.filter(function(i) return i % 2 == 0 end, iter.take(5, iter.counter())))), {2, 4})

  -- fold
  assert_eq(iter.fold(10, function(acc, i) return acc - i end, iter.take(4, iter.counter())), 10 - 1 - 2 - 3 - 4)
  assert_eq(iter.fold('a', function(acc, i) return acc .. i end, iter.map(function(_, v) return v end, ipairs{'b', 'c'})), 'abc')
  assert_eq(iter.fold('init', function() end, ipairs{}), 'init')

  -- reduce
  assert_eq(iter.reduce(function(a, b) return a[1] + b[1] end, iter.take(4, iter.counter())), 10)
  assert_eq(iter.reduce(function() end, iter.take(1, iter.counter())), 1)
  assert_eq(iter.reduce(function() end, ipairs{}), nil)

  -- skip
  assert_eq(iter.collect(iter.enumerate(iter.skip(2, iter.take(5, iter.counter())))), {3, 4, 5})
  assert_eq(iter.collect(iter.enumerate(iter.skip(5, iter.take(5, iter.counter())))), {})
  assert_eq(iter.collect(iter.enumerate(iter.skip(10, iter.take(5, iter.counter())))), {})
  assert_eq(iter.collect(iter.enumerate(iter.skip(0, iter.take(5, iter.counter())))), {1, 2, 3, 4, 5})

  -- skip_while
  assert_eq(iter.collect(iter.enumerate(iter.skip_while(function(i) return i < 3 end, iter.take(5, iter.counter())))), {3, 4, 5})
  assert_eq(iter.collect(iter.enumerate(iter.skip_while(function() return false end, iter.take(5, iter.counter())))), {1, 2, 3, 4, 5})
  assert_eq(iter.collect(iter.enumerate(iter.skip_while(function() return true end, iter.take(5, iter.counter())))), {})

  -- take_while
  assert_eq(iter.collect(iter.enumerate(iter.take_while(function(i) return i < 4 end, iter.counter()))), {1, 2, 3})
  assert_eq(iter.collect(iter.enumerate(iter.take_while(function() return false end, iter.counter()))), {})
  assert_eq(iter.collect(iter.enumerate(iter.take_while(function(i) return i < 10 end, iter.take(5, iter.counter())))), {1, 2, 3, 4, 5})

  -- zip
  do
    local result = {}
    local letters = table.pack(iter.map(function(_, v) return v end, ipairs{'a', 'b', 'c'}))
    for pack1, pack2 in iter.zip({iter.take(3, iter.counter())}, letters) do
      result[#result+1] = {pack1[1], pack2[1]}
    end
    assert_eq(result, {{1, 'a'}, {2, 'b'}, {3, 'c'}})
  end
  do
    local count = 0
    for _ in iter.zip({iter.take(2, iter.counter())}, {ipairs{'a', 'b', 'c', 'd', 'e'}}) do
      count = count + 1
    end
    assert_eq(count, 2)
  end
  do
    local count = 0
    for _ in iter.zip({iter.take(5, iter.counter())}, {ipairs{'a', 'b'}}) do
      count = count + 1
    end
    assert_eq(count, 2)
  end
  do
    local c1 = Closeable()
    local c2 = Closeable()
    local count1 = table.pack(iter.counter())
    local count2 = table.pack(iter.counter())
    count1[4] = c1
    count1.n = math.max(count1.n, 4)
    count2[4] = c2
    count2.n = math.max(count2.n, 4)
    for _ in iter.zip({iter.take(1, table.unpack(count1, 1, count1.n))}, {iter.take(1, table.unpack(count2, 1, count2.n))}) do end
    assert(c1.closed)
    assert(c2.closed)
  end
  do
    local c1 = FailableCloseable(true)
    local c2 = Closeable()
    local count1 = table.pack(iter.counter())
    local count2 = table.pack(iter.counter())
    count1[4] = c1
    count1.n = math.max(count1.n, 4)
    count2[4] = c2
    count2.n = math.max(count2.n, 4)
    local success, err = pcall(function()
      for _ in iter.zip({iter.take(1, table.unpack(count1, 1, count1.n))}, {iter.take(1, table.unpack(count2, 1, count2.n))}) do end
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

