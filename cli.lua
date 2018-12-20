crs = require('cr')

local function get_line()
    return io.read("*l")
end

local map_filter = {
    ['elements'] = {
        ['VERSION'] = {},
        ['REGION'] = {
            ['tags'] = { 'id', 'Terrain', 'Name', 'Beschr', 'keys' },
            ['elements'] = {}
        }
    }
}

local data = nil
local cr = nil
done = false
while not done do
    line = get_line()
    if not line then break end
    words = {}
    for word in line:gmatch("%S+") do table.insert(words, word) end
    print(words[1])
    if words[1] == 'quit' then
        done = true
    elseif words[1] == 'load' and #words>=2 then
        cr = crs.read(words[2])
    elseif words[1] == 'save' and #words>=2 then
        crs.write(cr, words[2])
    elseif words[1] == 'move' and #words>=3 then
        crs.move(cr, words[2], words[3])
    elseif words[1] == 'store' then
        data = cr
    elseif words[1] == 'recall' then
        cr = data
    elseif words[1] == 'status' then
        crs.status(cr)
    elseif words[1] == 'dump' then
        crs.dump(cr)
    elseif words[1] == 'merge' then
        if data then
            crs.merge(cr, data)
        end
        cr = data
    elseif words[1] == 'filter' then
        crs.filter(cr, map_filter)
    end
end
