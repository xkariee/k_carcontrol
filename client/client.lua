local nuiReady = false
local nuiFocused = false
local currentVehicle = 0
local windowStates = {}

local doorDefinitions = {
    { index = 0, label = 'Przód L', icon = 'door' },
    { index = 1, label = 'Przód P', icon = 'door' },
    { index = 2, label = 'Tył L', icon = 'door' },
    { index = 3, label = 'Tył P', icon = 'door' },
    { index = 4, label = 'Maska', icon = 'hood' },
    { index = 5, label = 'Bagażnik', icon = 'trunk' },
}

local windowDefinitions = {
    { index = 0, label = 'Przód L' },
    { index = 1, label = 'Przód P' },
    { index = 2, label = 'Tył L' },
    { index = 3, label = 'Tył P' },
}

local function sendUpdate(data)
    if not nuiReady then
        return
    end

    SendNUIMessage({
        action = 'carcontrol:update',
        data = data
    })
end

local function getPlayerVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return 0
    end

    return vehicle
end

local function requestControl(entity)
    if NetworkHasControlOfEntity(entity) then
        return true
    end

    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 500

    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

local function getVehicleName(vehicle)
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(displayName)

    if not label or label == 'NULL' then
        return displayName
    end

    return label
end

local function getLightMode(vehicle)
    local _, lightsOn, highBeamsOn = GetVehicleLightsState(vehicle)

    if highBeamsOn == 1 or highBeamsOn == true then
        return 2
    end

    if lightsOn == 1 or lightsOn == true then
        return 1
    end

    return 0
end

local function getDoorStates(vehicle)
    local doors = {
        {
            index = -1,
            label = 'Wszystkie',
            icon = 'car',
            open = false,
            available = true
        }
    }

    local anyDoorOpen = false

    for _, definition in ipairs(doorDefinitions) do
        local available = GetIsDoorValid(vehicle, definition.index)
        local isOpen = available and GetVehicleDoorAngleRatio(vehicle, definition.index) > 0.05

        if isOpen then
            anyDoorOpen = true
        end

        doors[#doors + 1] = {
            index = definition.index,
            label = definition.label,
            icon = definition.icon,
            open = isOpen,
            available = available
        }
    end

    doors[1].open = anyDoorOpen
    return doors
end

local function getSeatLabel(index)
    if index == -1 then
        return 'Kierowca'
    elseif index == 0 then
        return 'Pasażer'
    elseif index == 1 then
        return 'Tył lewy'
    elseif index == 2 then
        return 'Tył prawy'
    end

    return ('Siedzenie %d'):format(index + 2)
end

local function getWindowStates(vehicle)
    local vehicleKey = tostring(vehicle)
    local storedStates = windowStates[vehicleKey] or {}
    local seatCount = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
    local windows = {
        {
            index = -1,
            label = 'Wszystkie',
            down = false,
            available = true
        }
    }
    local anyWindowDown = false

    for _, definition in ipairs(windowDefinitions) do
        local available = definition.index < 2 or seatCount > 2
        local isDown = available and storedStates[definition.index] == true

        if isDown then
            anyWindowDown = true
        end

        windows[#windows + 1] = {
            index = definition.index,
            label = definition.label,
            down = isDown,
            available = available
        }
    end

    windows[1].down = anyWindowDown
    return windows
end

local function getSeatStates(vehicle)
    local ped = PlayerPedId()
    local seatCount = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
    local seats = {}

    for index = -1, seatCount - 2 do
        local occupant = GetPedInVehicleSeat(vehicle, index)

        seats[#seats + 1] = {
            index = index,
            label = getSeatLabel(index),
            occupied = occupant ~= 0 and occupant ~= ped,
            current = occupant == ped
        }
    end

    return seats
end

local function isNeonAvailable(vehicle)
    -- GTA safely ignores neon toggles on models that do not support them.
    return DoesEntityExist(vehicle)
end

local function isNeonOn(vehicle)
    for index = 0, 3 do
        if IsVehicleNeonLightEnabled(vehicle, index) then
            return true
        end
    end

    return false
end

local function buildVehicleState(vehicle)
    return {
        visible = true,
        focused = nuiFocused,
        vehicleName = getVehicleName(vehicle),
        engineOn = GetIsVehicleEngineRunning(vehicle),
        neonOn = isNeonOn(vehicle),
        neonAvailable = isNeonAvailable(vehicle),
        lightsMode = getLightMode(vehicle),
        doors = getDoorStates(vehicle),
        windows = getWindowStates(vehicle),
        seats = getSeatStates(vehicle)
    }
end

local function refreshState()
    local vehicle = getPlayerVehicle()

    if vehicle == 0 then
        currentVehicle = 0

        if nuiFocused then
            nuiFocused = false
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
        end

        sendUpdate({
            visible = false,
            focused = false
        })
        return
    end

    currentVehicle = vehicle
    sendUpdate(buildVehicleState(vehicle))
end

local function withVehicle(callback)
    local vehicle = getPlayerVehicle()

    if vehicle == 0 or not requestControl(vehicle) then
        return false
    end

    callback(vehicle)
    Wait(50)
    refreshState()
    return true
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    refreshState()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    nuiFocused = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    sendUpdate({ focused = false })
    cb({ ok = true })
end)

RegisterNUICallback('toggleEngine', function(_, cb)
    local success = withVehicle(function(vehicle)
        local nextState = not GetIsVehicleEngineRunning(vehicle)
        SetVehicleEngineOn(vehicle, nextState, false, true)
    end)

    cb({ ok = success })
end)

RegisterNUICallback('toggleDoor', function(data, cb)
    local success = withVehicle(function(vehicle)
        local index = tonumber(data.index)

        if index == -1 then
            local anyDoorOpen = false

            for _, definition in ipairs(doorDefinitions) do
                if GetIsDoorValid(vehicle, definition.index)
                    and GetVehicleDoorAngleRatio(vehicle, definition.index) > 0.05 then
                    anyDoorOpen = true
                    break
                end
            end

            for _, definition in ipairs(doorDefinitions) do
                if GetIsDoorValid(vehicle, definition.index) then
                    if not anyDoorOpen then
                        SetVehicleDoorOpen(vehicle, definition.index, false, false)
                    else
                        SetVehicleDoorShut(vehicle, definition.index, false)
                    end
                end
            end
        elseif index and GetIsDoorValid(vehicle, index) then
            if GetVehicleDoorAngleRatio(vehicle, index) > 0.05 then
                SetVehicleDoorShut(vehicle, index, false)
            else
                SetVehicleDoorOpen(vehicle, index, false, false)
            end
        end
    end)

    cb({ ok = success })
end)

RegisterNUICallback('toggleWindow', function(data, cb)
    local success = withVehicle(function(vehicle)
        local vehicleKey = tostring(vehicle)
        local index = tonumber(data.index)
        local states = windowStates[vehicleKey] or {}
        local seatCount = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
        windowStates[vehicleKey] = states

        if index == -1 then
            local anyWindowDown = false

            for _, definition in ipairs(windowDefinitions) do
                if states[definition.index] then
                    anyWindowDown = true
                    break
                end
            end

            for _, definition in ipairs(windowDefinitions) do
                local available = definition.index < 2 or seatCount > 2

                if available then
                    if anyWindowDown then
                        RollUpWindow(vehicle, definition.index)
                        states[definition.index] = false
                    else
                        RollDownWindow(vehicle, definition.index)
                        states[definition.index] = true
                    end
                end
            end
        elseif index and index >= 0 and index <= 3 and (index < 2 or seatCount > 2) then
            if states[index] then
                RollUpWindow(vehicle, index)
                states[index] = false
            else
                RollDownWindow(vehicle, index)
                states[index] = true
            end
        end
    end)

    cb({ ok = success })
end)

RegisterNUICallback('toggleNeon', function(_, cb)
    local success = withVehicle(function(vehicle)
        local enabled = not isNeonOn(vehicle)

        for index = 0, 3 do
            SetVehicleNeonLightEnabled(vehicle, index, enabled)
        end
    end)

    cb({ ok = success })
end)

RegisterNUICallback('cycleLights', function(_, cb)
    local success = withVehicle(function(vehicle)
        local nextMode = (getLightMode(vehicle) + 1) % 3

        if nextMode == 0 then
            SetVehicleFullbeam(vehicle, false)
            SetVehicleLights(vehicle, 1)
        elseif nextMode == 1 then
            SetVehicleFullbeam(vehicle, false)
            SetVehicleLights(vehicle, 2)
        else
            SetVehicleLights(vehicle, 2)
            SetVehicleFullbeam(vehicle, true)
        end
    end)

    cb({ ok = success })
end)

RegisterNUICallback('switchSeat', function(data, cb)
    local success = withVehicle(function(vehicle)
        local index = tonumber(data.index)

        if index and IsVehicleSeatFree(vehicle, index) then
            SetPedIntoVehicle(PlayerPedId(), vehicle, index)
        end
    end)

    cb({ ok = success })
end)

RegisterCommand('carcontrol', function()
    local vehicle = getPlayerVehicle()

    if vehicle == 0 then
        return
    end

    nuiFocused = not nuiFocused
    SetNuiFocus(nuiFocused, nuiFocused)
    SetNuiFocusKeepInput(nuiFocused)
    sendUpdate({
        visible = true,
        focused = nuiFocused
    })
end, false)

RegisterKeyMapping('carcontrol', 'Sterowanie pojazdem', 'keyboard', 'F7')

CreateThread(function()
    while true do
        local vehicle = getPlayerVehicle()

        if vehicle ~= currentVehicle or vehicle ~= 0 then
            refreshState()
        end

        Wait(vehicle == 0 and 750 or 250)
    end
end)

CreateThread(function()
    while true do
        if nuiFocused then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 75, true)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end)
