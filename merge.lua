crs = require('cr')

outfile = arg[1]
faction = arg[2]
first = arg[3] or 1
last = arg[4] or 10000

origin = nil
result, err = crs.read(outfile)
if result then
    crs.filter(result, crs.map_filter)
    local o = crs.find_region(result, 0, 0)
    if o then origin = o.id end
end
for i=first,last,1
do
    name = i .. '-' .. faction .. '.cr'
    cr, err = crs.read(name)
    if cr then
        crs.filter(cr, crs.map_filter)
        local r = crs.find_region(cr, 0, 0)
        if origin then
            if not r or origin ~= r.id then
                local o = crs.find_region_id(cr, origin)
                if not o then
                    cr = nil
                else
                    local dx = o.keys[1]
                    local dy = o.keys[2]
                    print(name, 'origin is at ' .. dx .. ',' .. dy)
                    crs.move(cr, - dx, - dy)
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
