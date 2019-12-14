crs = require('cr')

infile = arg[1]
outfile = arg[2]

origin = nil
result, err = crs.read(infile)
if not result then
    print(mapfile, err)
else 
    crs.write(result, outfile)
end
