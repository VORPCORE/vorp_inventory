---@alias sourceId string
---@alias itemId string
---@alias weaponId string
---@alias invId string
---@alias identifier string
---@alias charId number

---@class VorpInventoryLoadOutRow
---@field id             number
---@field identifier     string
---@field charidentifier number|nil
---@field name           string|nil
---@field ammo           string
---@field components     string
---@field used           number|nil
---@field dropped        number
---@field comps          string
---@field used2          number
---@field curr_inv       string

---@type table<invId, table<sourceId, table<itemId, Item>>|table<itemId, Item>>
UsersInventories = {
    default = {}
}

---@type table<string, Item>
svItems = {}

---@param db_weapon VorpInventoryLoadOutRow
function WrapDbWeaponAndCache(db_weapon)

    local ammo = json.decode(db_weapon.ammo)
    local comp = json.decode(db_weapon.components)
    local used = false
    local used2 = false

    if db_weapon.used == 1 then
        used = true
    end

    if db_weapon.used2 == 1 then
        used2 = true
    end

    if db_weapon.dropped == 0 then
        local weapon = Weapon:New({
            id = db_weapon.id,
            propietary = db_weapon.identifier,
            name = db_weapon.name,
            ammo = ammo,
            components = comp,
            used = used,
            used2 = used2,
            charId = db_weapon.charidentifier or 0,
            currInv = db_weapon.curr_inv,
            dropped = db_weapon.dropped
        })

        UserWeaponsCacheService:add(db_weapon.curr_inv, weapon)
    else
        -- delete any droped weapons
        MySQL.query('DELETE FROM loadout WHERE id = ?', { db_weapon.id })
    end
end

---@param invId invId
---@param weaponId weaponId
function LoadWeapon(invId, weaponId)

    local result = MySQL.query.await('SELECT * FROM loadout WHERE id = ? and curr_inv = ?;', { weaponId, invId })
    if next(result) then
        for _, db_weapon in pairs(result) do
            WrapDbWeaponAndCache(db_weapon)
        end
    end
end

---@param charid charId
function LoadDatabase(charid)
    local result = MySQL.query.await('SELECT * FROM loadout WHERE charidentifier = ? ', { charid })
    if next(result) then
        for _, db_weapon in pairs(result) do
            if db_weapon.charidentifier then
                WrapDbWeaponAndCache(db_weapon)
            end
        end
    end
end

-- load weapons only for the character that its joining
RegisterNetEvent("vorp:SelectedCharacter", function(source, character)
    local charid = character.charIdentifier
    LoadDatabase(charid)
end)

if Config.DevMode then
    RegisterNetEvent("DEV:loadweapons", function()
        local _source = source
        local character = Core.getUser(_source).getUsedCharacter
        local charid = character.charIdentifier
        LoadDatabase(charid)
    end)
end

-- load all items from database
Citizen.CreateThread(function()
    MySQL.query('SELECT * FROM items', {}, function(result)
        if next(result[1]) then
            for _, db_item in pairs(result) do
                local item = Item:New({
                    id = db_item.id,
                    item = db_item.item,
                    metadata = db_item.metadata or {},
                    label = db_item.label,
                    limit = db_item.limit,
                    type = db_item.type,
                    canUse = db_item.usable,
                    canRemove = db_item.can_remove,
                    desc = db_item.desc
                })
                svItems[item.item] = item
            end
        end
    end)
end)
