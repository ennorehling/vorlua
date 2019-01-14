crs = require('cr')

infile = arg[1] or 'test.cr'
outfile = arg[2] or 'filter.cr'

local map_filter = {
    ['elements'] = {
        ['VERSION'] = {
            ['tags'] = { 'mailcmd', 'mailto' }
        },
        ['REGION'] = {
            ['tags'] = { 'id', 'Terrain', 'Name', 'Beschr', 'keys' },
            ['elements'] = {}
        }
    }
}

result, err = crs.read(infile)
print(result.VERSION)
if result then
    crs.filter(result, map_filter)
    crs.write(result, outfile)
else
    print(name, err)
end
