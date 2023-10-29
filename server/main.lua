local cfg = lib.require('config.config')
local Vending = {}
local hookId

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
            local inventory = {}

            for _, item in pairs(data.items) do
                table.insert(inventory, { name = item.name, price = item.price, count = item.stock })
            end

            exports.ox_inventory:RegisterShop(v.name, {
                name = v.name,
                inventory = inventory,
            })

            exports.ox_inventory:RegisterStash(('stash-%s'):format(data.name), v.name, 1, 1000)

            Vending[v.name] = data

            table.insert(inventoryFilter, v.name)
        end


        hookId = exports.ox_inventory:registerHook('buyItem', function(payload)
            exports.ox_inventory:AddItem(('stash-%s'):format(payload.shopType), 'money', payload.totalPrice)

            for k,v in pairs(Vending[payload.shopType].items) do
                if v.name == payload.itemName then
                    v.stock -= 1
                    TriggerClientEvent('uniq_vending:syncStock', -1, Vending)
                end
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

                table.insert(inventory, { name = v.name, price = v.price, count = v.stock })
            end

            exports.ox_inventory:RegisterShop(data.name, {
                name = data.name,
                inventory = inventory,
            })

            TriggerClientEvent('uniq_vending:syncStock', -1, Vending)
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
            options[#options + 1] = { label = ('%s | %s'):format(v.PlayerData.name, v.PlayerData.source), value = v.PlayerData.source }
        end
    end

    TriggerClientEvent('uniq_vendingmachine:startCreating', source, options)
end)

RegisterNetEvent('uniq_vendingmachine:buyVending', function(name)
    local src = source

    if Vending[name] then
        if exports.ox_inventory:Search(src, 'count', 'money') >= Vending[name].price then
            exports.ox_inventory:RemoveItem(src, 'money', Vending[name].price)

            local active, identifier = GetIdentifier(src)
            Vending[name].owner = identifier
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

    if data.owner ~= false then
        local active, identifier = GetIdentifier(data.owner)

        if active then
            data.owner = identifier
        else
            TriggerClientEvent('uniq_vendingmachine:notify', src, L('notify.no_targeted_owner'), 'error')
        end
    end

    MySQL.insert('INSERT INTO `uniq_vending` (name, data) VALUES (?, ?)', {data.name, json.encode(data)})

    local inventory = {}

    for _, item in pairs(data.items) do
        table.insert(inventory, { name = item.name, price = item.price, count = item.stock })
    end

    exports.ox_inventory:RegisterShop(data.name, {
        name = data.name,
        inventory = inventory,
    })

    exports.ox_inventory:RegisterStash(('stash-%s'):format(data.name), data.name, 1, 1000)
    TriggerClientEvent('uniq_vendingmachine:notify', src, L('notify.vending_created'):format(data.name, data.price), 'error')

    Vending[data.name] = data

    if hookId then
        exports.ox_inventory:removeHooks(hookId)
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
    end

    TriggerClientEvent('uniq_vending:sync', -1, Vending, false)
end)


local function saveDB()
    local insertTable = {}
    if table.type(Vending) == 'empty' then return end

    for k,v in pairs(Vending) do
        insertTable[#insertTable + 1] = { query = 'UPDATE `uniq_vending` SET `data` = ? WHERE `name` = ?', values = { json.encode(v, {sort_keys = true}), v.name } }
    end

    MySQL.transaction(insertTable)
end

AddEventHandler('onResourceStop', function(name)
    if name == cache.resource then
        saveDB()

        if hookId then
            exports.ox_inventory:removeHooks(hookId)
        end
    end
end)