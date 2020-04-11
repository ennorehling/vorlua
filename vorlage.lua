crs = require 'cr'
user = require 'user'

-- BEGIN exports
-- TODO: move exports to a separate library file

function itoa36(x)
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

-- END exports

local function is_function(var)
    return type(var) == 'function'
end

local function factionname(f)
    return string.format('%s (%s)', f.Parteiname, itoa36(f.keys[1]))
end

local function regionname(r)
    name = r.Name or r.Terrain
    return string.format('%s (%d,%d)', name, r.keys[1], r.keys[2])
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

local function indent(s)
    return '    ' .. s
end

local function parse_comment(ctx, cmd, ...)
    if cmd == '#call' then
        local fname = arg[1]
        local fun = user[fname]
        if type(fun) == 'function' then
            return fun(ctx, unpack(arg, 2))
        end
    end
    return nil
end

local function print_command(u, str)
    print(indent(str))
    words = {}
    for w in str:gmatch('[^%s]+') do table.insert(words, w) end
    if (words[1]=='!LERNE') then
        skill = words[2]
        if skill == 'AUTO' then skill = words[3] end
        sk = get_skill(u, skill)
        if sk then
            print(indent('; ' .. skill .. ' ' .. sk))
        end
    end
end

local function print_commands(ctx)
    local u = ctx.unit
    local cmds = u.COMMANDS
    if cmds and (#cmds > 0) then
        for _, str in ipairs(cmds) do
            print_command(u, str)
        end
    else
        print(indent('ARBEITEN'))
    end
    print('')
end

local function template(cr, faction, password)
    local fno = faction.keys[1]
    local frace = faction.Typ
    local str = string.format('PARTEI %s "%s"', itoa36(fno), password)
    print(str .. '\n')
    for _, r in ipairs(cr.REGION) do
        local ship, bldg, owner
        if r.EINHEIT then
            local guards = {}
            for _, u in ipairs(r.EINHEIT) do
                if u.Partei ~= fno and u.bewacht then
                    guards[u.Partei] = u
                end
            end
            str = string.format('REGION %s,%s', r.keys[1], r.keys[2])
            str = ';' .. string.rep('-', 72) .. '\n' .. str
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
                    print_commands({['unit'] = u, ['region'] = r})
                end
            end
        end
    end
    print('NAECHSTER')
end

local function process(cr, faction)
    local ctx = {
        ['report'] = cr,
        ['faction'] = faction
    }
    for _, r in ipairs(cr.REGION) do
        ctx.region = r
        if r.EINHEIT then
            for _, u in ipairs(r.EINHEIT) do
                if u.Partei ~= fno then
                    local cmds = u.COMMANDS
                    local result = {}
                    if cmds and (#cmds > 0) then
                        ctx.unit = u
                        for _, str in ipairs(cmds) do
                            local words = {}
                            for w in str:gmatch('[^%s]+') do table.insert(words, w) end
                            if (words[1]=='//') then
                                local cmd = words[2]
                                if cmd:sub(1,1)=='#' then
                                    local s = parse_comment(ctx, cmd, unpack(words, 3))
                                    if s then
                                        if type(s) == 'string' then
                                            table.insert(result, str)
                                            table.insert(result, s)
                                        elseif type(s) == 'table' then
                                            table.insert(result, str)
                                            for _, l in ipairs(s) do
                                                table.insert(result, l)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if #result > 0 then
                        u.COMMANDS = result
                    end
                end
            end
        end
    end
end

local function preprocess(cr, faction)
    local fno = faction.keys[1]
    local ctx = {
        ['report'] = cr,
        ['faction'] = faction
    }
    for _, r in ipairs(cr.REGION) do
        ctx.unit = nil
        ctx.region = r
        if is_function(user.onregion) then 
            user.onregion(ctx)
        end
        if r.EINHEIT then
            for _, u in ipairs(r.EINHEIT) do
                if u.Partei == fno then
                    if is_function(user.onunit) then 
                        user.onunit(ctx)
                    end
                end
            end
        end
    end
end

name = arg[1]
password = arg[2] or 'password'

cr, err = crs.read(name)
if not cr then
    io.stderr:write(name .. '\t' .. err .. '\n')
else
    local faction = nil
    for _, f in ipairs(cr.PARTEI) do
        if f.age then
            faction = f
            break
        end
    end
    if faction then
        if is_function(user.onload) then
            user.onload(cr, faction)
        end
        preprocess(cr, faction)
        process(cr, faction)
        template(cr, faction, password)
    end
end