crs = require('cr')
map = require('map')

infile = arg[1]
outfile = arg[2]

if infile and outfile then
    cr, err = crs.read(infile)
    if cr then
        -- crs.write(outfile, cr)
        crs.write(outfile, map.filter(cr))
    else
        print(v, err)
    end
end
