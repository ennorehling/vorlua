local mod = {}

local function dump_table(tbl, indent)
    indent = indent or '- '
    for k,v in pairs(tbl) do
        if type(v) == 'table' then
            print(indent .. k .. ':')
            dump_table(v, '  ' .. indent)
        else
          print(indent .. k .. ': ' .. v)
        end
    end
end

local clone -- cyclical dependency

local function table_clone(tbl)
    if #tbl == 0 then
        local c = {}
        for k, v in pairs(tbl) do
            c[k] = clone(v)
        end
        return c
    end
    return {unpack(tbl)}
end

clone = function(org)
    if 'table' == type(org) then
        return table_clone(org)
    end
    return org
end

local function filter_region(r)
    local attrs = { 'id', 'Terrain', 'Name', 'Beschr', 'keys' }
    local c = {}
    for _, v in ipairs(attrs) do
        if r[v] then
            c[v] = clone(r[v])
        end
    end
    return c
end

function mod.filter(cr)
    local result = {}
    result.VERSION = table_clone(cr.VERSION)
    
    local regions = {}
    for _, r in ipairs(cr.REGION) do
        table.insert(regions, filter_region(r))
    end
    result.REGION = regions

    return result
end

return mod
