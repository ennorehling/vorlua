local function cr_get_region(cr, x, y, z)
    for _, r in ipairs(cr.REGION) do
        if x == r.keys[1] and y == r.keys[2] and z == r.keys[3] then
            return r
        end
    end
    return nil
end

local function cr_get_unit(cr, no, r)
    if r then
        if r.EINHEIT then
            for _, u in ipairs(r.EINHEIT) do
                if u.keys[1] == no then
                    return u
                end
            end
        end
    else
        for _, r in ipairs(cr.REGION) do
            u = cr_get_unit(cr, no, r)
            if u then return u end
        end
    end
    return nil
end

local function cr_get_faction(cr, no)
    for _, f in ipairs(cr.PARTEI) do
        if f.keys[1] == no then
            return f
        end
    end
    return nil
end

local crlib = {
    ['get_unit'] = cr_get_unit,
    ['get_region'] = cr_get_region,
    ['get_faction'] = cr_get_faction
}

return crlib
