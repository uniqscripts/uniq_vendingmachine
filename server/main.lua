local cfg = lib.require('config.config')
local Vending = {}
local hookId, swapItems



RegisterNetEvent('uniq_vendingmachine:setData', function(price, currency, payload)
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

    local result = MySQL.query.await('SELECT * FROM `uniq_vending`')

    if result[1] then
        local inventoryFilter = {}

        for k,v in pairs(result) do
            local data = json.decode(v.data)

            exports.ox_inventory:RegisterStash(('stash-money-%s'):format(data.name), v.name, 1, 1000)
            exports.ox_inventory:RegisterStash(('%s'):format(data.name), v.name, 100, 100000)

            Vending[v.name] = data

            table.insert(inventoryFilter, v.name)
        end


        hookId = exports.ox_inventory:registerHook('buyItem', function(payload)
            print(json.encode(payload, {indent = true}))
            exports.ox_inventory:RemoveItem(payload.shopType, payload.itemName, payload.count)
            exports.ox_inventory:AddItem(('stash-%s'):format(payload.shopType), 'money', payload.totalPrice)

            return true
        end, { inventoryFilter = inventoryFilter })

        swapItems = exports.ox_inventory:registerHook('swapItems', function(payload)
            if payload.toType == 'stash' then
                TriggerClientEvent('uniq_vending:selectCurrency', payload.source, payload)
            end

            return true
        end, { inventoryFilter = inventoryFilter })
    end
end)


RegisterNetEvent('uniq_vendingmachine:updateStock', function(data)
    local src = source

    if Vending[data.name] then
        if exports.ox_inventory:Search(src, 'count', data.itemName) >= data.stock then
            exports.ox_inventory:RemoveItem(src, data.itemName, data.stock)

            local inventory = {}
            for k,v in pairs(Vending[data.name].items) do
                if v.name == data.itemName then
                    v.price = data.price
                    v.stock = data.stock
                end

                table.insert(inventory, { name = v.name, price = v.price, count = v.stock, currency = v.currency })
            end

            exports.ox_inventory:RegisterShop(data.name, {
                name = data.name,
                inventory = inventory,
            })

            TriggerClientEvent('uniq_vendingmachine:notify', src, L('notify.stock_updated'):format(data.itemName, data.stock, data.price), 'success')
        else
            TriggerClientEvent('uniq_vendingmachine:notify', src, L('notify.not_enough_items'), 'error')
        end
    end
end)


lib.callback.register('uniq_vending:fetchVendings', function(source)
    return Vending
end)

lib.addCommand('addvending', {
    help = 'Command that helps you create ownable vending machine',
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

    TriggerClientEvent('uniq_vendingmachine:startCreating', source, options)
end)


lib.addCommand('dellvending', {
    help = 'Command that helps you to delete vendings',
    restricted = 'group.admin'
}, function(source, args, raw)
    if source == 0 then return end
    local options = {}

    if table.type(Vending) == 'empty' then

        return -- nema
    end

    for k,v in pairs(Vending) do
        options[#options + 1] = { label = v.name, value = v.name }
    end

    TriggerClientEvent('uniq_vending:client:dellvending', source, options)
end)


RegisterNetEvent('uniq_vending:server:dellvending', function(shop)
    if Vending[shop] then
        MySQL.query('DELETE FROM `uniq_vending` WHERE `name` = ?', { shop })

        exports.ox_inventory:ClearInventory(('stash-money-%s'):format(shop))
        -- drugi items
        Vending[shop] = nil
        TriggerClientEvent('uniq_vending:sync', -1, Vending, true)
    end
end)

RegisterNetEvent('uniq_vendingmachine:buyVending', function(name)
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
            TriggerClientEvent('uniq_vendingmachine:notify', src, L('notify.vending_bought'):format(Vending[name], Vending[name].price), 'success')
        else
            TriggerClientEvent('uniq_vendingmachine:notify', src, L('notify.not_enough_money'):format(Vending[name].price), 'error')
        end
    end
end)


RegisterNetEvent('uniq_vendingmachine:sellVending', function(name)
    local src = source
    
    if Vending[name] then
        local price = math.floor(Vending[name].price * cfg.SellPertencage)

        exports.ox_inventory:AddItem(src, 'money', price)
        Vending[name].owner = false

        MySQL.update('UPDATE `uniq_vending` SET `data` = ? WHERE `name` = ?', {json.encode(Vending[name], {sort_keys = true}), name})
        TriggerClientEvent('uniq_vending:sync', -1, Vending, true)
        TriggerClientEvent('uniq_vendingmachine:notify', src, L('notify.vending_sold'):format(Vending[name], price), 'success')
    end
end)

RegisterNetEvent('uniq_vendingmachine:createVending', function(data)
    local src = source

    MySQL.insert('INSERT INTO `uniq_vending` (name, data) VALUES (?, ?)', {data.name, json.encode(data, {sort_keys = true})})

    local inventory = {}

    for _, item in pairs(data.items) do
        table.insert(inventory, { name = item.name, price = item.price, count = item.stock, currency = item.currency })
    end

    exports.ox_inventory:RegisterShop(data.name, {
        name = data.name,
        inventory = inventory,
    })

    exports.ox_inventory:RegisterStash(('stash-money-%s'):format(data.name), data.name, 1, 1000)
    TriggerClientEvent('uniq_vendingmachine:notify', src, L('notify.vending_created'):format(data.name, data.price), 'success')

    Vending[data.name] = data

    
    local inventoryFilter = {}

    for k,v in pairs(Vending) do
        table.insert(inventoryFilter, v.name)
    end

    hookId = exports.ox_inventory:registerHook('buyItem', function(payload)
        exports.ox_inventory:AddItem(('stash-%s'):format(payload.shopType), 'money', payload.totalPrice)

        for k,v in pairs(Vending[payload.shopType].items) do
            if v.name == payload.itemName then
                v.stock -= 1
            end
        end

        return true
    end, { inventoryFilter = inventoryFilter })

    TriggerClientEvent('uniq_vending:sync', -1, Vending, false)
end)

lib.callback.register('uniq_vendingmachine:getJobs', function(source)
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

lib.callback.register('uniq_vendingmachine:getGrades', function(source, job)
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
        saveDB()

        exports.ox_inventory:removeHooks(hookId)
        exports.ox_inventory:removeHooks(swapItems)
    end
end)