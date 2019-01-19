crs = require('cr')
command = arg[1]
infile = arg[2]

local foo = require(command)
if type(foo) ~= 'function' then
    print(command, 'invalid command')
    return 1
end
print(foo)
return 0

if infile then
    result, err = crs.read(infile)
    if not result then
        print(infile, err)
        result = {}
    end
else
    result = {}
end

if result then
    n = 3
    outfile = arg[3]
    if not outfile or outfile == '--' then
        outfile = infile
    else
        n = 4
    end
    if arg[n] == '--' then n = n + 1 end
    result = foo(result, unpack(arg, n))
    if result then
        crs.write(result, outfile)
    end
else
    print(infile, err)
end
