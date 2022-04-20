crs = require('cr')

local function merge(...)
    local args = { select(1, ...) }
    local result = nil
    for _, infile in ipairs(args) do
        cr, err = crs.read(infile)
        if cr then
            if not result then
                result = cr
            else
                local dx, dy
                dx, dy = crs.find_offset(result, cr)
                if dx or dy then
                    print(infile, 'origin is at ' .. dx .. ',' .. dy)
                    if dx ~= 0 or dy ~= 0 then
                        crs.move(cr, - dx, - dy)
                    end
                end
                crs.merge(result, cr)
            end
        else
            print(infile, err)
        end
    end
    return result
end

return merge
