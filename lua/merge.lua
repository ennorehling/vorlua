crs = require('cr')

local function merge(result, ...)
    local args = { select(1, ...) }
    for _, infile in ipairs(args) do
        cr, err = crs.read(infile)
        if cr then
            crs.merge(result, cr)
        else
            print(name, err)
        end
    end
    return result
end

return merge
