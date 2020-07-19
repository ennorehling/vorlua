local crs = require 'cr'

function log_error(str)
    io.stderr:write(str)
end

local terrains = {
    ['Ozean'] = 'ocean',
    ['Gletscher'] = 'glacier',
    ['Eisberg'] = 'iceberg',
    ['Hochland'] = 'highland',
    ['Feuerwand'] = 'firewall',
    ['Sumpf'] = 'swamp',
    ['Aktiver Vulkan'] = 'volcano',
    ['Vulkan'] = 'volcano',
    ['Wüste'] = 'desert',
    ['Berge'] = 'mountain',
    ['Wald'] = 'plain',
    ['Ebene'] = 'plain',
}

function lua_export(cr)
    local r
    print('require "config"')
    for _, r in ipairs(cr.REGION) do
        if r.Terrain then
            local terrain = terrains[r.Terrain] or 'desert'
            print('r = region.create(' .. r.keys[1] .. ', ' .. r.keys[2] .. ', "' .. terrain .. '")')
            if (r.Name) then
                print('r.name = "' .. r.Name .. '"')
            end
        end
    end
    print("eressea.write_game('export.dat')")
end

local name = arg[1]
local cr, err = crs.read(name)
if not cr then
    log_error(name .. '\t' .. err .. '\n')
else
    lua_export(cr)
end
