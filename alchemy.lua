-- user defined functions

local self = {}

-- useful potions in order of preference:
local potions = {
    ['Wasser~des~Lebens'] = {
        ['herbs'] = {'Elfenlieb', 'Knotiger Saugwurz'},
        ['level'] = 1
    },
    ['Gehirnschmalz'] = {
        ['herbs'] = {'Steinbeißer', 'Gurgelkraut', 'Wasserfinder', 'Windbeutel'},
        ['level'] = 3
    },
    ['Schaffenstrunk'] = {
        ['herbs'] = {'Spaltwachs', 'Alraune', 'Würziger Wagemut'},
        ['level'] = 2
    },
    ['Berserkerblut'] = {
        ['herbs'] = {'Alraune', 'Weißer Wüterich', 'Flachwurz', 'Sandfäule'},
        ['level'] = 3
    },
    ['Heiltrank'] = {
        ['herbs'] = {'Gurgelkraut', 'Windbeutel', 'Eisblume', 'Elfenlieb', 'Spaltwachs'},
        ['level'] = 4
    },
    ['Wundsalbe'] = {
        ['herbs'] = {'Würziger Wagemut', 'Blauer Baumringel', 'Weißer Wüterich'},
        ['level'] = 2
    }
}

self.possible_potions = function(items)
    local result = {}
    for name, potion in pairs(potions) do
        local num = nil
        -- print('; Potion: ' .. name)
        for _, h in ipairs(potion.herbs) do
            if not items[h] then
                -- print('; - no ' .. h)
                num = 0
                break
            else
                -- print('; - ' .. items[h] .. ' ' .. h)
                if not num then
                    num = items[h]
                elseif items[h] < num then
                    num = items[h]
                end
            end
        end
        if num then
            r = {}
            r.count = num
            r.potion = potion
            result[name] = r
        end
    end
    return result
end

return self
