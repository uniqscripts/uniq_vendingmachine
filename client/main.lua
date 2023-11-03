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

local function onEnter(point)
    if not point.entity then
        local model = lib.requestModel(point.model)
        if not model then return end

        local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, true, true)

        SetModelAsNoLongerNeeded(model)
		PlaceObjectOnGroundProperly(entity)
		FreezeEntityPosition(entity, true)

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

		point.entity = nil
	end
end

local menu = {
    id = 'uniq_vendingmachine:main',
    title = 'Vending Machine',
    options = {}
}

function GenerateMenu(point)
    local options = {
        {
            icon = 'fas fa-shopping-basket',
            title = L('context.access_vending'),
            onSelect = function()
                exports.ox_inventory:openInventory('shop', { type = point.label, id = 1})
            end,
            distance = 2.0
        }
    }

    if not point.owner or point.owner == false then
        options[#options + 1] = {
            title = L('context.buy_vending'),
            icon = 'fa-solid fa-dollar-sign',
            onSelect = function ()
                local alert = lib.alertDialog({
                    header = L('context.buy_vending'),
                    content = L('alert.buy_vending_confirm'):format(point.price),
                    centered = true,
                    cancel = true
                })

                if alert == 'confirm' then
                    TriggerServerEvent('uniq_vendingmachine:buyVending', point.label)
                end
            end
        }
    end

    -- owned by player
    if type(point.owner) == 'string' then
        if point.owner == GetIdentifier() then
            options[#options+1] = {
                title = L('context.sell_vending'),
                icon = 'fa-solid fa-money-bill-trend-up',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = L('context.sell_vending'),
                        content = L('alert.sell_vending_confirm'):format(math.floor(point.price * cfg.SellPertencage)),
                        centered = true,
                        cancel = true
                    })
    
                    if alert == 'confirm' then
                        TriggerServerEvent('uniq_vendingmachine:sellVending', point.label)
                    end
                end
            }

            options[#options + 1] = {
                title = L('context.stock'),
                icon = 'fa-solid fa-box',
                onSelect = function()
                    exports.ox_inventory:openInventory('stash', ('%s'):format(point.label))
                end
            }

            options[#options + 1] = {
                title = L('context.money'),
                icon = 'fa-solid fa-sack-dollar',
                onSelect = function()
                    exports.ox_inventory:openInventory('stash', ('stash-money-%s'):format(point.label))
                end
            }
        end
        -- owned by job
    elseif type(point.owner) == 'table' then
        local job, grade = GetJob()

        if point.owner[job] and point.owner[job] >= grade then
            options[#options+1] = {
                title = L('context.sell_vending'),
                icon = 'fa-solid fa-money-bill-trend-up',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = L('context.sell_vending'),
                        content = L('alert.sell_vending_confirm'):format(math.floor(point.price * cfg.SellPertencage)),
                        centered = true,
                        cancel = true
                    })
    
                    if alert == 'confirm' then
                        TriggerServerEvent('uniq_vendingmachine:sellVending', point.label)
                    end
                end
            }

            options[#options + 1] = {
                title = L('context.stock'),
                icon = 'fa-solid fa-box',
                onSelect = function()
                    exports.ox_inventory:openInventory('stash', ('%s'):format(point.label))
                end
            }

            options[#options + 1] = {
                title = L('context.money'),
                icon = 'fa-solid fa-sack-dollar',
                onSelect = function()
                    exports.ox_inventory:openInventory('stash', ('stash-money-%s'):format(point.label))
                end
            }
        end
    end

    menu.options = options

    lib.registerContext(menu)

    return lib.showContext(menu.id)
end

local function nearby(point)
    if point.currentDistance < 1.4 then
        if IsControlJustPressed(0, 38) then
            GenerateMenu(point)
        end
    end
end

local textUI = false
CreateThread(function()
    while true do
        local point = lib.points.getClosestPoint()

        if point then
            if point.currentDistance < 1.4 then
                if not textUI then
                    textUI = true
                    lib.showTextUI('[E] - Open Vending')
                end
            else
                if textUI then
                    textUI = false
                    lib.hideTextUI()
                end
            end
        end

        Wait(300)
    end
end)

function SetupVendings()
   local data = lib.callback.await('uniq_vending:fetchVendings', false)

    if data then
        Vendings = data

        for k,v in pairs(data) do
            Points[#Points + 1] = lib.points.new({
                coords = v.coords,
                distance = 15.0,
                onEnter = onEnter,
                nearby = nearby,
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
            nearby = nearby,
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

    local input = lib.inputDialog(L('input.vending_creator'), {
        { type = 'input', label = L('input.vending_label'), required = true },
        { type = 'number', label = L('input.vending_price'), required = true, min = 1 },
        { type = 'select', label = L('input.select_object'), required = true, options = cfg.Machines, clearable = true },
        { type = 'select', label = L('input.owned_type.title'), options = {
            { label = L('input.owned_type.a'), value = 'a' },
            { label = L('input.owned_type.b'), value = 'b' },
        }, clearable = true, required = true },
    })

    if not input then return end

    vending.name = input[1]
    vending.price = input[2]
    vending.obj = input[3]

    if input[4] == 'a' then
        local owner = lib.inputDialog(L('input.vending_creator'), {
            { type = 'select', label = L('input.player_owned_label'), description = L('input.player_owned_desc'), options = players, clearable = true }
        })
        
        if not owner then
            vending.owner = false
        else
            vending.owner = owner[1]
        end
        vending.type = 'player'
    elseif input[4] == 'b' then
        local jobs = lib.callback.await('uniq_vendingmachine:getJobs', 100)

        table.sort(jobs, function (a, b)
            return a.label < b.label
        end)

        local owner = lib.inputDialog(L('input.vending_creator'), {
            { type = 'select', label = L('input.job_owned_label'), description = L('input.job_owned_desc'), options = jobs, clearable = true }
        })

        if not owner[1] then
            vending.owner = false
        else
            local grades = lib.callback.await('uniq_vendingmachine:getGrades', 100, owner[1])

            table.sort(grades, function (a, b)
                return a.value < b.value
            end)
    
            local grade = lib.inputDialog(L('input.vending_creator'), {
                { type = 'select', label = L('input.chose_grade'), description = L('input.chose_grade_desc'), required = true, options = grades, clearable = true }
            })
    
            if not grade then return end
    
            vending.owner = { [owner[1]] = grade[1] }
        end
        vending.type = 'job'
    end

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
        { type = 'select', label = L('input.job_owned_label'), required = true, clearable = true, options = data }
    })

    if not input then return end

    TriggerServerEvent('uniq_vending:server:dellvending', input[1])
end)


RegisterNetEvent('uniq_vending:selectCurrency', function(payload)
    if source == '' then return end
    local itemNames = {}

    for item, data in pairs(exports.ox_inventory:Items()) do
        if not cfg.CantBeCurrency[data.name] then
            itemNames[#itemNames + 1] = { label = data.label, value = data.name }
        end
    end

    local input = lib.inputDialog(payload.fromSlot.label, {
        { type = 'number', label = L('context.item_price_per_one'), required = true, min = 1 },
        { type = 'select', label = L('context.currency'), description = L('context.currency_desc'), clearable = true, options = itemNames }
    }, { allowCancel = false })

    if not input[2] then
        input[2] = 'money'
    end

    TriggerServerEvent('uniq_vendingmachine:setData', input[1], input[2], payload)
end)

AddEventHandler('onResourceStop', function(name)
    if name == cache.resource then
        RemovePoints()
        if textUI then
            lib.hideTextUI()
        end
    end
end)