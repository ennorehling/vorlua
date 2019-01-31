crs = require('cr')

local function dump_table(tbl, indent)
    indent = indent or '- '
    if #tbl == 0 then
        for k, v in pairs(tbl) do
            if type(v) == 'table' then
                print(indent .. k .. ':')
                dump_table(v, '  ' .. indent)
            else
              print(indent .. k .. ': ' .. v)
            end
        end
    else
        for k, v in ipairs(tbl) do
            if type(v) == 'table' then
                print(indent .. k .. ':')
                dump_table(v, '  ' .. indent)
            else
              print(indent .. k .. ': ' .. v)
            end
        end
    end
end

cr = crs.read('991-fmno.cr')
dump_table(cr.PARTEI[1].OPTIONEN)
dump_table(cr.MESSAGETYPE)
dump_table(cr.TRANSLATION)
