crs = require('cr')

local function itoa36(i)
    i = tonumber(i)
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

local function regionname(r)
    name = r.Name or r.Terrain
    return string.format('%s (%d, %d)', name, r.keys[1], r.keys[2])
end

local function get_item(u, name)
    if u.GEGENSTAENDE then
        return u.GEGENSTAENDE[name]
    end
    return 0
end

local function unitname(u)
    return string.format('%s (%s)', u.Name, itoa36(u.keys[1]))
end

local function work_pay(r)
    return r.Lohn or 11
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
                str = string.format('REGION %s,%s', r.keys[1], r.keys[2])
                if (r.keys[3]) then
                    str = str .. ' ' .. r.keys[3]
                end
                str = str .. ' ; ' .. (r.Name or r.Terrain)
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
                        if u.COMMANDS then
                            for _, str in ipairs(u.COMMANDS) do
                                print('    ' .. str)
                            end
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
        s = string.format('; %s: Monster: %s, %d %s',
            r.Name or regionname(r),
            unitname(u),
            u.Anzahl,
            u.Typ)
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
                if itoa36(u.Partei) == faction_id then
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
    end
    template(cr, password)
end

