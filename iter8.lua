-- iter8: Lazy iterator objects

-- TODO: better documentation
-- TODO: type annotations

local M_MT = {}
local M = setmetatable({}, M_MT)

local Iter_MT = {}

-- Holds the methods of Iter objects.
local Iter = setmetatable({}, {
    -- Iter() constructor
    __call = function(_, fn)
        return setmetatable({fn = fn, finished = false}, Iter_MT)
    end,
})

-- Use the type's methods
Iter_MT.__index = Iter

-- Wrap a coroutine
Iter.co = function(fn)
    return Iter(coroutine.wrap(fn))
end

-- Iterator is called (e.g. in a for loop)
Iter_MT.__call = function(self, ...)
    if self.finished then
        error("evaluated an iterator twice")
        return
    end

    local ret = {self.fn(...)}
    if ret[1] ~= nil then
        return table.unpack(ret)
    else
        self.finished = true
    end
end

function Iter:next()
    if self.finished then return end
    return self()
end

------------------
-- Constructors --
------------------

-- M(iter_fn, state, initial, closing)
M_MT.__call = function(_, iter_fn, state, initial, closing)
    local control = initial

    return Iter(function()
        local var = {iter_fn(state, control)}
        control = var[1]
        if control == nil then
            local mt = getmetatable(closing)
            if closing and mt and mt.__close then
                mt.__close()
            end

            return nil
        else
            return table.unpack(var)
        end
    end)
end

function M.range(start, finish, step)
    if not finish then
        finish = start
        start = 1
    end
    step = step or 1

    return Iter.co(function()
        for i = start, finish, step do
            coroutine.yield(i)
        end
    end)
end

-- fn can either return
--      x, seed
-- or return
--      x
-- if x and seed would be the same.
function M.unfold(seed, fn)
    return Iter.co(function()
        while true do
            local x
            x, seed = fn(seed)
            seed = seed or x
            if x == nil then break end
            coroutine.yield(x)
        end
    end)
end

function M.chars(s)
    return Iter.co(function()
        for c in s:gmatch(".") do
            coroutine.yield(c)
        end
    end)
end

function M.keys(t)
    return Iter.co(function()
        for k, _ in pairs(t) do
            coroutine.yield(k)
        end
    end)
end

function M.values(t)
    return Iter.co(function()
        for _, v in pairs(t) do
            coroutine.yield(v)
        end
    end)
end

function M.pairs(t)
    return Iter.co(function()
        for k, v in pairs(t) do
            coroutine.yield(k, v)
        end
    end)
end

function M.ivalues(t)
    return Iter.co(function()
        for _, v in ipairs(t) do
            coroutine.yield(v)
        end
    end)
end

function M.ipairs(t)
    return Iter.co(function()
        for i, v in ipairs(t) do
            coroutine.yield(i, v)
        end
    end)
end

M.table = M.pairs
M.list = M.ivalues

function M.empty()
    return Iter(function() end)
end

function M.once(...)
    local once
    local ret = {...}
    return Iter(function()
        if not once then
            once = true
            return table.unpack(ret)
        end
    end)
end

function M.rep(v)
    return Iter(function() return v end)
end

function M.cycle(iter)
    return Iter.co(function()
        -- Until we exhaust the inner iterator,
        -- yield the iterator's values,
        -- while memoising.
        local memo = {}
        while true do
            local ret = {iter()}
            if ret[1] == nil then break end
            memo[#memo+1] = ret
            coroutine.yield(table.unpack(ret))
        end

        -- Now that we've exhausted the iterator,
        -- repeatedly loop through the memoised results.
        local i = 1
        while true do
            coroutine.yield(table.unpack(memo[i]))

            i = i + 1

            if i > #memo then
                i = 1
            end
        end
    end)
end

------------------
-- Transformers --
------------------
function Iter:map(fn)
    local inner_fn = self.fn
    self.fn = function(...)
        local ret = {inner_fn(...)}
        if ret[1] == nil then return end

        return fn(table.unpack(ret))
    end
    return self
end

-- Calls the given function on each step of the iterator,
-- and otherwise acts as the identity transformation.
function Iter:trace(fn)
    local inner_fn = self.fn
    self.fn = function(...)
        local ret = {inner_fn(...)}
        if ret[1] == nil then return end

        fn(table.unpack(ret))
        return table.unpack(ret)
    end
    return self
end

function Iter:filter(pred)
    return Iter.co(function()
        while true do
            local ret = {self()}
            if ret[1] == nil then return end
            if pred(table.unpack(ret)) then
                coroutine.yield(table.unpack(ret))
            end
        end
    end)
end

function Iter:flatten()
    return Iter.co(function()
        for iter in self do
            while not iter.finished do
                local ret = {iter()}
                if ret[1] ~= nil then
                    coroutine.yield(table.unpack(ret))
                end
            end
        end
    end)
end

function Iter:flatmap(fn)
    return Iter.co(function()
        while not self.finished do
            local ret = {self()}
            if ret[1] == nil then return end

            local iter = fn(table.unpack(ret))
            while not iter.finished do
                local inner_ret = {iter()}
                if inner_ret[1] == nil then break end
                coroutine.yield(table.unpack(inner_ret))
            end

        end
    end)
end

function Iter:take(n)
    return Iter.co(function()
        for _ = 1, n do
            coroutine.yield(self())
        end
    end)
end

function Iter:drop(n)
    return Iter.co(function()
        for _ = 1, n do self() end
        while not self.finished do
            coroutine.yield(self())
        end
    end)
end

function Iter:zip(other)
    return Iter.co(function()
        while (not self.finished) and (not other.finished) do
            local ret1 = {self()}
            local ret2 = {other()}
            if ret1[1] ~= nil and ret2[1] ~= nil then
                -- join the result tables
                for _, val in ipairs(ret2) do
                    ret1[#ret1+1] = val
                end
                coroutine.yield(table.unpack(ret1))
            end
        end
    end)
end

function Iter:zipwith(other, fn)
    return Iter.co(function()
        while (not self.finished) and (not other.finished) do
            local ret1 = {self()}
            local ret2 = {other()}
            if ret1[1] ~= nil and ret2[1] ~= nil then
                -- join the result tables using the given function
                for _, val in ipairs(ret2) do
                    ret1[#ret1+1] = val
                end
                coroutine.yield(fn(table.unpack(ret1)))
            end
        end
    end)
end

function Iter:enumerate()
    return Iter.co(function()
        local i = 1
        while not self.finished do
            local ret = {self()}
            if ret[1] ~= nil then
                coroutine.yield(i, table.unpack(ret))
                i = i + 1
            end
        end
    end)
end

function Iter:chain(other)
    return Iter.co(function()
        while not self.finished do
            local ret = {self()}
            if ret[1] ~= nil then
                coroutine.yield(table.unpack(ret))
            end
        end

        while not other.finished do
            coroutine.yield(other())
        end
    end)
end

-----------------
-- Terminators --
-----------------

-- Do nothing, only for side effects.
function Iter:force()
    ---@diagnostic disable-next-line: empty-block
    for _ in self do end
end

-- Run the given function with each element as an argument,
-- ignoring the results.
function Iter:foreach(fn)
    return self:trace(fn):force()
end

-- Collect into a table (either map-like or list-like)
function Iter:collect()
    local t = {}
    for var1, var2 in self do
        if var2 then -- map-like
            t[var1] = var2
        else -- list-like
            t[#t+1] = var1
        end
    end
    return t
end

function Iter:fold(acc, fn)
    for x in self do
        acc = fn(x, acc)
    end
    return acc
end

function Iter:fold1(fn)
    local acc
    for x in self do
        if acc then
            acc = fn(x, acc)
        else
            acc = x
        end
    end
    return acc
end

function Iter:count()
    return Iter:fold(0, function(_, acc) return acc + 1 end)
end

-- 1-based, i.e. Iter:nth(1) == Iter:first()
function Iter:nth(n)
    local i = 1
    for x in self do
        if i == n then
            return x
        end
        i = i + 1
    end
end

function Iter:last()
    local last
    for x in self do
        last = x
    end
    return last
end


return M
