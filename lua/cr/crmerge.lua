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
    for i, o in ipairs(list) do
        local no = hkey(o.keys)
        input[no] = { ['index'] = i, ['value'] = o }
    end
    for _, r in ipairs(new) do
        local no = hkey(r.keys)
        local orig = input[no]
        if not orig then
            table.insert(list, r)
        else
            local o = orig.value
            if r.visibility then
                for k, v in pairs(r) do
                    if 'table' ~= type(v) then
                        o[k] = v
                    end
                end
                o.EINHEIT = r.EINHEIT
                o.SCHIFF = r.SCHIFF
                o.MESSAGE = r.MESSAGE
                o.DURCHREISE = r.DURCHREISE
                o.DURCHREISE = r.DURCHSCHIFFUNG
                o.visibility = r.visibility
                replace_block(o, r, 'PREISE')
                replace_block(o, r, 'RESOURCE')
                replace_block(o, r, 'BURG')
                replace_block(o, r, 'GRENZE')
                list[orig.index] = o
            else
                list[orig.index] = r
            end
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
    merge_object(orig.VERSION, cr.VERSION)
    orig.PARTEI = cr.PARTEI
    orig.REGION = merge_regions(orig.REGION, cr.REGION)
    orig.MESSAGETYPE = nil
    return orig
end

return merge
