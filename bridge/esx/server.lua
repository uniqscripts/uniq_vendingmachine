if not IsESX() then return end

local ESX = exports['es_extended']:getSharedObject()

function GetAllPlayers()
    return ESX.GetExtendedPlayers()
end

function GetPlayerFromId(id)
    return ESX.GetPlayerFromId(id)
end

function GetJobs()
    return ESX.GetJobs()
end

function GetIdentifier(id)
    local xPlayer = ESX.GetPlayerFromId(id)
    
    if xPlayer then
        return true, xPlayer.identifier
    end

    return false
end