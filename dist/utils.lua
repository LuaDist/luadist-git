-- System functions

module ("dist.utils", package.seeall)

-- Returns a deep copy of 'table' with reference to the same metadata table.
-- Source: http://lua-users.org/wiki/CopyTable
function deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

-- Return shallow copy of 'a_table', containing only items for which 'predicate_fn' returns true.
function filter_by(predicate_fn, a_table)
    local tbl = {}
    for k, v in pairs(a_table) do
        if predicate_fn(v) == true then tbl[k] = v end
    end
    return tbl
end
