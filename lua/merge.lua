crs = require('cr')

local function merge(result, ...)
    local args = { select(1, ...) }
    for _, infile in ipairs(args) do
        cr, err = crs.read(infile)
        if cr then
            local dx, dy
            dx, dy = crs.find_offset(result, cr)
            if dx and dy then
                print(infile, 'origin is at ' .. dx .. ',' .. dy)
                crs.move(cr, - dx, - dy)
            end
            crs.merge(result, cr)
        else
            print(infile, err)
        end
    end
    return result
end

return merge
