crs = require('cr')

local function itoa36(x)
    i = tonumber(x)
    if i <= 0 then return '0' end
    local digits = '0123456789abcdefghijkLmnopqrstuvwxyz'
    local a = ''
    while i > 0 do
        local d = (i % 36) + 1
        c = string.sub(digits, d, d)
        a = c .. a
        i = math.floor(i / 36)
    end
    return a
end


local function factionname(f)
    return string.format('%s (%s)', f.Parteiname, itoa36(f.keys[1]))
end

local function regionname(r)
    name = r.Name or r.Terrain
    return string.format('%s (%d, %d)', name, r.keys[1], r.keys[2])
end

local function cr_get_faction(cr, no)
    for _, f in ipairs(cr.PARTEI) do
        if f.keys[1] == no then
            return f
        end
    end
    return nil
end

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

local function get_item(u, name)
    if u.GEGENSTAENDE then
        return u.GEGENSTAENDE[name]
    end
    return 0
end

local function get_skill(u, name)
    if u.TALENTE then
        return u.TALENTE[name]
    end
    return 0
end

local function unitname(u)
    return string.format('%s (%s)', u.Name, itoa36(u.keys[1]))
end

local function work_pay(r)
    return r.Lohn or 11
end

local function print_command(u, str)
    print('    ' .. str)
    words = {}
    for w in str:gmatch('[^%s]+') do table.insert(words, w) end
    if (words[1]=='!LERNE') then
        skill = words[2]
        if skill == 'AUTO' then skill = words[3] end
        sk = get_skill(u, skill)
        if sk then
            print('    ; ' .. skill .. ' ' .. sk)
        end
    end
end

local function template(cr, password)
    local fno = nil
    local frace = nil
    for _, f in ipairs(cr.PARTEI) do
        if f.age then
            fno = f.keys[1]
            frace = f.Typ
            break
        end
    end
    if fno then
        local str = string.format('PARTEI %s "%s"', itoa36(fno), password)
        print(str .. '\n')
        for _, r in ipairs(cr.REGION) do
            local ship, bldg, owner
            if r.EINHEIT then
                local guards = {}
                for _, u in ipairs(r.EINHEIT) do
                    if u.Partei~=fno and u.bewacht then
                        guards[u.Partei] = u
                    end
                end
                str = '; ------------------------------------------------------------------------\n' .. string.format('REGION %s,%s', r.keys[1], r.keys[2])
                if (r.keys[3]) then
                    str = str .. ' ' .. r.keys[3]
                end
                str = str .. ' ; ' .. (r.Name or r.Terrain)
                for k, u in pairs(guards) do
                    local f = cr_get_faction(cr, k)
                    str = str .. '\n' .. '; bewacht von ' .. factionname(f)
                end
                for _, u in ipairs(r.EINHEIT) do
                    if u.Schiff then
                        owner = u.Schiff ~= ship
                    elseif u.Burg then
                        owner = u.Burg ~= bldg
                    end
                    ship = u.Schiff
                    bldg = u.Burg
                    if u.Partei == fno then
                        if str then
                            print(str)
                            print('; ECheck Lohn ' ..  work_pay(r) - 1 .. '\n')
                        end
                        str = string.format('EINHEIT %s;    %s',
                            itoa36(u.keys[1]), u.Name)
                        str = str .. ' [' .. u.Anzahl
                        local wealth = get_item(u, 'Silber') or 0
                        str = str .. ',' .. wealth .. '$'
                        if u.Typ ~= frace then
                            str = str .. ',I'
                        end
                        if ship then
                            if owner then
                                str = str .. ',S'
                            else
                                str = str .. ',s'
                            end
                            str = str .. itoa36(ship)
                        end
                        str = str .. ']'
                        print(str)
                        if u.privat then
                            print('; ' .. u.privat)
                        end
                        cmds = u.COMMANDS
                        if cmds and (#cmds > 0) then
                            for _, str in ipairs(cmds) do
                                print_command(u, str)
                            end
                        else
                            print('    ARBEITEN')
                        end
                        print('')
                        str = nil
                    end
                end
            end
        end
        print('NAECHSTER')
    end
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

local ignored_types = {
    1371301106, -- Gebäude funktioniert nicht
    2019496915, -- Unterhalt nicht gezahlt
    2110306401, -- BOTSCHAFT REGION
    1712068859, -- Region verwüstet
    2122087327, -- Bauern flohen aus Furcht vor
    1585159418, -- segnet in einem kurzen Ritual
--[[
    107552268, -- bezahlt den Unterhalt
    170076, -- bezahlt für den Kauf von Luxusgütern
    1549031288, -- kauft Luxusgüter
    771334452, -- verdient
    1235024123, -- erhält X von Y
]]--
    -1
}

local function msg_ignored(m)
    for _, v in ipairs(ignored_types) do
        if m.type == v then return true end
    end
    return false
end

local function print_messages(cr, faction_id)
    for _, f in ipairs(cr.PARTEI) do
        if f.MESSAGE then
            for _, m in ipairs(f.MESSAGE) do
                if m.command then
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

turn = arg[1]
faction = arg[2] or 'enno'
password = arg[3] or 'password'

name = turn .. '-' .. faction .. '.cr'
cr, err = crs.read(name)
if not cr then
    print(name, err)
else
    name = (turn-1) .. '-' .. faction .. '.cr'
    old, err = crs.read(name)
    if not old then
        print(name, err)
    else
        local monsters = find_new_monsters(cr, old)
        print_monsters(monsters)
        print_low_silver(cr, faction)
        print_messages(cr, faction)
    end
    template(cr, password)
end

