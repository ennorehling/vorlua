local mod = {}

function mod.read(filename)
    return crparse(filename)
end

local block_write -- forward define for circular recursion

local function tbl_write(file, tbl, name, recursive)
    str = name
    if tbl.keys then
        for _, v in ipairs(tbl.keys) do
            str = str .. ' ' .. v
        end
    end
    file:write(str .. '\n')

    for k, v in pairs(tbl) do
        t = type(v)
        if 'string' == t then
            file:write('"' .. v .. '";' .. k .. '\n');
        elseif 'number' == t then
            file:write(v .. ';' .. k .. '\n');
        elseif 'table' ~= t then
            print(name, t, v)
        end
    end
    if recursive then
        for k, v in pairs(tbl) do
            if 'keys' ~= k and 'table' == type(v) then
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
            strings_write(file, block, name)
        else
            for _, child in ipairs(block) do
                tbl_write(file, child, name, recursive)
            end
        end
    else 
        tbl_write(file, block, name, recursive)
    end
end

function mod.write(filename, cr)
    file, err = io.open(filename, "w")
    if not file then
        return nil, err
    end
    block_write(file, cr.VERSION, 'VERSION')
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

function mod.move(cr, delta_x, delta_y)
    return cr
end

return mod
