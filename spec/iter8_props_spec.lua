local Iter8 = require "iter8"
local P     = require "spec.property"
local gen   = P.gen
local forall = P.forall

local N = 200  -- trials per property

-- Shared predicates and helpers
local id           = function(x) return x end
local always_true  = function() return true end
local always_false = function() return false end
local is_even      = function(x) return x % 2 == 0 end

local function tconcat(a, b)
  local r = {}
  for _, v in ipairs(a) do r[#r+1] = v end
  for _, v in ipairs(b) do r[#r+1] = v end
  return r
end


describe("Property: constructors", function()

  describe("Iter8(ipairs(t))", function()
    it("transparently wraps ipairs for any list", function()
      forall(N, gen.list(gen.int()), function(t)
        local r1, r2 = {}, {}
        for i, v in ipairs(t)        do r1[i] = v end
        for i, v in Iter8(ipairs(t)) do r2[i] = v end
        assert.are.same(r1, r2)
      end)
    end)
  end)

  describe("Iter8(pairs(t))", function()
    it("transparently wraps pairs for any table", function()
      forall(N, gen.list(gen.int()), function(t)
        local r1, r2 = {}, {}
        for k, v in pairs(t)        do r1[k] = v end
        for k, v in Iter8(pairs(t)) do r2[k] = v end
        assert.are.same(r1, r2)
      end)
    end)
  end)

end)


describe("Property: count / size laws", function()

  it("count equals length of collected list", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.equal(#t, Iter8.list(t):count())
    end)
  end)

  it("take(n):count() == min(n, #t)", function()
    forall(N, gen.list(gen.int()), gen.nat(30), function(t, n)
      assert.are.equal(math.min(n, #t), Iter8.list(t):take(n):count())
    end)
  end)

  it("drop(n):count() == max(0, #t - n)", function()
    forall(N, gen.list(gen.int()), gen.nat(30), function(t, n)
      assert.are.equal(math.max(0, #t - n), Iter8.list(t):drop(n):count())
    end)
  end)

  it("step_by(n):count() == ceil(#t / n)", function()
    forall(N, gen.list(gen.int()), gen.pos(10), function(t, n)
      local expected = #t == 0 and 0 or math.ceil(#t / n)
      assert.are.equal(expected, Iter8.list(t):step_by(n):count())
    end)
  end)

  it("windows(n):count() == max(0, #t - n + 1)", function()
    forall(N, gen.list(gen.int()), gen.pos(10), function(t, n)
      assert.are.equal(math.max(0, #t - n + 1), Iter8.list(t):windows(n):count())
    end)
  end)

  it("chunks(n):count() == ceil(#t / n)", function()
    forall(N, gen.list(gen.int()), gen.pos(10), function(t, n)
      local expected = #t == 0 and 0 or math.ceil(#t / n)
      assert.are.equal(expected, Iter8.list(t):chunks(n):count())
    end)
  end)

  it("intersperse(v):count() == max(0, 2*#t - 1)", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.equal(math.max(0, 2 * #t - 1), Iter8.list(t):intersperse(0):count())
    end)
  end)

  it("zip(iter2):count() == min(#t1, #t2)", function()
    forall(N, gen.list(gen.int()), gen.list(gen.int()), function(t1, t2)
      assert.are.equal(
        math.min(#t1, #t2),
        Iter8.list(t1):zip(Iter8.list(t2)):count()
      )
    end)
  end)

end)


describe("Property: map", function()

  it("identity law: map(id) == id", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.same(t, Iter8.list(t):map(id):collect())
    end)
  end)

  it("composition law: map(f):map(g) == map(g∘f)", function()
    local f = function(x) return x * 2     end
    local g = function(x) return x + 1     end
    local h = function(x) return g(f(x))   end
    forall(N, gen.list(gen.int()), function(t)
      local r1 = Iter8.list(t):map(f):map(g):collect()
      local r2 = Iter8.list(t):map(h):collect()
      assert.are.same(r1, r2)
    end)
  end)

end)


describe("Property: filter", function()

  it("filter(always_true) is identity", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.same(t, Iter8.list(t):filter(always_true):collect())
    end)
  end)

  it("filter(always_false) is empty", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.same({}, Iter8.list(t):filter(always_false):collect())
    end)
  end)

  it("idempotency: filter(pred):filter(pred) == filter(pred)", function()
    forall(N, gen.list(gen.int()), function(t)
      local r1 = Iter8.list(t):filter(is_even):filter(is_even):collect()
      local r2 = Iter8.list(t):filter(is_even):collect()
      assert.are.same(r1, r2)
    end)
  end)

end)


describe("Property: flatmap", function()

  it("flatmap(fn) == map(fn):flatten()", function()
    local fn = function(x) return Iter8.range(math.abs(x) % 4) end
    forall(N, gen.list(gen.int(10)), function(t)
      local r1 = Iter8.list(t):flatmap(fn):collect()
      local r2 = Iter8.list(t):map(fn):flatten():collect()
      assert.are.same(r1, r2)
    end)
  end)

end)


describe("Property: take / drop", function()

  it("take(n):chain(drop(n)) reconstructs the original", function()
    forall(N, gen.list(gen.int()), gen.nat(25), function(t, n)
      local result = Iter8.list(t):take(n):chain(Iter8.list(t):drop(n)):collect()
      assert.are.same(t, result)
    end)
  end)

end)


describe("Property: enumerate", function()

  it("enumerate equals range(maxint):zip(iter)", function()
    forall(N, gen.list(gen.int()), function(t)
      local r1, r2 = {}, {}
      Iter8.list(t):enumerate():foreach(
        function(i, v) r1[#r1+1] = {i, v} end)
      Iter8.range(math.maxinteger or 2^53):zip(Iter8.list(t)):foreach(
        function(i, v) r2[#r2+1] = {i, v} end)
      assert.are.same(r1, r2)
    end)
  end)

end)


describe("Property: scan", function()

  it("scan's last value equals fold", function()
    local fn = function(acc, x) return acc + x end
    forall(N, gen.nonempty_list(gen.int()), function(t)
      assert.are.equal(
        Iter8.list(t):fold(0, fn),
        Iter8.list(t):scan(0, fn):last()
      )
    end)
  end)

end)


describe("Property: chunks", function()

  it("chunks(n) then flatten reconstructs the original", function()
    forall(N, gen.list(gen.int()), gen.pos(10), function(t, n)
      local result = Iter8.list(t):chunks(n):flatmap(Iter8.list):collect()
      assert.are.same(t, result)
    end)
  end)

end)


describe("Property: step_by", function()

  it("step_by(1) is identity", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.same(t, Iter8.list(t):step_by(1):collect())
    end)
  end)

end)


describe("Property: intersperse + concat", function()

  it("intersperse(sep):concat() == concat(sep)", function()
    forall(N, gen.list(gen.char(), 15), gen.char(), function(t, sep)
      assert.are.equal(
        Iter8.list(t):intersperse(sep):concat(),
        Iter8.list(t):concat(sep)
      )
    end)
  end)

end)


describe("Property: any / all", function()

  it("any(pred) == not all(not pred)", function()
    forall(N, gen.list(gen.int()), function(t)
      local lhs = Iter8.list(t):any(is_even)
      local rhs = not Iter8.list(t):all(function(x) return not is_even(x) end)
      assert.are.equal(lhs, rhs)
    end)
  end)

  it("any(always_true) iff non-empty", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.equal(#t > 0, Iter8.list(t):any(always_true))
    end)
  end)

  it("all(always_true) is always true", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.is_true(Iter8.list(t):all(always_true))
    end)
  end)

  it("all(always_false) iff empty", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.equal(#t == 0, Iter8.list(t):all(always_false))
    end)
  end)

end)


describe("Property: takewhile / dropwhile", function()

  it("takewhile + dropwhile reconstruct the original", function()
    forall(N, gen.list(gen.int()), function(t)
      local taken   = Iter8.list(t):takewhile(is_even):collect()
      local dropped = Iter8.list(t):dropwhile(is_even):collect()
      assert.are.same(t, tconcat(taken, dropped))
    end)
  end)

  it("takewhile(always_true) is identity", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.same(t, Iter8.list(t):takewhile(always_true):collect())
    end)
  end)

  it("takewhile(always_false) is empty", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.same({}, Iter8.list(t):takewhile(always_false):collect())
    end)
  end)

  it("dropwhile(always_true) is empty", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.same({}, Iter8.list(t):dropwhile(always_true):collect())
    end)
  end)

  it("dropwhile(always_false) is identity", function()
    forall(N, gen.list(gen.int()), function(t)
      assert.are.same(t, Iter8.list(t):dropwhile(always_false):collect())
    end)
  end)

end)
