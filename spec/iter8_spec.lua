local Iter8 = require "iter8"

-- Helper function
local plus = function(a, b) return a + b end

describe("Iterators", function()
  it("should work with closing values", function()
    local close = spy.new(function() end)
    local closer = setmetatable({}, {
        __close = function(_self, _err)
          return close()
        end
    })

    ---@diagnostic disable-next-line: empty-block
    for _ in Iter8(function() end, {}, nil, closer) do end

    assert.spy(close).was.called(1)
  end)

  it("should error if evaluated twice", function()
    local iter = Iter8.range(5)
    assert.has.no.error(function() iter:force() end)
    assert.has   .error(function() iter:force() end, "evaluated an iterator twice")
  end)

end) -- Iterators


describe("Iterator constructor", function()

  describe("Iter8(...)", function()

    it("should transparently wrap ipairs", function()
      local t = {3, 6, 2}
      local res1, res2 = {}, {}
      for i, v in ipairs(t) do
        res1[i] = v
      end
      for i, v in Iter8(ipairs(t)) do
        res2[i] = v
      end
      assert.are.same(res1, res2)
    end)

    it("should transparently wrap pairs", function()
      local t = {hi = 123, hello = 456}
      local res1, res2 = {}, {}
      for i, v in pairs(t) do
        res1[i] = v
      end
      for i, v in Iter8(pairs(t)) do
        res2[i] = v
      end
      assert.are.same(res1, res2)
    end)

  end)

  describe("Iter8.range(n)", function()
    it("should generate a range of increasing numbers", function()
      assert.are.same({1, 2, 3, 4, 5}, Iter8.range(5):collect())
    end)
    it("should generate a range of decreasing numbers", function()
      assert.are.same({5, 4, 3, 2, 1}, Iter8.range(5, 1, -1):collect())
    end)
    it("should generate a range with varied steps", function()
      assert.are.same({1, 4, 7}, Iter8.range(1, 8, 3):collect())
    end)
    it("should produce a single element when start == finish", function()
      assert.are.same({3}, Iter8.range(3, 3):collect())
    end)
    it("should produce an empty iterator when range is empty", function()
      assert.are.same({}, Iter8.range(5, 1):collect())
    end)
  end)

  describe("Iter8.list(t)", function()
    it("should iterate over values in a list", function()
      local t = {2, 3, 5, 7, 11}
      assert.are.same(t, Iter8.list(t):collect())
    end)
  end)

  describe("Iter8.table(t)", function()
    it("should iterate over keys and values in a map-like table", function()
      local t = {a=3, b=4, c=5}
      assert.are.same(t, Iter8.table(t):collect())
    end)
  end)

  describe("Iter8.keys(t)", function()
    it("should iterate over keys in a map-like table", function()
      local t = {a=3, b=4, c=5}

      local res = Iter8.keys(t):collect()
      table.sort(res)
      assert.are.same({"a", "b", "c"}, res)
    end)
  end)

  describe("Iter8.values(t)", function()
    it("should iterate over values in a map-like table", function()
      local t = {a=3, b=4, c=5}

      local res = Iter8.values(t):collect()
      table.sort(res)
      assert.are.same({3, 4, 5}, res)
    end)
  end)

  describe("Iter8.matches(s, pat)", function()
    it("should iterate over matches of pat in a string", function()
      assert.are.same({"abc", "def"}, Iter8.matches("abcdef", "..."):collect())
    end)
  end)

  describe("Iter8.chars(s)", function()
    it("should iterate over characters in a string", function()
      assert.are.same({"h", "e", "l", "l", "o", "!"}, Iter8.chars("hello!"):collect())
    end)

    it("should be empty given the empty string", function()
      assert.is_nil(Iter8.chars(""):next())
    end)
  end)

  describe("Iter8.unfold(seed, fn)", function()
    it("should work with a single return value", function()
      local res = Iter8.unfold(5, function(x) return x+1 end):take(4):collect()
      assert.are.same({6, 7, 8, 9}, res)
    end)

    it("should work with two return values", function()
      local res = Iter8.unfold(5, function(x) return x+1, x end):take(4):collect()
      assert.are.same({5, 6, 7, 8}, res)
    end)
  end)

  describe("Iter8.empty()", function()
    it("should immediately return nil", function()
      assert.is_nil(Iter8.empty()())
    end)
  end)

  describe("Iter8.once(...)", function()
    it("should immediately return the given values", function()
      assert.are.same({1, "a", true}, {Iter8.once(1, "a", true)()})
    end)
    it("should return nil when called with no arguments", function()
      assert.is_nil(Iter8.once()())
    end)
  end)

  describe("Iter8.rep(v)", function()
    it("should repeat a single value", function()
      local res = Iter8.rep(33):take(3):collect()
      assert.are.same({33, 33, 33}, res)
    end)
  end)

  describe("Iter8.cycle(iter)", function()
    it("should endlessly cycle the given iterator", function()
      local res = Iter8.cycle(Iter8.range(7, 5, -1)):take(7):collect()
      assert.are.same({7, 6, 5, 7, 6, 5, 7}, res)
    end)
    it("should produce an empty iterator when given an empty iterator", function()
      assert.is_nil(Iter8.cycle(Iter8.empty()):next())
    end)
  end)

  do -- primitive constructors
    local hello = "hello, world"
    local scanned = {
      "he",
      "el",
      "ll",
      "lo",
      "o,",
      ", ",
      " w",
      "wo",
      "or",
      "rl",
      "ld",
    }

    describe("Iter8.fn(fn)", function()
      it("should be usable", function()
        local i = 0
        local fn = function()
          i = i + 1
          if i == #hello then return end
          return hello:sub(i, i+1)
        end

        local res = Iter8.fn(fn):collect()
        assert.are.same(scanned, res)
      end)
    end)

    describe("Iter8.co(fn)", function()
      it("should be usable", function()
        local fn = function()
          for i = 1, #hello-1 do
            coroutine.yield(hello:sub(i, i+1))
          end
        end

        local res = Iter8.co(fn):collect()
        assert.are.same(scanned, res)
      end)
    end)
  end -- primitive constructors

end) -- Iterator constructor


describe("Iterator transformer", function()

  describe("iterator:map(fn)", function()
    it("should map values using fn", function()
      local res = Iter8.range(5):map(function(x) return x+1 end):collect()
      assert.are.same({2, 3, 4, 5, 6}, res)
    end)
    it("should return an empty iterator when given an empty iterator", function()
      assert.are.same({}, Iter8.empty():map(function(x) return x+1 end):collect())
    end)
    it("should pass all multi-value step arguments to fn", function()
      local res = {}
      Iter8.ipairs({10, 20, 30}):map(function(i, v) return i, v * 2 end):foreach(function(i, v)
        res[i] = v
      end)
      assert.are.same({20, 40, 60}, res)
    end)
  end)

  describe("iterator:filter(pred)", function()
    it("should filter out values which don't satisfy the predicate", function()
      local res = Iter8.range(10):filter(function(x) return x%2==0 end):collect()
      assert.are.same({2, 4, 6, 8, 10}, res)
    end)
    it("should return an empty iterator when given an empty iterator", function()
      assert.are.same({}, Iter8.empty():filter(function() return true end):collect())
    end)
    it("should return an empty iterator when the predicate is always false", function()
      assert.are.same({}, Iter8.range(5):filter(function() return false end):collect())
    end)
  end)

  describe("iterator:filtermap(fn)", function()
    it("should map values using fn, while fn returns not-null", function()
      local res = Iter8.range(10):filtermap(function(x)
        if x % 2 == 0 then
          return x + 0.5
        end
      end):collect()
      assert.are.same({2.5, 4.5, 6.5, 8.5, 10.5}, res)
    end)
  end)

  describe("iterator:flatten()", function()
    it("should flatten iterators of iterators into a single layer", function()
      local res =
        Iter8.range(3)
          :map(function(n) return Iter8.range(n, 1, -1) end)
          :flatten()
          :collect()
      assert.are.same({1, 2, 1, 3, 2, 1}, res)
    end)
  end)

  describe("iterator:flatmap(fn)", function()
    it("should map an iterator-producing function over an iterator, then flatten the result",
    function()
      local res =
        Iter8.range(3)
          :flatmap(function(n) return Iter8.range(n, 1, -1) end)
          :collect()
      assert.are.same({1, 2, 1, 3, 2, 1}, res)
    end)

    it("should skip empty inner iterators", function()
      local res =
        Iter8.range(4)
          :flatmap(function(n)
            if n % 2 == 0 then return Iter8.empty() end
            return Iter8.range(n, 1, -1)
          end)
          :collect()
      assert.are.same({1, 3, 2, 1}, res)
    end)
  end)

  describe("iterator:trace(fn)", function()
    it("should call the given function for each value and not modify the iterator",
    function()
      local sum = 0
      local add = function(x) sum = sum + x end
      local res = Iter8.range(5):trace(add):collect()
      assert.are.same({1, 2, 3, 4, 5}, res)
      assert.are.equal(15, sum)
    end)
  end)

  describe("iterator:take(n)", function()
    it("should take n values, then finish the iterator", function()
      local res = Iter8.range(20):take(5):collect()
      assert.are.same({1, 2, 3, 4, 5}, res)
    end)
    it("should return an empty iterator when n == 0", function()
      assert.are.same({}, Iter8.range(20):take(0):collect())
    end)
    it("should return the full iterator when n > its length", function()
      assert.are.same({1, 2, 3}, Iter8.range(3):take(100):collect())
    end)
  end)

  describe("iterator:drop(n)", function()
    it("should ignore n values, then continue the iterator", function()
      local res = Iter8.range(20):drop(15):collect()
      assert.are.same({16, 17, 18, 19, 20}, res)
    end)
    it("should return the full iterator when n == 0", function()
      assert.are.same({1, 2, 3}, Iter8.range(3):drop(0):collect())
    end)
    it("should return an empty iterator when n >= its length", function()
      assert.are.same({}, Iter8.range(3):drop(10):collect())
    end)
  end)

  describe("iterator:zip(other)", function()
    it("should combine the values of two single-item iterators", function()
      local res = Iter8.chars("abc"):zip(Iter8.range(3, 8)):collect()
      assert.are.same({a=3, b=4, c=5}, res)
    end)

    it("should combine the values of two multi-item iterators", function()
      local t1 = { "a", 3, true, "yes" }
      local t2 = { "b", 4, false, "no" }
      local expected = {
        { 1, "a",    1, "b"   },
        { 2, 3,      2, 4     },
        { 3, true,   3, false },
        { 4, "yes",  4, "no"  },
      }

      local res = {}
      Iter8.ipairs(t1):zip(Iter8.ipairs(t2)):foreach(function(...)
        res[#res+1] = {...}
      end)
      assert.are.same(expected, res)
    end)

    it("should combine the values of three or more multi-item iterators",
    function()
      local t1 = { "a", 3, true,  "yes" }
      local t2 = { "b", 4, false, "no" }
      local t3 = { "c", 5, true,  "maybe" }
      local expected = {
        { 1, "a",      1, "b",      1, "c"     },
        { 2, 3,        2, 4,        2, 5       },
        { 3, true,     3, false,    3, true    },
        { 4, "yes",    4, "no",     4, "maybe" },
      }

      local res = {}
      Iter8.ipairs(t1)
        :zip(Iter8.ipairs(t2), Iter8.ipairs(t3))
        :foreach(function(...)
        res[#res+1] = {...}
      end)
      assert.are.same(expected, res)
    end)

    it("should work with infinite iterators", function()
      local res = Iter8.rep(true):zip(Iter8.range(3)):count()
      assert.are.equal(3, res)
    end)
  end)

  describe("iterator:enumerate()", function()
    it("should add the step index as the first value", function()
      local res = Iter8.chars("abc"):enumerate():collect()
      assert.are.same({[1]="a", [2]="b", [3]="c"}, res)
    end)

    it("should restart indexing from 1", function()
      local res = {}
      Iter8.chars("xyz"):enumerate():foreach(function(i, v)
        res[#res+1] = {i, v}
      end)
      assert.are.same({{1,"x"},{2,"y"},{3,"z"}}, res)
    end)

  end)

  describe("iterator:select(index)", function()
    it("should select one column of iterator's return values", function()
      local res =
        Iter8.chars("abc"):zip(Iter8.range(3, 7), Iter8.rep(true))
          :select(2)
          :collect()

      -- Note: {3, 4, 5} not {3, 4, 5, 6, 7}, because #"abc" == 3
      assert.are.same({3, 4, 5}, res)
    end)

    it("should be empty if index is greater than number of return values",
    function()
      assert.are.same({}, Iter8.chars("abc"):select(5):collect())
    end)
  end)

  describe("iterator:chain(other)", function()
    it("should return the values of iter, then the values of other",
    function()
      local res = Iter8.range(1, 10, 3):chain(Iter8.range(3)):collect()
      assert.are.same({1, 4, 7, 10, 1, 2, 3}, res)
    end)
    it("should chain three or more iterators", function()
      local res = Iter8.once(1):chain(Iter8.once(2), Iter8.once(3)):collect()
      assert.are.same({1, 2, 3}, res)
    end)
    it("should skip empty iterators in the chain", function()
      local res = Iter8.range(2):chain(Iter8.empty(), Iter8.range(3, 4)):collect()
      assert.are.same({1, 2, 3, 4}, res)
    end)
  end)

  describe("iterator:takewhile(pred)", function()
    it("should yield elements while the predicate holds", function()
      local res = Iter8.range(10):takewhile(function(x) return x < 5 end):collect()
      assert.are.same({1, 2, 3, 4}, res)
    end)
    it("should return an empty iterator when the first element fails the predicate", function()
      assert.are.same({}, Iter8.range(5):takewhile(function(x) return x > 5 end):collect())
    end)
    it("should return the full iterator when all elements pass", function()
      assert.are.same({1,2,3,4,5}, Iter8.range(5):takewhile(function(x) return x <= 10 end):collect())
    end)
  end)

  describe("iterator:dropwhile(pred)", function()
    it("should drop elements while the predicate holds, then yield the rest", function()
      local res = Iter8.range(10):dropwhile(function(x) return x < 5 end):collect()
      assert.are.same({5, 6, 7, 8, 9, 10}, res)
    end)
    it("should return the full iterator when the first element fails the predicate", function()
      assert.are.same({1,2,3,4,5}, Iter8.range(5):dropwhile(function(x) return x > 10 end):collect())
    end)
    it("should return an empty iterator when all elements pass", function()
      assert.are.same({}, Iter8.range(5):dropwhile(function(x) return x <= 5 end):collect())
    end)
  end)

  describe("iterator:scan(acc, fn)", function()
    it("should yield intermediate accumulator values", function()
      local res = Iter8.range(5):scan(0, function(acc, x) return acc + x end):collect()
      assert.are.same({1, 3, 6, 10, 15}, res)
    end)
    it("should return an empty iterator for an empty source", function()
      assert.are.same({}, Iter8.empty():scan(0, function(acc, x) return acc + x end):collect())
    end)
  end)

  describe("iterator:chunks(n)", function()
    it("should yield tables of n elements", function()
      local res = Iter8.range(6):chunks(2):collect()
      assert.are.same({{1,2},{3,4},{5,6}}, res)
    end)
    it("should yield a shorter final chunk when not evenly divisible", function()
      local res = Iter8.range(7):chunks(3):collect()
      assert.are.same({{1,2,3},{4,5,6},{7}}, res)
    end)
    it("should return an empty iterator for an empty source", function()
      assert.are.same({}, Iter8.empty():chunks(3):collect())
    end)
  end)

  describe("iterator:windows(n)", function()
    it("should yield overlapping windows of n elements", function()
      local res = Iter8.range(5):windows(3):collect()
      assert.are.same({{1,2,3},{2,3,4},{3,4,5}}, res)
    end)
    it("should return an empty iterator when n > length", function()
      assert.are.same({}, Iter8.range(2):windows(3):collect())
    end)
    it("should yield a single window when n == length", function()
      assert.are.same({{1,2,3}}, Iter8.range(3):windows(3):collect())
    end)
  end)

  describe("iterator:step_by(n)", function()
    it("should yield every nth element starting from the first", function()
      assert.are.same({1,4,7,10}, Iter8.range(10):step_by(3):collect())
    end)
    it("should be a no-op when n == 1", function()
      assert.are.same({1,2,3,4,5}, Iter8.range(5):step_by(1):collect())
    end)
    it("should yield only the first element when n > length", function()
      assert.are.same({1}, Iter8.range(3):step_by(10):collect())
    end)
  end)

  describe("iterator:intersperse(sep)", function()
    it("should insert the separator between each element", function()
      assert.are.same({"a",",","b",",","c"}, Iter8.list({"a","b","c"}):intersperse(","):collect())
    end)
    it("should return the single element unchanged for a singleton iterator", function()
      assert.are.same({42}, Iter8.once(42):intersperse(0):collect())
    end)
    it("should return an empty iterator for an empty source", function()
      assert.are.same({}, Iter8.empty():intersperse(0):collect())
    end)
  end)

end) -- Iterator transformer


describe("Iterator evaluator", function()

  describe("iterator:collect()", function()
    it("should collect a single-item iterator into a list-like table",
    function()
      assert.are.same({1, 2, 3, 4, 5}, Iter8.range(5):collect())
    end)

    it("should collect a two-item iterator into a map-like table", function()
      assert.are.same({ a = "b" }, Iter8.once("a", "b"):collect())
    end)

    it("should return an empty table for an empty iterator", function()
      assert.are.same({}, Iter8.empty():collect())
    end)

    it("should silently truncate to first two values when steps have 3+ return values",
    function()
      local iter = Iter8.co(function()
        coroutine.yield("a", 1, true)
        coroutine.yield("b", 2, false)
      end)
      assert.are.same({a=1, b=2}, iter:collect())
    end)
  end)

  describe("iterator:force()", function()
    it("should evaluate the iterator and throw away the result", function()
      local sum = 0
      local add = function(x) sum = sum + x end
      local res = Iter8.range(5):trace(add):force()
      assert.is_nil(res)
      assert.are.equal(15, sum)
    end)
  end)

  describe("iterator:foreach(fn)", function()
    it("should evaluate an iterator and run the function on each value",
    function()
      local sum = 0
      local add = function(x) sum = sum + x end
      local res = Iter8.range(5):foreach(add)
      assert.is_nil(res)
      assert.are.equal(15, sum)
    end)
  end)

  describe("iterator:fold(acc, fn)", function()
    it("should fold an iterator into acc, using fn", function()
      local res = Iter8.range(5):fold(0, plus)
      assert.are.equal(15, res)
    end)

    it("should fold an empty iterator, returning acc", function()
      local res = Iter8.empty():fold(0, plus)
      assert.are.equal(0, res)
    end)

    it("should call fn(acc, x), not fn(x, acc)", function()
      -- 0 - 1 - 2 - 3 - 4 - 5 = -15 only if fold calls fn(acc, x)
      local res = Iter8.range(5):fold(0, function(acc, x) return acc - x end)
      assert.are.equal(-15, res)
    end)
  end)

  describe("iterator:fold1(fn)", function()
    it("should fold a non-empty iterator", function()
      local res = Iter8.range(5):fold1(plus)
      assert.are.equal(15, res)
    end)

    it("should return nil on an empty iterator", function()
      local res = Iter8.empty():fold1(plus)
      assert.is_nil(res)
    end)
  end)

  describe("iterator:count()", function()
    it("should return 3 for a 3-step iterator", function()
      assert.are.equal(3, Iter8.range(3):count())
    end)

    it("should return 0 for the empty iterator", function()
      assert.are.equal(0, Iter8.empty():count())
    end)

  end)

  describe("iterator:sum()", function()
    it("should return the sum of iterator's first values", function()
      assert.are.equal(15, Iter8.range(5):sum())
    end)
    it("should return 0 for an empty iterator", function()
      assert.are.equal(0, Iter8.empty():sum())
    end)
  end)

  describe("iterator:concat(sep)", function()
    it("should concatenate string values", function()
      assert.are.equal("hello", Iter8.chars("hello"):concat())
    end)
    it("should return an empty string for an empty iterator", function()
      assert.are.equal("", Iter8.empty():concat())
    end)
    it("should work on a single-element iterator", function()
      assert.are.equal("x", Iter8.once("x"):concat())
    end)
    it("should join with a separator when given one", function()
      assert.are.equal("a, b, c", Iter8.list({"a","b","c"}):concat(", "))
    end)
    it("should return the sole element without added separator", function()
      assert.are.equal("x", Iter8.once("x"):concat(", "))
    end)
    it("should return an empty string for an empty iterator with a separator", function()
      assert.are.equal("", Iter8.empty():concat(", "))
    end)
  end)

  describe("iterator:nth(n)", function()
    it("should return the nth value of an iterator", function()
      local res = Iter8.range(1, 20, 3):nth(5)
      assert.are.equal(13, res)
    end)

    it("should work with multiple return values", function()
      local res1, res2 = Iter8.range(3, 6):zip(Iter8.chars("abcde")):nth(3)
      assert.are.equal(5, res1)
      assert.are.equal("c", res2)
    end)

    it("should return nil if n > #iterator", function()
      assert.is_nil(Iter8.range(5):nth(10))
    end)
    it("should return nil for an empty iterator", function()
      assert.is_nil(Iter8.empty():nth(1))
    end)
    it("should return the first element when n == 1", function()
      assert.are.equal(7, Iter8.range(7, 10):nth(1))
    end)
  end)

  describe("iterator:last()", function()
    it("should return the last value of an iterator", function()
      local res = Iter8.range(1, 20, 3):last()
      assert.are.equal(19, res)
    end)

    it("should work with multiple return values", function()
      local res1, res2 = Iter8.range(3, 6):zip(Iter8.chars("abcde")):last()
      assert.are.equal(6, res1)
      assert.are.equal("d", res2)
    end)

    it("should return nil for an empty iterator", function()
      assert.is_nil(Iter8.empty():last())
    end)
    it("should return the only element of a single-element iterator", function()
      assert.are.equal(42, Iter8.once(42):last())
    end)
  end)

  describe("iterator:any(pred)", function()
    it("should return true when any element matches", function()
      assert.is_true(Iter8.range(10):any(function(x) return x > 5 end))
    end)
    it("should return false when no elements match", function()
      assert.is_false(Iter8.range(5):any(function(x) return x > 10 end))
    end)
    it("should return false for an empty iterator", function()
      assert.is_false(Iter8.empty():any(function() return true end))
    end)
    it("should short-circuit on the first match", function()
      local count = 0
      Iter8.range(100):any(function(x) count = count + 1; return x == 5 end)
      assert.are.equal(5, count)
    end)
  end)

  describe("iterator:all(pred)", function()
    it("should return true when all elements match", function()
      assert.is_true(Iter8.range(5):all(function(x) return x > 0 end))
    end)
    it("should return false when some element doesn't match", function()
      assert.is_false(Iter8.range(10):all(function(x) return x < 5 end))
    end)
    it("should return true for an empty iterator", function()
      assert.is_true(Iter8.empty():all(function() return false end))
    end)
    it("should short-circuit on the first non-match", function()
      local count = 0
      Iter8.range(100):all(function(x) count = count + 1; return x < 5 end)
      assert.are.equal(5, count)
    end)
  end)

  describe("iterator:find(pred)", function()
    it("should return the first matching element", function()
      assert.are.equal(4, Iter8.range(10):find(function(x) return x % 4 == 0 end))
    end)
    it("should return nil when no element matches", function()
      assert.is_nil(Iter8.range(5):find(function(x) return x > 10 end))
    end)
    it("should return nil for an empty iterator", function()
      assert.is_nil(Iter8.empty():find(function() return true end))
    end)
    it("should stop early", function()
      local count = 0
      Iter8.range(100):find(function(x) count = count + 1; return x == 3 end)
      assert.are.equal(3, count)
    end)
  end)

  describe("iterator:min()", function()
    it("should return the minimum value", function()
      assert.are.equal(1, Iter8.list({3,1,4,1,5,9}):min())
    end)
    it("should return nil for an empty iterator", function()
      assert.is_nil(Iter8.empty():min())
    end)
    it("should handle a single element", function()
      assert.are.equal(7, Iter8.once(7):min())
    end)
  end)

  describe("iterator:max()", function()
    it("should return the maximum value", function()
      assert.are.equal(9, Iter8.list({3,1,4,1,5,9}):max())
    end)
    it("should return nil for an empty iterator", function()
      assert.is_nil(Iter8.empty():max())
    end)
    it("should handle a single element", function()
      assert.are.equal(7, Iter8.once(7):max())
    end)
  end)

end) -- Iterator evaluator

-- vim: shiftwidth=2
