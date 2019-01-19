crs = require('cr')

local export_filter = {
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

local function export(cr)
    crs.filter(cr, export_filter)
    return cr
end

return export
