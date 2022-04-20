crs = require('cr')

local export_filter = {
    ['elements'] = {
        ['VERSION'] = {
            ['tags'] = {
                'Spiel', 'charset', 'Koordinaten', 'Basis', 'Runde', 'Zeitalter'
            }
        },
        ['REGION'] = {
            ['tags'] = {
                'Terrain', 'Kraut', 'Name', 'Beschr', 'Lohn', 'id', 'keys'
            },
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

local function export(infile)
    cr = crs.read(infile)
    crs.filter(cr, export_filter)
    return cr
end

return export
