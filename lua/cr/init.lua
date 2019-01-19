crmerge = require('cr.crmerge')

local function dump_table(tbl, indent)
    indent = indent or '- '
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            print(indent .. k .. ':')
            dump_table(v, '  ' .. indent)
        else
          print(indent .. k .. ': ' .. v)
        end
    end
end

function find_region_id(cr, id)
    for _, r in ipairs(cr.REGION) do
        if r.id == id then
            return r
        end
    end
    return nil
end

function find_region(cr, x, y, z)
    if 'table' == type(cr.REGION) then
        for _, r in ipairs(cr.REGION) do
            if r.keys[1] == x and r.keys[2] == y then
                if not z or r.keys[3] == z then
                    return r
                end
            end
        end
    end
    return nil
end

local block_write -- forward define for circular recursion

local function skill_days(level)
    return 30 * ((level + 1) * level / 2);
end

local function tbl_write(file, tbl, name, recursive)
    str = name
    if tbl.keys then
        for _, v in ipairs(tbl.keys) do
            str = str .. ' ' .. v
        end
    end
    file:write(str .. '\n')

    -- first, write all attributes
    if 'TALENTE' == name then
        for k, v in pairs(tbl) do
            d = skill_days(v)
            file:write(d .. ' ' .. v .. ';' .. k .. '\n');
        end
    else
        for k, v in pairs(tbl) do
            t = type(v)
            if 'string' == t then
                file:write('"' .. v .. '";' .. k .. '\n');
            elseif 'number' == t then
                file:write(v .. ';' .. k .. '\n');
            else
                assert('table' == t)
            end
        end
    end
    -- next, write all non-sequence blocks (i.e. PREISE)
    if recursive then
        for k, v in pairs(tbl) do
            if 'keys' ~= k and 'table' == type(v) and #v == 0 then
                tbl_write(file, v, k, true)
            end
        end
        for k, v in pairs(tbl) do
            if 'keys' ~= k and 'table' == type(v) and #v ~= 0 then
                block_write(file, v, k, true)
            end
        end
    end
end

-- sequence of strings, i.e. COMMANDS block
local function strings_write(file, seq, name)
    file:write(name .. '\n')
    for k, v in ipairs(seq) do
        file:write('"' .. v .. '"\n')
    end
    return
end

block_write = function(file, block, name, recursive)
    recursive = recursive or false
    if #block > 0 then
        -- block contains a sequence
        if 'string' == type(block[1]) then
            -- sequence of strings
            strings_write(file, block, name)
        else
            -- sequence of blocks
            for _, child in ipairs(block) do
                tbl_write(file, child, name, recursive)
            end
        end
    else 
        -- single block
        tbl_write(file, block, name, recursive)
    end
end

local function write(cr, filename)
    file, err = io.open(filename, "w")
    if not file then
        return nil, err
    end
    -- always write the VERSION block first
    tbl_write(file, cr.VERSION, 'VERSION', false)
    for _, key in ipairs({'PARTEI', 'REGION', 'MESSAGETYPE'}) do
        if cr[key] then
            for _, v in ipairs(cr[key]) do
                block_write(file, v, key, true)
            end
        end
    end
    file:close()
    return cr
end

local function move(cr, delta_x, delta_y, z)
    z = z or 0
    for _, r in ipairs(cr.REGION) do
        local rz = r.keys[3]
        if not rz or z == rz then
            r.keys[1] = r.keys[1] + delta_x
            r.keys[2] = r.keys[2] + delta_y
        end
    end
    return cr
end

local function filter_tags(el, tags)
    local keys = {}
    for k, v in pairs(el) do
        for _, pat in ipairs(tags) do
            if pat == k or string.match(k, pat) == k then v = nil end
        end
        if v and 'table' ~= type(v) then
            table.insert(keys, k)
        end
    end
    for _, k in ipairs(keys) do
        el[k] = nil
    end
end

local function filter_element(el, filter)
    if filter.elements then
        for k, v in pairs(el) do
            if k ~= 'keys' and 'table' == type(v) then
                local f = filter.elements[k]
                if f then
                    if #v == 0 then
                        -- single element, e.g. VERSION
                        filter_element(v, f)
                    else
                        -- sequence, e.g. REGION
                        for i, e in ipairs(v) do
                            filter_element(e, f)
                        end
                    end
                else
                    el[k] = nil
                end
            end
        end
    end
    if filter.tags then
        filter_tags(el, filter.tags)
    end
end

local map_filter = {
    ['elements'] = {
        ['VERSION'] = {},
        ['REGION'] = {
            ['tags'] = { 'id', 'Terrain', 'Name', 'Beschr', 'keys' },
            ['elements'] = {}
        }
    }
}

local function filter(cr, filter)
    filter = filter or map_filter
    filter_element(cr, filter)
end

local function find_offset(from, cr)
    for _, r in ipairs(from.REGION) do
        local o = crs.find_region_id(cr, r.id)
        if o then
            return o.keys[1] - r.keys[1], o.keys[2] - r.keys[2]
        end
    end
    return nil, nil
end

local function status(cr)
    for k, v in pairs(cr) do
        if 'table' == type(v) then
            if #v > 0 then
                print(#v .. ' ' .. k)
            elseif v.keys then
                print(k .. ' ' .. hkey(v.keys))
            end
        end
    end
end

return {
    ['read'] = crparse,
    ['write'] = write,
    ['status'] = status,
    ['filter'] = filter,
    ['move'] = move,
    ['merge'] = crmerge,
    ['dump'] = dump_table,
    ['find_offset'] = find_offset,
    ['find_region'] = find_region,
    ['find_region_id'] = find_region_id,
    ['MAP_FILTER'] = map_filter
}