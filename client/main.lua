local cfg = lib.require('config.config')
local Vendings, Points = {}, {}

local function Notify(description, type)
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
    if source == '' then return end
    Vendings = data
end)

local function OpenVending(name)
    if Vendings[name] then
        lib.registerContext({
            id = 'uniq_vendingmachine:openVendingSettigs',
            title = L('context.vending_settings'),
            options = {
                {
                    title = L('context.money'),
                    onSelect = function()
                        exports.ox_inventory:openInventory('stash', ('stash-%s'):format(name))
                    end
                },
                {
                    title = L('context.update_stock'),
                    onSelect = function()
                        local options = {}
                        for k,v in pairs(Vendings[name].items) do
                            options[#options + 1] = {
                                icon = ('https://cfx-nui-ox_inventory/web/images/%s.png'):format(v.name),
                                title = v.label,
                                description = L('context.stock_price'):format(v.stock, v.price),
                                arrow = true,
                                onSelect = function ()
                                    local item = lib.inputDialog(v.label, {
                                        { type = 'number', label = L('context.item_price'), min = 1, required = true, default = v.price },
                                        { type = 'number', label = L('context.item_stock'), min = 1, required = true, default = v.stock },
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
                            title = L('context.items'),
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


function ownerTarget(entity, point)
    exports.ox_target:addLocalEntity(entity, {
        {
            label = L('target.buy_vending'),
            icon = 'fa-solid fa-dollar-sign',
            canInteract = function()
                if point.owner == false then return true end

                return false
            end,
            onSelect = function ()
                local alert = lib.alertDialog({
                    header = L('target.buy_vending'),
                    content = L('alert.buy_vending_confirm'):format(point.price),
                    centered = true,
                    cancel = true
                })

                if alert == 'confirm' then
                    TriggerServerEvent('uniq_vendingmachine:buyVending', point.label)
                end
            end
        },
        {
            label = L('target.sell_vending'),
            onSelect = function()
                local alert = lib.alertDialog({
                    header = L('target.sell_vending'),
                    content = L('alert.sell_vending_confirm'):format(math.floor(point.price * cfg.SellPertencage)),
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
            label = L('target.manage_vending'),
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
            label = L('target.access_vending'),
            onSelect = function()
                exports.ox_inventory:openInventory('shop', { type = point.label, id = 1})
            end,
            distance = 2.0
        }
    })
end

function GenerateTarget(entity, point)
    local options = {
        {
            icon = 'fas fa-shopping-basket',
            label = L('target.access_vending'),
            onSelect = function()
                exports.ox_inventory:openInventory('shop', { type = point.label, id = 1})
            end,
            distance = 2.0
        }
    }

    if not point.owner or point.owner == false then
        options[#options + 1] = {
            {
                label = L('target.buy_vending'),
                icon = 'fa-solid fa-dollar-sign',
                onSelect = function ()
                    local alert = lib.alertDialog({
                        header = L('target.buy_vending'),
                        content = L('alert.buy_vending_confirm'):format(point.price),
                        centered = true,
                        cancel = true
                    })
    
                    if alert == 'confirm' then
                        TriggerServerEvent('uniq_vendingmachine:buyVending', point.label)
                    end
                end
            },
        }
    end

    if type(point.owner) == 'string' then
        local data = lib.points.getClosestPoint()
        
        if data and data.owner == GetIdentifier() then
            options[#options+1] = {
                {
                    label = L('target.sell_vending'),
                    onSelect = function()
                        local alert = lib.alertDialog({
                            header = L('target.sell_vending'),
                            content = L('alert.sell_vending_confirm'):format(math.floor(point.price * cfg.SellPertencage)),
                            centered = true,
                            cancel = true
                        })
        
                        if alert == 'confirm' then
                            TriggerServerEvent('uniq_vendingmachine:sellVending', point.label)
                        end
                    end
                },
            }
        end
    end

    exports.ox_target:addLocalEntity(entity, options)
end

local function onEnter(point)
    if not point.entity then
        local model = lib.requestModel(point.model)
        if not model then return end

        local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, true, true)

        SetModelAsNoLongerNeeded(model)
		PlaceObjectOnGroundProperly(entity)
		FreezeEntityPosition(entity, true)

        GenerateTarget(entity, point)

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
    if source == '' then return end
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
        options[#options + 1] = { label = data.label, value = data.name }
    end

    table.sort(options, function(a, b)
        return a.label < b.label
    end)

    local input = lib.inputDialog(L('input.vending_creator'), {
        { type = 'input', label = L('input.vending_label'), required = true },
        { type = 'number', label = L('input.vending_price'), required = true, min = 1 },
        { type = 'select', label = L('input.select_object'), required = true, options = cfg.Machines, clearable = true },
        { type = 'select', label = L('input.owned_type.title'), description = L('input.owned_type.desc'), options = {
            { label = L('input.owned_type.a'), value = 'a' },
            { label = L('input.owned_type.b'), value = 'b' },
        }, clearable = true },
        { type = 'multi-select', label = L('input.select_items'), required = true, options = options }
    })

    if not input then return end

    vending.name = input[1]
    vending.price = input[2]
    vending.obj = input[3]
    
    if not input[4] then
        vending.owner = false
    end

    if input[4] == 'a' then
        local owner = lib.inputDialog(L('input.vending_creator'), {
            { type = 'select', label = L('input.player_owned_label'), description = L('input.player_owned_desc'), required = true, options = players, clearable = true }
        })
        if not owner then return end

        vending.owner = owner[1]
    elseif input[4] == 'b' then
        local jobs = lib.callback.await('uniq_vendingmachine:getJobs', 100)

        table.sort(jobs, function (a, b)
            return a.label < b.label
        end)

        local owner = lib.inputDialog(L('input.vending_creator'), {
            { type = 'select', label = L('input.job_owned_label'), description = L('input.job_owned_desc'), required = true, options = jobs, clearable = true }
        })
        if not owner then return end

        local grades = lib.callback.await('uniq_vendingmachine:getGrades', 100, owner[1])

        table.sort(grades, function (a, b)
            return a.value < b.value
        end)

        local grade = lib.inputDialog(L('input.vending_creator'), {
            { type = 'select', label = L('input.chose_grade'), description = L('input.chose_grade_desc'), required = true, options = grades, clearable = true }
        })

        if not grade then return end

        vending.owner = {
            [owner[1]] = grade[1]
        }

        print(json.encode(vending.owner, {indent = true}))
    end

    vending.items = {}

    local newItems = {}
    for k,v in pairs(input[5]) do
        
        local item = lib.inputDialog(items[v].label, {
            { type = 'number', label = L('context.item_price'), min = 1, required = true },
            { type = 'number', label = L('context.item_stock'), min = 1, required = true },
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

    lib.showTextUI(table.concat(L('text_ui.help')))
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


RegisterNetEvent('uniq_vending:client:dellvending', function(data)
    if source == '' then return end

    table.sort(data, function (a, b)
        return a.value < b.value
    end)

    local input = lib.inputDialog('Delete Vending', {
        { type = 'select', label = L('context.item_price'), required = true, clearable = true, options = data }
    })

    if not input then return end

    TriggerServerEvent('uniq_vending:server:dellvending', input[1])
end)

AddEventHandler('onResourceStop', function(name)
    if name == cache.resource then
        RemovePoints()
    end
end)

RegisterCommand('opentest', function (source, args, raw)
    exports.ox_inventory:openInventory('shop', { type = 'Test A', id = 1})
end)