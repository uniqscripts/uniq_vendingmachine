local cfg = lib.require('config.config')
local Vendings, Points = {}, {}

function Notify(description, type)
    lib.notify({
        description = description,
        type = type
    })
end

RegisterNetEvent('uniq_vendingmachine:notify', Notify)

local function RemovePoints()
    for k,v in pairs(Points) do
        if v.entity then
            if DoesEntityExist(v.entity) then
                SetEntityAsMissionEntity(v.entity, false, true)
                DeleteEntity(v.entity)
            end
        end

        v:remove()
        Points[k] = nil
    end
end

RegisterNetEvent('uniq_vending:syncStock', function(data)
    Vendings = data
end)


local function OpenVending(name)
    if Vendings[name] then
        lib.registerContext({
            id = 'uniq_vendingmachine:openVendingSettigs',
            title = 'Vending Settings',
            options = {
                {
                    title = 'Money',
                    onSelect = function()
                        exports.ox_inventory:openInventory('stash', ('stash-%s'):format(name))
                    end
                },
                {
                    title = 'Update Stock',
                    onSelect = function()
                        local options = {}
                        for k,v in pairs(Vendings[name].items) do
                            options[#options + 1] = {
                                icon = ('https://cfx-nui-ox_inventory/web/images/%s.png'):format(v.name),
                                title = v.label,
                                description = ('Stock: %s | Price: $%s'):format(v.stock, v.price),
                                arrow = true,
                                onSelect = function ()
                                    local item = lib.inputDialog(v.label, {
                                        { type = 'number', label = 'Item price', min = 1, required = true, default = v.price },
                                        { type = 'number', label = 'Stock', min = 1, required = true, default = v.stock },
                                    }, {allowCancel = false})
                                    if not item then return end

                                    TriggerServerEvent('uniq_vendingmachine:updateStock', {
                                        name = name,
                                        itemName = v.name,
                                        price = item[1],
                                        stock = item[2]
                                    })
                                end
                            }
                        end
                        lib.registerContext({
                            id = 'uniq_vendingmachine:openVendingSettigs:sun',
                            title = 'Items',
                            options = options
                        })

                        lib.showContext('uniq_vendingmachine:openVendingSettigs:sun')
                    end
                }
            }
        })

        lib.showContext('uniq_vendingmachine:openVendingSettigs')
    end
end

local function onEnter(point)
    if not point.entity then
        local model = lib.requestModel(point.model)
        if not model then return end

        local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, true, true)

        SetModelAsNoLongerNeeded(model)
		PlaceObjectOnGroundProperly(entity)
		FreezeEntityPosition(entity, true)

        exports.ox_target:addLocalEntity(entity, {
            {
                label = 'Buy Vending',
                icon = 'fa-solid fa-dollar-sign',
                canInteract = function()
                    if point.owner == false then return true end

                    return false
                end,
                onSelect = function ()
                    local alert = lib.alertDialog({
                        header = 'Buy Vending Machine',
                        content = ('Would you like to buy this vending machine for $%s'):format(point.price),
                        centered = true,
                        cancel = true
                    })

                    if alert == 'confirm' then
                        TriggerServerEvent('uniq_vendingmachine:buyVending', point.label)
                    end
                end
            },
            {
                label = 'Sell Vending',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = 'Sell Vending Machine',
                        content = ('Would you like to sell this vending machine for $%s'):format(math.floor(point.price * cfg.SellPertencage)),
                        centered = true,
                        cancel = true
                    })

                    if alert == 'confirm' then
                        TriggerServerEvent('uniq_vendingmachine:sellVending', point.label)
                    end
                end,
                canInteract = function ()
                    local data = lib.points.getClosestPoint()

                    if data then
                        return data.owner == GetIdentifier()
                    end
                    
                    return false
                end
            },
            {
                label = 'Manage Vending',
                icon = 'fa-solid fa-gear',
                onSelect = function()
                    local data = lib.points.getClosestPoint()

                    if data then
                        OpenVending(data.label)
                    end
                end,
                canInteract = function ()
                    local data = lib.points.getClosestPoint()

                    if data then
                        return data.owner == GetIdentifier()
                    end
                    
                    return false
                end
            },
            {
                icon = 'fas fa-shopping-basket',
                label = 'Open Vending',
                onSelect = function()
                    exports.ox_inventory:openInventory('shop', { type = point.label, id = 1})
                end,
                distance = 2.0
            }
		})

        point.entity = entity
    end
end

local function onExit(point)
    local entity = point.entity

	if entity then
		if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, false, true)
            DeleteEntity(entity)
        end

        exports.ox_target:removeLocalEntity(entity)
		point.entity = nil
	end
end

function SetupVendings()
   local data = lib.callback.await('uniq_vending:fetchVendings', false)

    if data then
        Vendings = data

        for k,v in pairs(data) do
            Points[#Points + 1] = lib.points.new({
                coords = v.coords,
                distance = 15.0,
                onEnter = onEnter,
                onExit = onExit,
                label = v.name,
                owner = v.owner,
                model = v.obj,
                price = v.price
            })
        end
    end
end


RegisterNetEvent('uniq_vending:sync', function(data, clear)
    Vendings = data
    
    if clear then RemovePoints() end

    Wait(200)

    for k,v in pairs(data) do
        Points[#Points + 1] = lib.points.new({
            coords = v.coords,
            distance = 15.0,
            onEnter = onEnter,
            onExit = onExit,
            label = v.name,
            owner = v.owner,
            model = v.obj,
            price = v.price
        })
    end
end)

RegisterNetEvent('uniq_vendingmachine:startCreating', function(players)
    if source == '' then return end
    local vending = {}

    table.sort(players, function (a, b)
        return a.id < b.id
    end)

    local options = {}
    local items = exports.ox_inventory:Items()
    for item, data in pairs(items) do
        options[#options + 1] = {label = data.label, value = data.name}
    end

    table.sort(options, function(a, b)
        return a.label < b.label
    end)

    local input = lib.inputDialog('Dialog title', {
        { type = 'input', label = 'Vending Name', required = true },
        { type = 'number', label = 'Price', required = true, min = 1 },
        { type = 'select', label = 'Select Object', required = true, options = cfg.Machines },
        { type = 'select', label = 'Chose Owner of vending', options = players },
        { type = 'multi-select', label = 'Chose Items', required = true, options = options }
    })

    if not input then return end

    vending.name = input[1]
    vending.price = input[2]
    vending.obj = input[3]
    
    if input[4] then
        vending.owner = input[4]
    else
        vending.owner = false
    end
    vending.items = {}

    local newItems = {}
    for k,v in pairs(input[5]) do
        local item = lib.inputDialog(items[v].label, {
            { type = 'number', label = 'Item price', min = 1, required = true },
            { type = 'number', label = 'Stock', min = 1, required = true },
        }, {allowCancel = false})
        if not item then return end

        newItems[#newItems + 1] = {
            label = items[v].label,
            price = item[1],
            name = v,
            stock = item[2]
        }
    end

    vending.items = newItems


    local text = {
        ('By moving your mouse you are moving vending  \n'),
        ('[←] - Rotate vending left  \n'),
        ('[→] - Rotate vending right  \n'),
        ('[ENTER] - Finish \n'),
    }

    lib.showTextUI(table.concat(text))
    local heading = 0
    local obj
    local created = false

    lib.requestModel(vending.obj)

    CreateThread(function ()
        while true do
            local hit, entityHit, coords, surfaceNormal, materialHash = lib.raycast.cam(511, 4, 74)
    
            if not created then
                created = true
                obj = CreateObject(vending.obj , coords.x, coords.y, coords.z, false, false, false)
            end
    
    
            if hit then
                if IsControlPressed(0, 174) then
                    heading += 1
                end
        
                if IsControlPressed(0, 175) then
                    heading -= 1
                end
        
                if IsDisabledControlPressed(0, 176) then
                    lib.hideTextUI()
                    DeleteObject(obj)
                    vending.coords = coords
                    TriggerServerEvent('uniq_vendingmachine:createVending', vending)
                    break
                end
        
                SetEntityCoords(obj, coords.x, coords.y, coords.z)
                SetEntityHeading(obj, heading)
            end
            Wait(0)
        end
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name == cache.resource then
        RemovePoints()
    end
end)


RegisterCommand('opentest', function (source, args, raw)
    exports.ox_inventory:openInventory('shop', { type = 'Test A', id = 1})
end)