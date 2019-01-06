crs = require('cr')

infile = arg[1]
outfile = arg[2]

if infile and outfile then
    cr, err = crs.read(infile)
    if cr then
    	crs.filter(cr, crs.map_filter)
        crs.write(cr, outfile)
    else
        print(v, err)
    end
end
