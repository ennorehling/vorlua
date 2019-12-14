crs = require('cr')

mapfile = arg[1]
infile = arg[2]
outfile = arg[3]

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
result, err = crs.read(mapfile)
if not result then
    print(mapfile, err)
else 
    crs.filter(result, my_map_filter)
    cr, err = crs.read(infile)
    if cr then 
        crs.merge(result, cr)
        crs.write(result, outfile)
    else
        print(infile, err)
    end
end
