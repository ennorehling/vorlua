-- break cyclical reference:
local merge_list

local function merge_object(orig, new)
    if not orig then return new end
    for k, v in pairs(new) do
        if k~='keys' and 'table' == type(v) then
            local o = orig[k]
            if v.keys then
                orig[k] = merge_object(o, v)
            else
                orig[k] = merge_list(o, v)
            end
        else
            orig[k] = v
        end
    end
    return orig
end

local function hkey(keys)
    local s = keys[1]
    for i = 2, #keys do
        s = s .. '|' .. keys[i]
    end
    return s
end

local function replace_block(o, r, name)
    if r[name] then
        o[name] = r[name]
    end
end

local function merge_regions(list, new)
    local input = {}
    local ignore = {
        'EINHEIT',
        'SCHIFF',
        'MESSAGE',
        'DURCHREISE',
        'DURCHSCHIFFUNG',
        'visibility',
        'Runde'
    }
    local update = {
        'PREISE',
        'RESOURCE',
        'EFFECTS',
        'GRENZE',
        'BURG'
    }
    for i, o in ipairs(list) do
        local no = hkey(o.keys)
        input[no] = { ['index'] = i, ['value'] = o }
        for _, k in ipairs(ignore) do
            o[k] = nil
        end
    end
    for _, r in ipairs(new) do
        local no = hkey(r.keys)
        local orig = input[no]
        if not orig then
            table.insert(list, r)
        else
            local o = orig.value
            for k, v in pairs(r) do
                if 'table' ~= type(v) then
                    o[k] = v
                end
            end
            for _, k in ipairs(ignore) do
                o[k] = r[k]
            end
            for _, k in ipairs(update) do
                replace_block(o, r, k)
            end
            list[orig.index] = o
        end
    end
    return list
end

merge_list = function(orig, list)
    if not list then return orig end
    if not orig then return list end
    if type(list[1]) == 'table' then
        local hash = {}
        for k, f in ipairs(orig) do
            local no = hkey(f.keys)
            hash[no] = { ['index'] = k, ['f'] = f }
        end
        for _, f in ipairs(list) do
            local no = hkey(f.keys)
            if hash[no] then
                local oh = hash[no]
                orig[oh.index] = merge_object(oh.f, f)
            else
                table.insert(orig, f)
            end
        end
    else
        -- COMMANDS
        return list
    end
    return orig
end

local function merge(orig, cr)
    orig.MESSAGETYPE = nil
    orig.BATTLE = cr.BATTLE
    merge_object(orig.VERSION, cr.VERSION)
    orig.PARTEI = cr.PARTEI
    assert(orig.REGION)
    orig.REGION = merge_regions(orig.REGION, cr.REGION)
    return orig
end

return merge
