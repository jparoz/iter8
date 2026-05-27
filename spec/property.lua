-- Minimal property-based testing helpers for busted, with shrinking.
--
-- Generators are callable objects: call them to draw a value, access
-- .shrink(v) to get a list of smaller candidates for that value.
-- forall() draws random inputs, and on failure does a greedy shrink
-- descent before reporting the minimal counterexample.

math.randomseed(os.time())

local M = {}

-----------------------------
-- Internal shrink helpers
-----------------------------

-- Returns candidates between n and target via repeated bisection.
-- Converges toward target; always includes target in the result.
local function shrink_toward(n, target)
  if n == target then return {} end
  local s, x = {}, n
  while x ~= target do
    local mid = target + math.floor((x - target) / 2)
    if mid == x then
      s[#s+1] = target   -- floor can stall on ±1; add target explicitly
      break
    end
    x = mid
    s[#s+1] = x
  end
  return s
end

-- Returns a list of structurally and element-wise smaller candidates
-- for a list t.  shrink_elem may be nil (no element shrinking).
local function shrink_list(t, shrink_elem)
  local s = {}
  -- Structural: drop each element in turn
  for i = 1, #t do
    local c = {}
    for j = 1, #t do if j ~= i then c[#c+1] = t[j] end end
    s[#s+1] = c
  end
  -- Structural: keep only first half
  if #t > 1 then
    s[#s+1] = {table.unpack(t, 1, math.floor(#t / 2))}
  end
  -- Element-wise: shrink one element at a time
  if shrink_elem then
    for i = 1, #t do
      for _, sv in ipairs(shrink_elem(t[i])) do
        local c = {table.unpack(t)}
        c[i] = sv
        s[#s+1] = c
      end
    end
  end
  return s
end

-----------------------------
-- Generator constructor
-----------------------------

-- Wraps a sampling function and a shrink function into a callable
-- object.  g() draws a value; g.shrink(v) returns smaller candidates.
local function make_gen(next_fn, shrink_fn)
  return setmetatable(
    { shrink = shrink_fn or function() return {} end },
    { __call = function() return next_fn() end }
  )
end

-----------------------------
-- Public generators
-----------------------------

local gen = {}
M.gen = gen

function gen.bool()
  return make_gen(
    function() return math.random() < 0.5 end,
    function(b) return b and {false} or {} end
  )
end

-- Integer in [-max, max], shrinks toward 0.
function gen.int(max)
  max = max or 100
  return make_gen(
    function() return math.random(-max, max) end,
    function(n) return shrink_toward(n, 0) end
  )
end

-- Non-negative integer in [0, max], shrinks toward 0.
function gen.nat(max)
  max = max or 100
  return make_gen(
    function() return math.random(0, max) end,
    function(n) return shrink_toward(n, 0) end
  )
end

-- Positive integer in [1, max], shrinks toward 1.
function gen.pos(max)
  max = max or 100
  return make_gen(
    function() return math.random(1, max) end,
    function(n) return shrink_toward(n, 1) end
  )
end

-- List of values from elem_gen, length in [0, max_len].
-- Shrinks by dropping elements, halving, and shrinking each element.
function gen.list(elem_gen, max_len)
  max_len = max_len or 20
  return make_gen(
    function()
      local t = {}
      for _ = 1, math.random(0, max_len) do t[#t+1] = elem_gen() end
      return t
    end,
    function(t) return shrink_list(t, elem_gen.shrink) end
  )
end

-- Non-empty list from elem_gen.
-- Shrinks like gen.list but never produces an empty list.
function gen.nonempty_list(elem_gen, max_len)
  max_len = max_len or 20
  return make_gen(
    function()
      local t = {}
      for _ = 1, math.random(1, max_len) do t[#t+1] = elem_gen() end
      return t
    end,
    function(t)
      local s = {}
      if #t > 1 then
        for i = 1, #t do          -- drop one element (safe: #t-1 >= 1)
          local c = {}
          for j = 1, #t do if j ~= i then c[#c+1] = t[j] end end
          s[#s+1] = c
        end
        local half = math.floor(#t / 2)
        if half >= 1 then s[#s+1] = {table.unpack(t, 1, half)} end
      end
      if elem_gen.shrink then
        for i = 1, #t do
          for _, sv in ipairs(elem_gen.shrink(t[i])) do
            local c = {table.unpack(t)}
            c[i] = sv
            s[#s+1] = c
          end
        end
      end
      return s
    end
  )
end

-- Single lowercase ASCII character, shrinks toward 'a'.
function gen.char()
  return make_gen(
    function() return string.char(math.random(97, 122)) end,
    function(c) return c == "a" and {} or {"a"} end
  )
end

-----------------------------
-- Shrink inputs
-----------------------------

-- Given a failing input tuple, greedily minimise it: cycle through
-- each generator dimension, replacing the current best value with the
-- first smaller candidate that still falsifies the property.
-- Repeats until no dimension can be reduced further.
local function minimise(inputs, gens, prop)
  local best = {table.unpack(inputs)}
  local changed = true
  while changed do
    changed = false
    for i, g in ipairs(gens) do
      for _, candidate in ipairs(g.shrink(best[i])) do
        local trial = {table.unpack(best)}
        trial[i] = candidate
        if not pcall(prop, table.unpack(trial)) then
          best[i] = candidate
          changed  = true
          break
        end
      end
    end
  end
  return best
end

-----------------------------
-- Formatting
-----------------------------

local function fmt(v)
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for i, x in ipairs(v) do
    parts[i] = type(x) == "string" and ('"'..x..'"') or tostring(x)
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

-----------------------------
-- forall
-----------------------------

-- Run a property n times, drawing one value per generator.
-- Usage:  forall(n, gen1, gen2, ..., function(v1, v2, ...) ... end)
-- On failure, shrinks each dimension independently then reports the
-- minimal counterexample together with the falsifying assertion.
function M.forall(n, ...)
  local args = {...}
  local prop  = table.remove(args)   -- last arg is the property
  for i = 1, n do
    local inputs = {}
    for _, g in ipairs(args) do inputs[#inputs+1] = g() end
    local ok, err = pcall(prop, table.unpack(inputs))
    if not ok then
      local best = minimise(inputs, args, prop)
      -- Re-run on the minimal input to get a clean error message.
      local _, min_err = pcall(prop, table.unpack(best))
      local parts = {}
      for _, v in ipairs(best) do parts[#parts+1] = fmt(v) end
      error(string.format(
        "Falsified after %d trial(s). Shrunk counterexample: (%s)\n%s",
        i, table.concat(parts, ", "), min_err or err
      ), 2)
    end
  end
end

return M
