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

function GetJob(id)
    local xPlayer = ESX.GetPlayerFromId(id)

    if xPlayer then
        return xPlayer.job.name, xPlayer.job.grade
    end
end

function GetIdentifier(id)
    local xPlayer = ESX.GetPlayerFromId(id)
    
    if xPlayer then
        return xPlayer.identifier
    end

    return false
end