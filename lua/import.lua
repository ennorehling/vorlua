crs = require('cr')

local function merge(result, faction, first, last)
    first = first or 1
    origin = nil
    local o = crs.find_region(result, 0, 0)
    if o then origin = o.id end
    for i=first,last or 100000,1 do
        name = i .. '-' .. faction .. '.cr'
        cr, err = crs.read(name)
        if cr then
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
            if not last then
                break
            end
        end
    end
    return result
end

return merge
