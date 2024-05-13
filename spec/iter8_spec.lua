local Iter8 = require "iter8"

-- TODO: code coverage

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

    it("should transparently wrap ipairs for any table", function()
      pending("property testing")
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

    it("should transparently wrap pairs for any table", function()
      pending("property testing")
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
      local res = Iter8.unfold(5, function(x) return x, x+1 end):take(4):collect()
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
  end)

end) -- Iterator constructor


describe("Iterator transformer", function()

  describe("iterator:map(fn)", function()
    it("should map values using fn", function()
      local res = Iter8.range(5):map(function(x) return x+1 end):collect()
      assert.are.same({2, 3, 4, 5, 6}, res)
    end)
  end)

  describe("iterator:filter(pred)", function()
    it("should filter out values which don't satisfy the predicate", function()
      local res = Iter8.range(10):filter(function(x) return x%2==0 end):collect()
      assert.are.same({2, 4, 6, 8, 10}, res)
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

    it("should be equivalent to iterator:map(fn):flatten()", function()
      pending("property testing")
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

  describe("iterator:chain(other)", function()
    it("should return the values of iter, then the values of other",
    function()
      local res = Iter8.range(1, 10, 3):chain(Iter8.range(3)):collect()
      assert.are.same({1, 4, 7, 10, 1, 2, 3}, res)
    end)
  end)

  describe("iterator:take(n)", function()
    it("should take n values, then finish the iterator", function()
      local res = Iter8.range(20):take(5):collect()
      assert.are.same({1, 2, 3, 4, 5}, res)
    end)
  end)

  describe("iterator:drop(n)", function()
    it("should ignore n values, then continue the iterator", function()
      local res = Iter8.range(20):drop(15):collect()
      assert.are.same({16, 17, 18, 19, 20}, res)
    end)
  end)

  describe("iterator:enumerate()", function()
    it("should add the iterator value number as an extra iterator value",
    function()
      local res = Iter8.range(1, 10, 3):chain(Iter8.range(3)):collect()
      assert.are.same({1, 4, 7, 10, 1, 2, 3}, res)
    end)

    it("should be equivalent to Iter8.range(math.maxinteger):zip(iter)", function()
      pending("property testing")
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

  describe("iterator:zipwith(other, fn)", function()
    it("should combine the values of two iterators using the given function",
    function()
      local res = Iter8.range(5):zipwith(Iter8.range(4, 10, 2), plus):collect()
      assert.are.same({5, 8, 11, 14}, res)
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

    it("should be tested more thoroughly", function()
      pending("property testing")
    end)
  end)

  describe("iterator:nth(n)", function()
    it("should return the nth value of an iterator", function()
      local res = Iter8.range(1, 20, 3):nth(5)
      assert.are.equal(13, res)
    end)
  end)

  describe("iterator:last()", function()
    it("should return the last value of an iterator", function()
      local res = Iter8.range(1, 20, 3):last()
      assert.are.equal(19, res)
    end)
  end)

end) -- Iterator evaluator

-- vim: shiftwidth=2
