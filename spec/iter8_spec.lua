local Iter = require "iter8"

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
    for _ in Iter(function() end, {}, nil, closer) do end

    assert.spy(close).was.called(1)
  end)

  it("should error if evaluated twice", function()
    local iter = Iter.range(5)
    assert.has.no.error(function() iter:force() end)
    assert.has   .error(function() iter:force() end, "evaluated an iterator twice")
  end)

end) -- Iterators


describe("Iterator constructor", function()

  describe("Iter(...)", function()

    it("should transparently wrap ipairs", function()
      local t = {3, 6, 2}
      local res1, res2 = {}, {}
      for i, v in ipairs(t) do
        res1[i] = v
      end
      for i, v in Iter(ipairs(t)) do
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
      for i, v in Iter(pairs(t)) do
        res2[i] = v
      end
      assert.are.same(res1, res2)
    end)

  end)

  describe("Iter.range(n)", function()
    it("should generate a range of increasing numbers", function()
      assert.are.same({1, 2, 3, 4, 5}, Iter.range(5):collect())
    end)
    it("should generate a range of decreasing numbers", function()
      assert.are.same({5, 4, 3, 2, 1}, Iter.range(5, 1, -1):collect())
    end)
    it("should generate a range with varied steps", function()
      assert.are.same({1, 4, 7}, Iter.range(1, 8, 3):collect())
    end)
  end)

  describe("Iter.list(t)", function()
    it("should iterate over values in a list", function()
      local t = {2, 3, 5, 7, 11}
      assert.are.same(t, Iter.list(t):collect())
    end)
  end)

  describe("Iter.table(t)", function()
    it("should iterate over values in a map-like table", function()
      local t = {a=3, b=4, c=5}
      assert.are.same(t, Iter.table(t):collect())
    end)
  end)

  describe("Iter.chars(s)", function()
    it("should iterate over characters in a string", function()
      assert.are.same({"h", "e", "l", "l", "o", "!"}, Iter.chars("hello!"):collect())
    end)

    it("should be empty given the empty string", function()
      assert.is_nil(Iter.chars(""):next())
    end)
  end)

  describe("Iter.unfold(seed, fn)", function()
    it("should work with a single return value", function()
      local res = Iter.unfold(5, function(x) return x+1 end):take(4):collect()
      assert.are.same({6, 7, 8, 9}, res)
    end)

    it("should work with two return values", function()
      local res = Iter.unfold(5, function(x) return x, x+1 end):take(4):collect()
      assert.are.same({5, 6, 7, 8}, res)
    end)
  end)

  describe("Iter.rep(v)", function()
    it("should repeat a single value", function()
      local res = Iter.rep(33):take(3):collect()
      assert.are.same({33, 33, 33}, res)
    end)
  end)

  describe("Iter.cycle(iter)", function()
    it("should endlessly cycle the given iterator", function()
      local res = Iter.cycle(Iter.range(7, 5, -1)):take(7):collect()
      assert.are.same({7, 6, 5, 7, 6, 5, 7}, res)
    end)
  end)

end) -- Iterator constructor


describe("Iterator transformer", function()

  describe("iter:map(fn)", function()
    it("should map values using the given function", function()
      local res = Iter.range(5):map(function(x) return x+1 end):collect()
      assert.are.same({2, 3, 4, 5, 6}, res)
    end)
  end)

  describe("iter:filter(pred)", function()
    it("should filter out values which don't satisfy the predicate", function()
      local res = Iter.range(10):filter(function(x) return x%2==0 end):collect()
      assert.are.same({2, 4, 6, 8, 10}, res)
    end)
  end)

  describe("iter:flatten()", function()
    it("should flatten iterators of iterators into a single layer", function()
      local res =
        Iter.range(3)
          :map(function(n) return Iter.range(n, 1, -1) end)
          :flatten()
          :collect()
      assert.are.same({1, 2, 1, 3, 2, 1}, res)
    end)
  end)

  describe("iter:flatmap(fn)", function()
    it("should map an iterator-producing function over an iterator, then flatten the result",
    function()
      local res =
        Iter.range(3)
          :flatmap(function(n) return Iter.range(n, 1, -1) end)
          :collect()
      assert.are.same({1, 2, 1, 3, 2, 1}, res)
    end)

    it("should be equivalent to iter:map(fn):flatten()", function()
      pending("property testing")
    end)
  end)

  describe("iter:trace(fn)", function()
    it("should call the given function for each value and not modify the iterator",
    function()
      local sum = 0
      local add = function(x) sum = sum + x end
      local res = Iter.range(5):trace(add):collect()
      assert.are.same({1, 2, 3, 4, 5}, res)
      assert.are.equal(15, sum)
    end)
  end)

  describe("iter:chain(other)", function()
    it("should return the values of iter, then the values of other",
    function()
      local res = Iter.range(1, 10, 3):chain(Iter.range(3)):collect()
      assert.are.same({1, 4, 7, 10, 1, 2, 3}, res)
    end)
  end)

  describe("iter:take(n)", function()
    it("should take n values, then finish the iterator", function()
      local res = Iter.range(20):take(5):collect()
      assert.are.same({1, 2, 3, 4, 5}, res)
    end)
  end)

  describe("iter:drop(n)", function()
    it("should ignore n values, then continue the iterator", function()
      local res = Iter.range(20):drop(15):collect()
      assert.are.same({16, 17, 18, 19, 20}, res)
    end)
  end)

  describe("iter:enumerate()", function()
    it("should add the iterator value number as an extra iterator value",
    function()
      local res = Iter.range(1, 10, 3):chain(Iter.range(3)):collect()
      assert.are.same({1, 4, 7, 10, 1, 2, 3}, res)
    end)

    it("should be equivalent to Iter.range(math.maxinteger):zip(iter)", function()
      pending("property testing")
    end)
  end)

  describe("iter:zip(other)", function()
    it("should combine the values of two single-item iterators", function()
      local res = Iter.chars("abc"):zip(Iter.range(3, 8)):collect()
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
      Iter.ipairs(t1):zip(Iter.ipairs(t2)):foreach(function(...)
        res[#res+1] = {...}
      end)
      assert.are.same(expected, res)
    end)
  end)

  describe("iter:zipwith(other, fn)", function()
    it("should combine the values of two iterators using the given function",
    function()
      local res = Iter.range(5):zipwith(Iter.range(4, 10, 2), plus):collect()
      assert.are.same({5, 8, 11, 14}, res)
    end)
  end)

end) -- Iterator transformer


describe("Iterator evaluator", function()

  describe("iter:collect()", function()
    it("should collect a single-item iterator into a list-like table",
    function()
      assert.are.same({1, 2, 3, 4, 5}, Iter.range(5):collect())
    end)

    it("should collect a two-item iterator into a map-like table", function()
      assert.are.same({ a = "b" }, Iter.once("a", "b"):collect())
    end)
  end)

  describe("iter:force()", function()
    it("should evaluate the iterator and throw away the result", function()
      local sum = 0
      local add = function(x) sum = sum + x end
      local res = Iter.range(5):trace(add):force()
      assert.is_nil(res)
      assert.are.equal(15, sum)
    end)
  end)

  describe("iter:foreach(fn)", function()
    it("should evaluate an iterator and run the function on each value",
    function()
      local sum = 0
      local add = function(x) sum = sum + x end
      local res = Iter.range(5):foreach(add)
      assert.is_nil(res)
      assert.are.equal(15, sum)
    end)
  end)

  describe("iter:fold(acc, fn)", function()
    it("should fold an iterator into acc, using fn", function()
      local res = Iter.range(5):fold(0, plus)
      assert.are.equal(15, res)
    end)

    it("should fold an empty iterator, returning acc", function()
      local res = Iter.empty():fold(0, plus)
      assert.are.equal(0, res)
    end)
  end)

  describe("iter:fold1(fn)", function()
    it("should fold a non-empty iterator", function()
      local res = Iter.range(5):fold1(plus)
      assert.are.equal(15, res)
    end)

    it("should return nil on an empty iterator", function()
      local res = Iter.empty():fold1(plus)
      assert.is_nil(res)
    end)
  end)

  describe("iter:nth(n)", function()
    it("should return the nth value of an iterator", function()
      local res = Iter.range(1, 20, 3):nth(5)
      assert.are.equal(13, res)
    end)
  end)

  describe("iter:last()", function()
    it("should return the last value of an iterator", function()
      local res = Iter.range(1, 20, 3):last()
      assert.are.equal(19, res)
    end)
  end)

end) -- Iterator evaluator

-- vim: shiftwidth=2
