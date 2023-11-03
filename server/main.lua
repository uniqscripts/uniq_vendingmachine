local cfg = lib.require('config.config')
local Vending = {}
local buyHook, swapHook


RegisterNetEvent('uniq_vending:setData', function(price, currency, payload)
    exports.ox_inventory:SetMetadata(payload.toInventory, payload.toSlot, { price = price, currency = currency })
    Wait(200)
    local items = exports.ox_inventory:GetInventoryItems(payload.toInventory, false)
    local inventory = {}

    if items then
        for k,v in pairs(items) do
            inventory[#inventory + 1] = { name = v.name, metadata = v.metadata, price = v.metadata.price, currency = v.metadata.currency, count = v.count }
        end

        exports.ox_inventory:RegisterShop(payload.toInventory, {
            name = payload.toInventory,
            inventory = inventory,
        })
    end
end)

RegisterNetEvent('uniq_vending:SetUpStore', function(store)
    Wait(300)
    local items = exports.ox_inventory:GetInventoryItems(store, false)
    local inventory = {}

    if items then
        for k,v in pairs(items) do
            inventory[#inventory + 1] = { name = v.name, metadata = v.metadata, price = v.metadata.price, currency = v.metadata.currency, count = v.count }
        end

        exports.ox_inventory:RegisterShop(store, {
            name = store,
            inventory = inventory,
        })
    end
end)

local function SetUpHooks(inventoryFilter)
    if buyHook then exports.ox_inventory:removeHooks(buyHook) end
    if swapHook then exports.ox_inventory:removeHooks(swapHook) end

    buyHook = exports.ox_inventory:registerHook('buyItem', function(payload)
        exports.ox_inventory:RemoveItem(payload.shopType, payload.itemName, payload.count)
        exports.ox_inventory:AddItem(('stash-money-%s'):format(payload.shopType), payload.currency, payload.totalPrice)

        return true
    end, { inventoryFilter = inventoryFilter })

    swapHook = exports.ox_inventory:registerHook('swapItems', function(payload)
        if payload.toType == 'stash' then
            if cfg.BlacklistedItems[payload.fromSlot.name] then
                lib.notify(payload.source, { description = L('notify.cant_put'), type = 'error' })

                return false
            end

            TriggerClientEvent('uniq_vending:selectCurrency', payload.source, payload)
        else
            TriggerEvent('uniq_vending:SetUpStore', payload.fromInventory)
        end

        return true
    end, { inventoryFilter = inventoryFilter })
end

local function RegisterStash(name)
    exports.ox_inventory:RegisterStash(('stash-money-%s'):format(name), name, 100, 100000)
    exports.ox_inventory:RegisterStash(('%s'):format(name), name, 100, 100000)
end

MySQL.ready(function()
    Wait(1000) -- to not fetch old data from sql
    local success, error = pcall(MySQL.scalar.await, 'SELECT 1 FROM `uniq_vending`')

    if not success then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `uniq_vending` (
                `name` varchar(50) DEFAULT NULL,
                `data` longtext DEFAULT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        ]])
    end

    Wait(50)

    local result = MySQL.query.await('SELECT * FROM `uniq_vending`')

    if result[1] then
        local inventoryFilter = {}

        for k,v in pairs(result) do
            local data = json.decode(v.data)

            RegisterStash(data.name)

            Vending[v.name] = data

            table.insert(inventoryFilter, v.name)

            TriggerEvent('uniq_vending:SetUpStore', v.name)
        end

        SetUpHooks(inventoryFilter)
    end
end)

lib.callback.register('uniq_vending:fetchVendings', function(source)
    return Vending
end)

lib.addCommand('addvending', {
    help = L('commands.addvending'),
    restricted = 'group.admin'
}, function(source, args, raw)
    if source == 0 then return end
    local options = {}

    local players = GetAllPlayers()
    
    if IsQBCore() then
        for k,v in pairs(players) do
            options[#options + 1] = { label = ('%s | %s'):format(v.PlayerData.name, v.PlayerData.source), value = v.PlayerData.citizenid }
        end
    elseif IsESX() then
        for k,v in pairs(players) do
            options[#options + 1] = { label = ('%s | %s'):format(v.getName(), v.source), value = v.identifier }
        end
    end

    TriggerClientEvent('uniq_vending:startCreating', source, options)
end)


lib.addCommand('dellvending', {
    help = L('commands.dellvending'),
    restricted = 'group.admin'
}, function(source, args, raw)
    if source == 0 then return end
    local options = {}
    local count = 0

    for k,v in pairs(Vending) do
        count += 1
    end

    if count == 0 then
        return lib.notify(source, { description = L('notify.no_vendings'), type = 'error' })
    end

    for k,v in pairs(Vending) do
        options[#options + 1] = { label = v.name, value = v.name }
    end

    TriggerClientEvent('uniq_vending:client:dellvending', source, options)
end)


lib.addCommand('findvending', {
    help = L('commands.findvending'),
    restricted = 'group.admin'
}, function(source, args, raw)
    if source == 0 then return end
    local options = {}
    local count = 0

    for k,v in pairs(Vending) do
        count += 1
    end

    if count == 0 then
        return lib.notify(source, { description = L('notify.no_vendings'), type = 'error' })
    end

    for k,v in pairs(Vending) do
        options[#options + 1] = { label = v.name, value = v.name }
    end

    local cb = lib.callback.await('uniq_vending:choseVending', source, options)

    if cb then
        if Vending[cb] then
            local coords = Vending[cb].coords
            local ped = GetPlayerPed(source)
            SetEntityCoords(ped, coords.x, coords.y + 1, coords.z, false, false , false, false)
        end
    end
end)

RegisterNetEvent('uniq_vending:server:dellvending', function(shop)
    if Vending[shop] then
        MySQL.query('DELETE FROM `uniq_vending` WHERE `name` = ?', { shop })

        exports.ox_inventory:ClearInventory(('stash-money-%s'):format(shop))
        exports.ox_inventory:ClearInventory(('%s'):format(shop))

        Vending[shop] = nil
        TriggerClientEvent('uniq_vending:sync', -1, Vending, true)
    end
end)

RegisterNetEvent('uniq_vending:buyVending', function(name)
    local src = source

    if Vending[name] then
        if exports.ox_inventory:Search(src, 'count', 'money') >= Vending[name].price then
            exports.ox_inventory:RemoveItem(src, 'money', Vending[name].price)

            if Vending[name].type == 'player' then
                local identifier = GetIdentifier(src)
                Vending[name].owner = identifier
            elseif Vending[name].type == 'job' then
                local job, grade = GetJob(src)

                Vending[name].owner = { [job] = grade }
            end
            MySQL.update('UPDATE `uniq_vending` SET `data` = ? WHERE `name` = ?', {json.encode(Vending[name], {sort_keys = true}), name})
            TriggerClientEvent('uniq_vending:sync', -1, Vending, true)
            lib.notify(src, { description = L('notify.vending_bought'):format(Vending[name].name, Vending[name].price), type = 'success' })
        else
            lib.notify(src, { description = L('notify.not_enough_money'):format(Vending[name].price), type = 'error' })
        end
    end
end)


RegisterCommand('adad', function (source, args, raw)
    lib.notify(source, { description = 'ad', type = 'success' })
end)


RegisterNetEvent('uniq_vending:sellVending', function(name)
    local src = source
    
    if Vending[name] then
        local price = math.floor(Vending[name].price * cfg.SellPertencage)

        exports.ox_inventory:AddItem(src, 'money', price)
        Vending[name].owner = false

        MySQL.update('UPDATE `uniq_vending` SET `data` = ? WHERE `name` = ?', {json.encode(Vending[name], {sort_keys = true}), name})
        TriggerClientEvent('uniq_vending:sync', -1, Vending, true)
        lib.notify(src, { description = L('notify.vending_sold'):format(Vending[name], price), type = 'success' })
    end
end)

RegisterNetEvent('uniq_vending:createVending', function(data)
    local src = source

    MySQL.insert('INSERT INTO `uniq_vending` (name, data) VALUES (?, ?)', {data.name, json.encode(data, {sort_keys = true})})
    
    RegisterStash(data.name)
    lib.notify(src, { description = L('notify.vending_created'):format(data.name, data.price), type = 'success' })

    Vending[data.name] = data
    
    local inventoryFilter = {}

    for k,v in pairs(Vending) do
        table.insert(inventoryFilter, v.name)
    end


    TriggerEvent('uniq_vending:SetUpStore', data.name)

    SetUpHooks(inventoryFilter)

    TriggerClientEvent('uniq_vending:sync', -1, Vending, false)
end)

lib.callback.register('uniq_vending:getJobs', function(source)
    local jobs = GetJobs()
    local options = {}

    if IsESX() then
        for k,v in pairs(jobs) do
            if not cfg.BlacklsitedJobs[k] then
                options[#options + 1] = { label = v.label, value = k }
            end
        end
    end

    return options
end)

lib.callback.register('uniq_vending:getGrades', function(source, job)
    local jobs = GetJobs()
    local options = {}

    for k,v in pairs(jobs['police'].grades) do
        options[#options + 1] = { label = v.label, value = v.grade }
    end

    return options
end)


local function saveDB()
    local insertTable = {}
    if table.type(Vending) == 'empty' then return end

    for k,v in pairs(Vending) do
        insertTable[#insertTable + 1] = { query = 'UPDATE `uniq_vending` SET `data` = ? WHERE `name` = ?', values = { json.encode(v, {sort_keys = true} ), v.name } }
    end

    MySQL.transaction(insertTable)
end

AddEventHandler('onResourceStop', function(name)
    if name == cache.resource then
        exports.ox_inventory:removeHooks(buyHook)
        exports.ox_inventory:removeHooks(swapHook)
        saveDB()
    end
end)