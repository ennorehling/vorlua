-- user defined functions

local crlib = require 'crlib'
local crs = require 'cr'
local alchemy = require 'alchemy'

local RESOURCE_STONE = 221560393
local RESOURCE_IRON = 5478848

local self = {}

local function unescape_spaces(str)
    return string.gsub(str, '~', ' ')
end

local function get_char_at(s, i)
    return string.sub(s, i, i)
end

local function gen_name()
    local vowels = 'aeiouy'
    local consos = 'lmnbgtrws'
    local sy = math.random(2,4)
    local name = ''
    for i = sy,1,-1 do
        local c = get_char_at(consos, math.random(1, string.len(consos)))
        local v = get_char_at(vowels, math.random(1, string.len(vowels)))
        if string.len(name) == 0 then
            c = string.upper(c)
        end
        name = name .. c .. v
    end
    return name
end

local function gen_elf_name()
    return gen_name() .. ' ' .. gen_name()
end

local function get_item(u, name)
    if u.GEGENSTAENDE and u.GEGENSTAENDE[name] then
        return tonumber(u.GEGENSTAENDE[name])
    end
    return 0
end

local function get_level(u, skill)
    if u.TALENTE and u.TALENTE[skill] then
        return tonumber(u.TALENTE[skill]:match(" (%d+)"))
    end
    return 0
end

local function get_effects(u, item)
    if u.EFFECTS then
        for _, line in ipairs(u.EFFECTS) do
            local m = line:match("(%d+) " .. item)
            if m then
                return tonumber(m)
            end
        end
    end
    return 0
end

self.work = function(ctx)
    return 'ARBEITE'
end

self.user = function(ctx, item, per_user)
    local e = get_effects(ctx.unit, item) or 0
    local need = ctx.unit.Anzahl - e
    if need > 0 then
		need = math.ceil(need / (per_user or 1))
		return {
			'; ' .. item .. ": " .. e .. ' verbleibende Wirkungen',
			'BENUTZE ' .. need .. ' ' .. item
		}, true
    end
end

self.make_bows = function(ctx)
    local level = get_level(ctx.unit, 'Waffenbau')
    if level < 2 then
        return 'LERNE Waffenbau'
    else
        return 'MACHE Bogen'
    end
end

self.lighthouse = function(ctx, ...)
    ctx.unit.ejcOrdersConfirmed = 1
    local params = {...}
    local cmd = 'LERNE AUTO Wahrnehmung'
    if get_item(ctx.unit, 'Silber') < 10 * ctx.unit.Anzahl then
        if get_level(ctx.unit, 'Unterhaltung') > 0 then
            cmd = 'UNTERHALTE'
        end
    end
    if #params > 0 and not ctx.unit.Burg then
        return {
            cmd,
            'BETRETE BURG ' .. params[1]
        }
    end
    return cmd
end

self.trader = function(ctx, num, good, ...)
    local params = {...}
    local result = {}
    table.insert(result, 'KAUFE ' .. num .. ' ' .. good)
    if #params > 0 then
        for i=1,#params do
            table.insert(result, '!VERKAUFE ALLES ' .. params[i])
        end
    end
    return result
end

self.embassy = function(ctx, ...)
    local ent = get_level(ctx.unit, 'Unterhaltung')
    if ent < 1 then
        return 'LERNE Unterhaltung'
    else
        local mon = get_item(ctx.unit, 'Silber')
        if mon < 10 then
            return '@ARBEITE'
        elseif mon < 20 then
            return 'UNTERHALTE'
        end
    end
    return {
        'LERNE Wahrnehmung',
        '@RESERVIERE 20 Silber'
    }
end

self.entertain = function(ctx, ...)
    local params = {...}
    local val = get_level(ctx.unit, 'Unterhaltung')
    local level = 1
    ctx.unit.ejcOrdersConfirmed = 1
    if #params > 0 then
        level = tonumber(params[1]) or 1
    end
    if val and (val >= level) then
        return {
            '; bestaetigt',
            'UNTERHALTE'
        }
    else
        return {
            '; bestaetigt',
            'LERNE AUTO Unterhaltung'
        }
    end
end

-- learn skill [skill ...]
-- example: #call learn Stangenwaffen Ausdauer
self.learn = function(ctx, skill, ...)
    local u = ctx.unit
    local params = {...}
    if #params > 0 then
        local i = ctx.turn % #params
        skill = params[i + 1]
    end
    return {
        '; bestaetigt',
        'LERNE AUTO ' .. skill
    }
end

self.multiply = function(ctx, skill, count)
    local u = ctx.unit
    count = count or ctx.region.Rekruten
    if tonumber(count) > ctx.region.Rekruten then
        count = ctx.region.Rekruten
    end
    temp = itoa36(u.keys[1])
    return {
        'LERNE AUTO ' .. skill,
        'MACHE TEMP ' .. temp .. ' "' .. u.Name .. '"',
        '  REKRUTIERE ' .. count,
        '  LERNE AUTO ' .. skill,
        'ENDE'
    }
end

self.auto = function(ctx, skill, level)
    local u = ctx.unit
    local goal = tonumber(level)
    if type(goal)~='number' then
        return "; OBS: Syntax error, level: " .. level
    elseif get_level(u, skill) < goal then
        ctx.unit.ejcOrdersConfirmed = 1
        return {
            '; bestaetigt',
            'LERNE AUTO ' .. skill
        }
    else
        return {
            'LERNE AUTO ' .. skill,
            '; OBS: ' .. skill .. ' ' .. get_level(u, skill)
        }
    end
end

self.learnto = function(ctx, skill, level, ...)
    local u = ctx.unit
    local goal = tonumber(level)
    if type(goal)~='number' then
        return "; OBS: Syntax error, level: " .. level
    elseif get_level(u, skill) < goal then
        ctx.unit.ejcOrdersConfirmed = 1
        return {
            '; bestaetigt',
            'LERNE ' .. skill
        }
    else
        local params = {...}
        cmd = 'LERNE AUTO'
        for k, param in ipairs(params) do
            if param == 'noauto' then
                cmd = 'LERNE'
            end
        end
        return {
            cmd .. ' ' .. skill,
            '; OBS: ' .. skill .. ' ' .. get_level(u, skill)
        }
    end
end

self.recruit = function(ctx, ...)
    local r = ctx.region
    local u = ctx.unit
    local params = {...}
    local incr = tonumber(params[1])
    local tomax = params[2]
    if tomax then 
        local diff = tonumber(tomax) - u.Anzahl
        if diff > 0 then
            if diff < incr then
                incr = diff
            end
        else
            return '; OBS: unit size reached ' .. tomax
        end
    end
    return 'REKRUTIERE ' .. incr
end

self.recruit_entertainers = function(ctx)
    local r = ctx.region
    local u = ctx.unit
    local count = u.Anzahl * 10
    local maxr = r.Rekruten
    if count > maxr then count = maxr end
    temp = itoa36(u.keys[1])
    local level = get_level(u, 'Unterhaltung')
    if level >= 2 then
        -- can teach the new unit:
        return {
            'LEHRE TEMP ' .. temp,
            'DEFAULT UNTERHALTE',
            'MACHE TEMP ' .. temp .. ' "' .. gen_elf_name() .. '"',
            '  REKRUTIERE ' .. count,
            '  LERNE Unterhaltung',
            '  DEFAULT UNTERHALTE',
            'ENDE'
        }
    end
    -- the new unit must learn without teacher:
    return {
        'UNTERHALTE',
        'MACHE TEMP ' .. temp .. ' "' .. gen_elf_name() .. '"',
        '  REKRUTIERE ' .. count,
        '  LERNE AUTO Unterhaltung',
        '  DEFAULT UNTERHALTE',
        'ENDE'
    }
end

self.findstone = function(ctx)
    local r = ctx.region
    local u = ctx.unit
    if r.RESOURCE and r.RESOURCE[RESOURCE_STONE] then
        local needed = r.RESOURCE[RESOURCE_STONE].skill
        local skill = get_level(u, "Steinbau")
        print('; ' .. itoa36(u.keys[1]) .. ' findstone: ' .. skill .. ' of ' .. needed)
        if needed <= skill then
            return {
                '; OBS: Steine gefunden',
                'MACHE Steine',
            }
        end
    end
    ctx.unit.ejcOrdersConfirmed = 1
    return {
        '; bestaetigt',
        'LERNE AUTO Steinbau'
    }
end

self.findiron = function(ctx)
    local r = ctx.region
    local u = ctx.unit
    if r.RESOURCE and r.RESOURCE[RESOURCE_IRON] and r.RESOURCE[RESOURCE_IRON].skill <= get_level(u, "Bergbau") then
        return {
            '; OBS: Eisen gefunden',
            'MACHE Eisen',
        }
    else
        ctx.unit.ejcOrdersConfirmed = 1
        return {
            '; bestaetigt',
            'LERNE AUTO Bergbau'
        }
    end
end

local function all_items(r)
    result = {}
    if r.EINHEIT then
        for i, u in ipairs(r.EINHEIT) do
            if u.GEGENSTAENDE then
                for k, v in pairs(u.GEGENSTAENDE) do
                    local x = result[k] or 0
                    result[k] = x + v
                end
            end
        end
    end
    return result
end

local g_alchemist = {
    r = nil,
    potions = {}
}

self.alchemist = function(ctx, ...)
    local params = {...}
    local index = 1
    local r = ctx.region
    if g_alchemist.r ~= r then
        local items = all_items(r)
        g_alchemist.items = items
        g_alchemist.potions = alchemy.possible_potions(items)
        g_alchemist.r = r
    end
    local potions = g_alchemist.potions
    local item = nil
    local result = {'; Alchemist'}
    local skill = get_level(ctx.unit, 'Alchemie')
    if #params > 0 then
        for _, want in ipairs(params) do
            -- want = unescape_spaces(want)
            if potions[want] and potions[want].count > 0 then
                if potions[want].potion.level <= skill / 2 then
                    item = want
                    break
                end
            end
        end
    end
--[[
    if not item then
        for name, potion in pairs(potions) do
            local n = potion.count
            item = item or name
            table.insert(result, '; ' .. n .. ' ' .. name)
        end
    end
--]]
    if item then
        local limit = math.floor(ctx.unit.Anzahl * skill / 2)
        -- try making as many as possible:
        local num = g_alchemist.potions[item].count
        if num > limit then num = limit end
        -- assume we can make all of them:
        g_alchemist.potions[item].count = g_alchemist.potions[item].count - num
        table.insert(result, 'MACHE ' .. num .. ' ' .. item)
    else
        table.insert(result, 'LERNE Alchemie')
    end
    return result
end

-- MACHE Kräuter mit regelmäßiger FORSCHung
-- Examples:
--  #call herbalist : FORSCHE jede Woche
--  #call herbalist 10 : MACHE 10, FORSCHE jede 5. Woche (10/2)
--  #call herbalist 10 4 : MACHE 10, FORSCHE jede 4. Woche
--  #call herbalist 10 0 : MACHE 10, FORSCHE nie
self.herbalist = function(ctx, ...)
    local params = {...}
    local want = 0
    local check = 0
    if #params > 0 then
        want = tonumber(params[1])
    end
    if #params > 1 then
        check = tonumber(params[2])
    elseif want > 1 then
        check = want / 2
    end
    if want > 0 then
        if (check ~= 0) and (ctx.turn % check ~= 0) then
            return {
                '; bestaetigt',
                "MACHE " .. want .. " Kräuter"
            }
        end
    end
    return "FORSCHE Kräuter"
end

local function find_new_monsters(cr, old)
    local monsters = {}
    for _, r in ipairs(cr.REGION) do
        if r.EINHEIT and not r.visibility then
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

local function print_monsters(monsters, turn)
    for k, v in pairs(monsters) do
        local u = v.unit
        local r = v.region
        s = string.format('; %s: %d %s (%s) @%d',
            r.Name or regionname(r),
            u.Anzahl,
            u.Typ,
            itoa36(u.keys[1]),
            turn)
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
    1398502408, -- X Bauern besucht unverhofft der Storch.
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
    424720393, -- eine Botschaft
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
                            r = crlib.get_region(cr, m.region)
                        end
                        u = crlib.get_unit(cr, m.unit, r)
                        if r then
                            if not u then
                                u = crlib.get_unit(cr, m.unit, nil)
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
    math.randomseed(turn)
    if not old then
        log_error(name .. '\t' .. err .. '\n')
    else
        --[[
        local monsters = find_new_monsters(cr, old)
        print_monsters(monsters, turn)
        print_low_silver(cr, faction)
        print_messages(cr, faction)
        ]]
    end
end

self.onregion = function(ctx)
    local r = ctx.region
    local fno = ctx.faction.keys[1]
    
    if r.EINHEIT then
        local silver = 0
        local men = 0
        local first = nil
        for _, u in ipairs(r.EINHEIT) do
            if u.Partei == fno then
                silver = silver + get_item(u, "Silber")
                men = men + u.Anzahl
                if not first then first = u end
            end
        end
        if first and silver < men * 10 then
            local cmds = first.COMMANDS or {}
            table.insert(cmds, "; OBS Silber: only " .. silver .. " silver for " .. men .. " men")
            first.COMMANDS = cmds
        end
    end
end

return self
