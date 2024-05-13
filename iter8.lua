-- iter8: Lazy iterator objects

-- TODO: better documentation
-- TODO: type annotations
-- TODO: README.md

-- Forward declare the private iterator constructors
local mkIter, mkIterCo

------------------
-- Constructors --
------------------

local Iter8_MT = {}

---The main `Iter8` object,
---returned from the call to `require("iter8")`.
---
---When called as a function,
---wraps the return values of
---a for-loop-compatible, Lua-style iterator
---such as `pairs`, `ipairs`, or `string.gmatch`.
---The resulting `iterator` behaves transparently;
---that is, it provides the same results when evaluated
---as if you had directly evaluated the arguments to `Iter8`.
---
---Example:
---```lua
---local iter = Iter8(pairs(t))
---iter = iter:take(3)
---for k, v in iter do
---    process(k, v)
---end
---```
---@overload fun(iter_fn: fun(state: any, control: any), state: any, initial: any, closing: any): iterator
---@class Iter8
local Iter8 = setmetatable({}, Iter8_MT)
Iter8_MT.__call = function(_, iter_fn, state, initial, closing)
    local control = initial

    return mkIter(function()
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

---Iterate over a range of integers.
---`start` and `step` are optional, both defaulting to a value of 1.
---@overload fun(start: integer, finish: integer, step: integer): iterator
---@overload fun(start: integer, finish: integer): iterator
---@overload fun(finish: integer): iterator
function Iter8.range(start, finish, step)
    if not finish then
        finish = start
        start = 1
    end
    step = step or 1

    return mkIterCo(function()
        for i = start, finish, step do
            coroutine.yield(i)
        end
    end)
end

---Generate an `iterator`
---by (unfolding)[https://en.wikipedia.org/wiki/Anamorphism]
---using the given seed value and function.
---
---fn can either return `val, seed` or just `seed`,
---if `val` and `seed` would be the same.
---
---@generic T
---@param seed `T`
---@param fn (fun(seed: T): T) | (fun(seed: T): any, T)
---@return iterator
function Iter8.unfold(seed, fn)
    return mkIterCo(function()
        while true do
            local x
            x, seed = fn(seed)
            seed = seed or x
            if x == nil then break end
            coroutine.yield(x)
        end
    end)
end

---Iterate over matches of the Lua pattern-string `pat` in the string `s`.
---
---Has an alias `Iter8.matches`.
---
---@see Iter8.matches
---
---@param s string
---@param pat string
---@return iterator
function Iter8.gmatch(s, pat)
    return mkIterCo(function()
        for match in s:gmatch(pat) do
            coroutine.yield(match)
        end
    end)
end

---@see Iter8.gmatch
Iter8.matches = Iter8.gmatch

---Iterate over characters in the string `s`.
---
---@param s string
---@return iterator
function Iter8.chars(s)
    return mkIterCo(function()
        for c in s:gmatch(".") do
            coroutine.yield(c)
        end
    end)
end

---Iterate over the keys in the table `t`
---in an arbitrary order (similar to `pairs`).
---
---@see Iter8.values
---@see Iter8.pairs
---
---@param t table
---@return iterator
function Iter8.keys(t)
    return mkIterCo(function()
        for k, _ in pairs(t) do
            coroutine.yield(k)
        end
    end)
end

---Iterate over the values in the table `t`
---in an arbitrary order (similar to `pairs`).
---
---@see Iter8.keys
---@see Iter8.pairs
---@see Iter8.ivalues
---
---@param t table
---@return iterator
function Iter8.values(t)
    return mkIterCo(function()
        for _, v in pairs(t) do
            coroutine.yield(v)
        end
    end)
end

---Iterate over the keys and values in the table `t`
---in an arbitrary order (similar to `pairs`).
---
---Has an alias `Iter8.table`.
---
---* If you just want the values, use `Iter8.values(t)` instead.
---* If you just want the keys, use `Iter8.keys(t)` instead.
---
---@see Iter8.keys
---@see Iter8.values
---@see Iter8.ipairs
---@see Iter8.table
---
---@param t table
---@return iterator
function Iter8.pairs(t)
    return mkIterCo(function()
        for k, v in pairs(t) do
            coroutine.yield(k, v)
        end
    end)
end

---@see Iter8.pairs
Iter8.table = Iter8.pairs

---Iterate over the values in the table `t`
---in increasing order (similar to `ipairs`).
---
---Has an alias `Iter8.list`.
---
---@see Iter8.values
---@see Iter8.pairs
---@see Iter8.list
---
---@param t table
---@return iterator
function Iter8.ivalues(t)
    return mkIterCo(function()
        for _, v in ipairs(t) do
            coroutine.yield(v)
        end
    end)
end

---@see Iter8.ivalues
Iter8.list = Iter8.ivalues

---Iterate over the indices and values in the table `t`
---in increasing order (similar to `ipairs`).
---
---* If you just want the values, use `Iter8.ivalues(t)` instead.
---* If you just want the indices, use `Iter8.range(#t)` instead.
---
---@see Iter8.ivalues
---@see Iter8.range
---@see Iter8.pairs
---
---@param t table
---@return iterator
function Iter8.ipairs(t)
    return mkIterCo(function()
        for i, v in ipairs(t) do
            coroutine.yield(i, v)
        end
    end)
end

---Returns an empty `iterator`.
---
---@return iterator
function Iter8.empty()
    return mkIter(function() end)
end

---Returns an `iterator` which will:
---* on the first iteration, produce all the arguments given to `Iter8.once`;
---* then finish.
---
---@param ... any
---@return iterator
function Iter8.once(...)
    local once = false
    local ret = {...}
    return mkIter(function()
        if not once then
            once = true
            return table.unpack(ret)
        end
    end)
end

---Repeat the given value forever.
---
---The returned `iterator` will never finish.
---
---@param v any
---@return iterator
function Iter8.rep(v)
    return mkIter(function() return v end)
end

---Returns an `iterator` which
---endlessly repeats through the elements of
---the `iterator` given as the argument `iter`.
---
---> [!Note]
---> The repetition is accomplished
---> via memoisation of `iter`'s results;
---> as such,
---> if your `iterator` produces non-deterministic or otherwise changing outputs,
---> you may wish to find another way to achieve this cycling effect.
---
---The returned `iterator` will never finish.
---
---@param iter iterator
---@return iterator
function Iter8.cycle(iter)
    return mkIterCo(function()
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

-------------
-- Methods --
-------------

---This section describes the methods available on `iterator` objects.
---@class iterator
---@field private fn fun(): any
---@field finished boolean
---@operator call:any
local iterator = {}

local iterator_MT = {
    __index = iterator,

    -- For when the iterator is called (e.g. in a for loop)
    __call = function(self)
        if self.finished then
            error("evaluated an iterator twice")
            return
        end

        local ret = {self.fn()}
        if ret[1] ~= nil then
            return table.unpack(ret)
        else
            self.finished = true
        end
    end,
}

---Make an `iterator` from a function.
---@private
---@param fn fun(): any
---@return iterator
function mkIter(fn)
    return setmetatable({fn = fn, finished = false}, iterator_MT)
end

---Make an `iterator` from a coroutine-function.
---@private
---@param fn fun(): any
---@return iterator
function mkIterCo(fn)
    return mkIter(coroutine.wrap(fn))
end

---Return the next value in the `iterator`,
---or `nil` if the `iterator` is finished.
---@return any
function iterator:next()
    if self.finished then return end
    return self()
end

------------------
-- Transformers --
------------------

---Maps each step of the iterator
---by passing the values to `fn`,
---and replacing the values with the return values of `fn`.
---
---@see iterator.flatmap
---@see iterator.filtermap
---@see iterator.trace
---
---@param fn fun(...): any
---@return iterator
function iterator:map(fn)
    local inner_fn = self.fn
    self.fn = function()
        local ret = {inner_fn()}
        if ret[1] == nil then return end

        return fn(table.unpack(ret))
    end
    return self
end

---Calls `fn` on each step of the iterator,
---and returns the iterator unchanged.
---That is,
---`fn` is called on each step of the iterator
---just for its side-effects.
---
---> [!Note]
---> `iterator:trace(fn)` doesn't evaluate the `iterator`,
---> and as such, `fn` will not be called until the `iterator` is evaluated.
---> If you want to evaluate the iterator straight away,
---> use `iterator:foreach(fn)`.
---
---@see iterator.map
---@see iterator.foreach
---
---@param fn fun(...): any
---@return iterator
function iterator:trace(fn)
    local inner_fn = self.fn
    self.fn = function()
        local ret = {inner_fn()}
        if ret[1] == nil then return end

        fn(table.unpack(ret))
        return table.unpack(ret)
    end
    return self
end

---Calls `pred` on each step of the `iterator`,
---and keeps only the steps for which `pred` returns true.
---
---@see iterator.filtermap
---
---@param pred fun(...): boolean
---@return iterator
function iterator:filter(pred)
    return mkIterCo(function()
        while true do
            local ret = {self()}
            if ret[1] == nil then return end
            if pred(table.unpack(ret)) then
                coroutine.yield(table.unpack(ret))
            end
        end
    end)
end

---Maps each step of `iterator`
---by passing the values to `fn`,
---and replacing the values with the return values of `fn`—as long as `fn`
---has a value other than `nil` as its first return value.
---
---@see iterator.filter
---@see iterator.map
---
---@param fn fun(...): any
---@return iterator
function iterator:filtermap(fn)
    return mkIterCo(function()
        while true do
            local ret = {self()}
            if ret[1] == nil then return end

            local res = {fn(table.unpack(ret))}
            if res[1] ~= nil then
                coroutine.yield(table.unpack(res))
            end
        end
    end)
end

---Turns an `iterator` of `iterator`s of values
---into an `iterator` of values.
---
---`flatten` removes exactly one level of nesting.
---
---@see iterator.flatmap
---
---@return iterator
function iterator:flatten()
    return mkIterCo(function()
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

---Maps each step of `iterator`
---by passing the values to `fn`,
---and replacing the values with
---the concatenated results of the `iterator`s returned from `fn`.
---
---`flatmap` removes exactly one level of nesting.
---
---Useful for when you want to use `map`,
---but your mapping function may give more than one result.
---
---@see iterator.flatten
---@see iterator.map
---
---@param fn fun(...): iterator
---@return iterator
function iterator:flatmap(fn)
    return mkIterCo(function()
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

---Yields the first `n` steps of `iterator`,
---then ends the iterator.
---
---If `iterator` yields fewer than `n` steps,
---then the result of `take` will be equivalent to `iterator`.
---
---@see iterator.drop
---
---@param n integer
---@return iterator
function iterator:take(n)
    return mkIterCo(function()
        for _ = 1, n do
            coroutine.yield(self())
        end
    end)
end


---Skips the first `n` steps of `iterator`,
---then yields the rest of the steps of `iterator`.
---
---If `iterator` yields fewer than `n` steps,
---then the result of `drop` will be equivalent to `iterator.empty()`.
---
---@see iterator.take
---
---@param n integer
---@return iterator
function iterator:drop(n)
    return mkIterCo(function()
        for _ = 1, n do self() end
        while not self.finished do
            coroutine.yield(self())
        end
    end)
end

function iterator:zip(other)
    return mkIterCo(function()
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

function iterator:zipwith(other, fn)
    return mkIterCo(function()
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

function iterator:enumerate()
    return mkIterCo(function()
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

function iterator:chain(other)
    return mkIterCo(function()
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

---Do nothing; evaluate the `iterator` only for its side effects.
function iterator:force()
    ---@diagnostic disable-next-line: empty-block
    for _ in self do end
end

---Run the given function with each element as an argument,
---ignoring the results.
function iterator:foreach(fn)
    return self:trace(fn):force()
end

---Collect into a table (either map-like or list-like)
function iterator:collect()
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

function iterator:fold(acc, fn)
    for x in self do
        acc = fn(x, acc)
    end
    return acc
end

function iterator:fold1(fn)
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

function iterator:count()
    return self:fold(0, function(_, acc) return acc + 1 end)
end

---1-based, i.e. iterator:nth(1) == iterator:first()
function iterator:nth(n)
    local i = 1
    for x in self do
        if i == n then
            return x
        end
        i = i + 1
    end
end

function iterator:last()
    local last
    for x in self do
        last = x
    end
    return last
end


return Iter8
