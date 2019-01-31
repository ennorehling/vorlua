infile = arg[1]
result, err = crparse(infile)
if not result then
    print(infile, err)
else
    print("VERSION " .. result.VERSION.keys[1])
    for k, v in pairs(result.VERSION) do
        print(v, k)
    end
end
