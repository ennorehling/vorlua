-- user defined functions

local self = {}

local function get_level(u, skill)
    if u.TALENTE[skill] then
        return tonumber(u.TALENTE[skill]:match(" (%d+)"))
    end
    return 0
end

self.work = function(ctx)
    return 'ARBEITE'
end

self.entertain = function(ctx, ...)
    local level = tonumber(arg[1]) or 1
    local val = get_level(ctx.unit, 'Unterhaltung')
    if val and (val >= level) then
        return 'UNTERHALTE'
    else
        return 'LERNE Unterhaltung'
    end
end

self.new_entertainers = function(ctx)
    local count = ctx.unit.Anzahl * 10
    local maxr = ctx.region.Rekruten
    if count > maxr then count = maxr end
    temp = math.random()
    return {
        'LEHRE TEMP ' .. temp,
        'DEFAULT UNTERHALTE',
        'MACHE TEMP ' .. temp,
        '  LERNE Unterhaltung',
        '  DEFAULT UNTERHALTE',
        'ENDE'
    }
end

local function find_new_monsters(cr, old)
    local monsters = {}
    for _, r in ipairs(cr.REGION) do
        if r.EINHEIT then
            for i, u in ipairs(r.EINHEIT) do
                if u.Partei == 666 then
                    local no = u.keys[1]
                    monsters[no] = {
                        ['unit'] = u,
                        ['region'] = r
                    }
                end
            end
        end
    end

    for _, r in ipairs(old.REGION) do
        if r.EINHEIT then
            for i, u in ipairs(r.EINHEIT) do
                if u.Partei == 666 then
                    local no = u.keys[1]
                    monsters[no] = nil
                end
            end
        end
    end
    return monsters
end

local function print_monsters(monsters)
    for k, v in pairs(monsters) do
        local u = v.unit
        local r = v.region
        s = string.format('; %s: %d %s, %s ',
            r.Name or regionname(r),
            u.Anzahl,
            u.Typ,
            unitname(u))
        print(s)
    end
end

local function format_plural(n, s1, s2)
    if n == 1 then
        return s1
    end
    return string.format(s2, n)
end

local function print_low_silver(cr, faction_id)
    for _, r in ipairs(cr.REGION) do
        if r.EINHEIT then
            local m = 0
            local n = 0
            for i, u in ipairs(r.EINHEIT) do
                if u.Partei == nil then
                    -- print('; ' .. unitname(u.Name) .. " ist anonym")
                elseif itoa36(u.Partei) == faction_id then
                    n = n + u.Anzahl
                    if u.GEGENSTAENDE then
                        local s = u.GEGENSTAENDE.Silber
                        if s then m = m + s end
                    end
                end
            end
            if n * 10 > m then
                print(string.format('; %s: %d Silber / %s',
                    r.Name or regionname(r), m,
                    format_plural(n, '1 Person', '%d Personen')))
            end
        end
    end
end

local ignored_messages = {
    725029990, -- X beschwört einen magischen Wind, der die Schiffe über das Wasser treibt.
    1371301106, -- Gebäude funktioniert nicht
    1519194875, -- X erfleht den Segen der Götter des Windes und des Wassers für Y.
    1585159418, -- segnet in einem kurzen Ritual
    1712068859, -- Region verwüstet
    2019496915, -- Unterhalt nicht gezahlt
    2110306401, -- BOTSCHAFT REGION
    2122087327, -- Bauern flohen aus Furcht vor
--[[
    107552268, -- bezahlt den Unterhalt
    170076, -- bezahlt für den Kauf von Luxusgütern
    1549031288, -- kauft Luxusgüter
    771334452, -- verdient
    1235024123, -- erhält X von Y
]]--
    -1
}

local important_messages = {
    829394366, -- X in Y wird durch unzureichende Nahrung geschwächt.
    1158830147, -- X verliert in Y N Personen durch Unterernährung.
    1451290990, -- Die X entdeckt, dass Y Festland ist.
    -1
}

local function in_array(needle, haystack)
    for _, v in ipairs(haystack) do
        if needle == v then
            return true
        end
    end
    return false
end

local function msg_ignored(m)
    return in_array(m.type, ignored_messages)
end

local function msg_show(m)
    return m.command or in_array(m.type, important_messages)
end

local function print_messages(cr, faction_id)
    for _, f in ipairs(cr.PARTEI) do
        if f.MESSAGE then
            for _, m in ipairs(f.MESSAGE) do
                if msg_show(m) then
                    local name = nil
                    if m.unit then
                        local r = nil
                        if m.region then
                            r = cr_get_region(cr, m.region)
                        end
                        u = cr_get_unit(cr, m.unit, r)
                        if r then
                            if not u then
                                u = cr_get_unit(cr, m.unit, nil)
                            end
                        end
                        if u then
                            name = unitname(u)
                        elseif r then
                            name = regionname(r)
                        end
                    end
                    if name then
                        print(string.format('; %s: %s', name, m.rendered))
                    else
                        print(string.format('; %s', m.rendered))
                    end
                end
            end
        end
    end
    for _, r in ipairs(cr.REGION) do
        if r.MESSAGE then
            for _, m in ipairs(r.MESSAGE) do
                if not msg_ignored(m) then
                    local n = r.Name or r.Terrain
                    print(string.format('; %s: %s', regionname(r), m.rendered))
                end
            end
        end
    end
end

self.onload = function(cr, faction)
    local fno = faction.keys[1]
    local turn = cr.VERSION['Runde']
    local name = (turn-1) .. '-' .. itoa36(fno) .. '.cr'
    local old, err = crs.read(name)
    if not old then
        io.stderr:write(name .. '\t' .. err .. '\n')
    else
        local monsters = find_new_monsters(cr, old)
        print_monsters(monsters)
        print_low_silver(cr, faction)
        print_messages(cr, faction)
    end
end

return self
