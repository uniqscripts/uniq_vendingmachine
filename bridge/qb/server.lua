if not IsQBCore() then return end

local QBCore = exports['qb-core']:GetCoreObject()

function GetAllPlayers()
    return QBCore.Functions.GetQBPlayers()
end

function GetPlayerFromId(id)
    return QBCore.Functions.GetPlayer(id)
end


function GetIdentifier(id)
    local Player = QBCore.Functions.GetPlayer(id)
    
    if Player then
        return true, Player.PlayerData.citizenid
    end

    return false
end