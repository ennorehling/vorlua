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

local function template(cr)
    dump_table(cr, '- ')
end

local reports = {}
for i, v in ipairs(arg) do
    print(i, v)
    cr, err = crparse(v)
    if cr then
        reports[i] = cr
        template(cr)
        -- print(cr.VERSION)
        -- print(cr.VERSION.REGION[1].EINHEIT[1].COMMANDS[1])
    else
        print(v, err)
    end
end
