local function dump_table(tbl, indent)
    for k,v in pairs(tbl) do
        if type(v) == 'table' then
            print(indent .. k .. ':')
            dump_table(v, '  ' .. indent)
        else
          print(indent .. k .. ': ' .. v)
        end
    end
end

local function itoa36(i)
    return "enno"
end

local function template(cr)
    local fno = nil
    for _, f in ipairs(cr.PARTEI) do
        if f.age then
            fno = f.keys[1]
            break
        end
    end
    if fno then
        local str = string.format('PARTEI %s "Passwort"', itoa36(fno))
        print(str .. '\n')
        for _, r in ipairs(cr.REGION) do
            if r.EINHEIT then
                str = string.format('REGION %s %s', r.keys[1], r.keys[2])
                if (r.keys[3]) then
                    str = str .. ' ' .. r.keys[3]
                end
                str = str .. '; ' .. r.Name
                for _, u in ipairs(r.EINHEIT) do
                    if u.Partei == fno then
                        if str then
                            print(str .. '\n')
                        end
                        str = string.format('EINHEIT %s ; %s',
                            itoa36(u.keys[1]), u.Name)
                        print(str)
                        if u.COMMANDS then
                            for _, str in ipairs(u.COMMANDS) do
                                print('    ' .. str)
                            end
                        end
                        print('\n')
                        str = nil
                    end
                end
            end
        end
        print('NAECHSTER')
    end
end

local reports = {}
for i, v in ipairs(arg) do
    print(i, v)
    cr, err = crparse(v)
    if cr then
        reports[i] = cr
        -- dump_table(cr, '- ')
        template(cr)
    else
        print(v, err)
    end
end
