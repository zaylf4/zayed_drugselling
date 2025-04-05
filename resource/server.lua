local config = lib.require('config')
local stevo_lib = exports['stevo_lib']:import()

local isInZone = false

local success, result = pcall(MySQL.scalar.await, 'SELECT 1 FROM zayed_drugsell_rep')

if not success then
    MySQL.query([[CREATE TABLE IF NOT EXISTS `zayed_drugsell_rep` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `owner` VARCHAR(50) NOT NULL,
    `rep` INT NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `owner` (`owner`)
    )]])
    print('[Stevo Scripts] Deployed database table for zayed_drugsell')
end


function get_reputation(source)
    local identifier = stevo_lib.GetIdentifier(source)
    local playerGang = exports['rcore_gangs']:GetPlayerGang(source)

    if playerGang ~= nil then

        local row = MySQL.single.await('SELECT `rep` FROM `zayed_drugsell_rep` WHERE `owner` = ? LIMIT 1', {
            playerGang.id
        })

        if row == nil or row.rep == nil then 
            MySQL.insert.await('INSERT INTO `zayed_drugsell_rep` (owner, rep) VALUES (?, ?)', {
                playerGang.id, 0
            })
            return 0
        else
            row.rep = tonumber(row.rep) -- Converting to number instead of string
            return row.rep
        end
    end
end


function set_reputation(source, rep)
    local identifier = stevo_lib.GetIdentifier(source)
    local playerGang = exports['rcore_gangs']:GetPlayerGang(source)

    if playerGang ~= nil then

        local row = MySQL.single.await('SELECT `rep` FROM `zayed_drugsell_rep` WHERE `owner` = ? LIMIT 1', {
            playerGang.id
        })

        if not row then 
            MySQL.insert.await('INSERT INTO `zayed_drugsell_rep` (owner, rep) VALUES (?, ?)', {
                playerGang.id, rep
            })
            return rep
        else
            local newrep = rep + row.rep
            MySQL.update.await('UPDATE `zayed_drugsell_rep` SET rep = ? WHERE `owner` = ?', {
                newrep, playerGang.id
            })

            local old_level = nil
            local new_level = nil
        
            for _, rep in ipairs(config.reps) do
                if row.rep >= rep.min_reputation then
                    old_level = rep
                end
                if newrep >= rep.min_reputation then
                    new_level = rep
                end
            end
        
            if new_level and old_level and new_level.level ~= old_level.level then
                return true, newrep, string.format("You have leveled up from %s to %s", old_level.label, new_level.label)
            else
                return false, newrep, nil
            end
        end
    end
end


lib.callback.register('zayed_drugsell:sale', function(source, data)

    local police_multi = 0

    if config.police.require then 
        local police_count = stevo_lib.GetJobCount(source, config.police.job) 

        if police_count < config.police.required then 
            return false
        end

        local police_amount = config.police.multi * data.amount
        police_multi = config.police.multi * police_amount
    end

    local reputation = get_reputation(source)

    local reputation_multi

    local final_amount = data.amount + police_multi

    exports.ox_inventory:RemoveItem(source, data.item, data.count)
    exports.ox_inventory:AddItem(source, config.money_item, final_amount)

    if isInZone then
        local level_up, current_reputation, msg = set_reputation(source, data.rep)
    end

    return final_amount, level_up, current_reputation, msg
end)


lib.callback.register('zayed_drugsell:getReputation', function(source)
    local playerGang = exports['rcore_gangs']:GetPlayerGang(source)
    local gangName = playerGang.name
    local rep = get_reputation(source)
    if playerGang then
        return rep, gangName
    else
        return false
    end
end)


lib.callback.register('zayed_drugsell:setReputation', function(source, rep)
    local level_up, current_reputation, msg = set_reputation(source, rep)
    return level_up, current_reputation, msg
end)


RegisterServerEvent("zayed_drugsell:server:setZoneStatus")
AddEventHandler("zayed_drugsell:server:setZoneStatus", function(status)
    isInZone = status
end)