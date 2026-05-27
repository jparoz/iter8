-- Minimal property-based testing helpers for busted.
-- No shrinking: failing counterexamples are reported as-is.

math.randomseed(os.time())

local M = {}

--------------
-- Generators
--------------

local gen = {}
M.gen = gen

-- A boolean.
function gen.bool()
  return function()
    return math.random() < 0.5
  end
end

-- An integer in [-max, max].
function gen.int(max)
  max = max or 100
  return function()
    return math.random(-max, max)
  end
end

-- A non-negative integer in [0, max].
function gen.nat(max)
  max = max or 100
  return function()
    return math.random(0, max)
  end
end

-- A positive integer in [1, max].
function gen.pos(max)
  max = max or 100
  return function()
    return math.random(1, max)
  end
end

-- A list of values drawn from elem_gen, length in [0, max_len].
function gen.list(elem_gen, max_len)
  max_len = max_len or 20
  return function()
    local t = {}
    for _ = 1, math.random(0, max_len) do
      t[#t+1] = elem_gen()
    end
    return t
  end
end

-- A non-empty list drawn from elem_gen.
function gen.nonempty_list(elem_gen, max_len)
  max_len = max_len or 20
  return function()
    local t = {}
    for _ = 1, math.random(1, max_len) do
      t[#t+1] = elem_gen()
    end
    return t
  end
end

-- A single lowercase ASCII character.
function gen.char()
  return function()
    return string.char(math.random(97, 122))
  end
end

------------
-- forall
------------

local function fmt(v)
  if type(v) ~= "table" then
    return tostring(v)
  end
  local parts = {}
  for i, x in ipairs(v) do
    parts[i] = type(x) == "string" and ('"'..x..'"') or tostring(x)
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- Run a property n times, drawing one value per generator.
-- Usage:  forall(n, gen1, gen2, ..., function(v1, v2, ...) ... end)
-- The last argument must be the property function; all preceding
-- arguments (after n) are generators.  Raises a busted-compatible
-- error if the property fails, quoting the counterexample.
function M.forall(n, ...)
  local args = {...}
  local prop = table.remove(args)   -- last arg is the property
  for i = 1, n do
    local inputs = {}
    for _, g in ipairs(args) do inputs[#inputs+1] = g() end
    local ok, err = pcall(prop, table.unpack(inputs))
    if not ok then
      local parts = {}
      for _, v in ipairs(inputs) do parts[#parts+1] = fmt(v) end
      error(string.format(
        "Falsified after %d trial(s). Counterexample: (%s)\n%s",
        i, table.concat(parts, ", "), err
      ), 2)
    end
  end
end

return M
