if not IsQBCore() then return end

local QBCore = exports['qb-core']:GetCoreObject()

function GetAllPlayers()
    return QBCore.Functions.GetQBPlayers()
end

function GetPlayerFromId(id)
    return QBCore.Functions.GetPlayer(id)
end

function GetJobs()
    return QBCore.Shared.Jobs
end

function GetJob(id)
    local Player = QBCore.Functions.GetPlayer(id)

    if Player then
        return Player.PlayerData.job.name, Player.PlayerData.job.grade.level
    end
end

function GetIdentifier(id)
    local Player = QBCore.Functions.GetPlayer(id)
    
    if Player then
        return Player.PlayerData.citizenid
    end

    return false
end