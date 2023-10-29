if not IsESX() then return end

ESX = exports['es_extended']:getSharedObject()

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	PlayerData = xPlayer
	PlayerLoaded = true

end)


RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
    lib.hideTextUI()
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    table.wipe(PlayerData)
    PlayerLoaded = false
end)


function IsBoss()
    return PlayerData.job.grade_name == 'boss'
end

function GetJob()
    return PlayerData.job.name
end

AddEventHandler('onResourceStart', function(resource)
    if cache.resource == resource then
        Wait(500)
        PlayerData = ESX.GetPlayerData()
        PlayerLoaded = true
    end
end)