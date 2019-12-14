crs = require('cr')

outfile = arg[1]
faction = arg[2]
first = arg[3] or 1
last = arg[4] or 10000

local my_map_filter = {
    ['elements'] = {
        ['VERSION'] = {},
        ['REGION'] = {
            ['tags'] = { 'Terrain', 'Name', 'Beschr', 'Lohn', 'id', 'keys' },
            ['elements'] = {
                ['BURG'] = {
                    ['tags'] = { 'Typ', 'Name', 'Groesse' },
                    ['elements'] = {}
                },
                ['PREISE'] = {
                    ['tags'] = { '%S+' },
                    ['elements'] = {}
                }
            }
        }
    }
}

origin = nil
result, err = crs.read(outfile)
if result then
    crs.filter(result, my_map_filter)
    local o = crs.find_region(result, 0, 0)
    if o then origin = o.id end
end
for i=first,last,1
do
    name = i .. '-' .. faction .. '.cr'
    cr, err = crs.read(name)
    if cr then
        crs.filter(cr, my_map_filter)
        local r = crs.find_region(cr, 0, 0)
        if origin then
            if not r or origin ~= r.id then
                local dx, dy
                dx, dy = crs.find_offset(result, cr)
                if dx and dy then
                    print(name, 'origin is at ' .. dx .. ',' .. dy)
                    crs.move(cr, - dx, - dy)
                else
                    print(name, 'origin not found')
                end
            end
        else
            if r then
                origin = r.id
            end
        end
        if cr then
            if result then
                crs.merge(result, cr)
            else
                result = cr
            end
        end
    else
        print(name, err)
        if not arg[4] then
            break
        end
    end
end
crs.write(result, outfile)
