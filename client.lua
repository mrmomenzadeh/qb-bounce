local QBCore = exports['qb-core']:GetCoreObject()

local is_bounce_mode_active = false
local original_height = {}
local bounce_time = 0

local function enumerate_vehicles()
    return coroutine.wrap(function()
        local handle, vehicle = FindFirstVehicle()
        local success
        repeat
            coroutine.yield(vehicle)
            success, vehicle = FindNextVehicle(handle)
        until not success
        EndFindVehicle(handle)
    end)
end

local function table_contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

local function get_vehicles_in_radius(coords, radius)
    local vehicles = {}
    for vehicle in enumerate_vehicles() do
        if #(coords - GetEntityCoords(vehicle)) < radius then
            vehicles[#vehicles + 1] = vehicle
        end
    end
    return vehicles
end

local function toggle_for_multiple_vehicles(vehicles)
    is_bounce_mode_active = not is_bounce_mode_active
    bounce_time = GetGameTimer()
    for _, vehicle in ipairs(vehicles) do
        local vehicle_type = GetVehicleClass(vehicle)
        if table_contains(Config.AllowedClasses, vehicle_type) then
            if is_bounce_mode_active then
                original_height[vehicle] = GetVehicleSuspensionHeight(vehicle)
                SetVehicleLights(vehicle, 2)
                SetVehicleFullbeam(vehicle, true)
            else
                SetVehicleSuspensionHeight(vehicle, original_height[vehicle] or 0)
                SetVehicleLights(vehicle, 0)
                SetVehicleFullbeam(vehicle, false)
            end
        end
    end
end

local function toggle_for_single_vehicle(vehicle)
    is_bounce_mode_active = not is_bounce_mode_active
    bounce_time = GetGameTimer()
    if is_bounce_mode_active then
        original_height[vehicle] = GetVehicleSuspensionHeight(vehicle)
        SetVehicleLights(vehicle, 2)
        SetVehicleFullbeam(vehicle, true)
    else
        SetVehicleSuspensionHeight(vehicle, original_height[vehicle] or 0)
        SetVehicleLights(vehicle, 0)
        SetVehicleFullbeam(vehicle, false)
    end
end

local function toggle_vehicle_bounce_mode()
    local player = PlayerPedId()
    local coords = GetEntityCoords(player)
    local vehicle = GetVehiclePedIsIn(player, false)
    local vehicle_type = GetVehicleClass(vehicle)
    
    if Config.AffectVehiclesInRange then
        local vehicles = get_vehicles_in_radius(coords, Config.Radius)
        toggle_for_multiple_vehicles(vehicles)
    else
        if vehicle ~= 0 and table_contains(Config.AllowedClasses, vehicle_type) then
            toggle_for_single_vehicle(vehicle)
        end
    end
end

CreateThread(function()
    while true do
        Wait(0)
        if is_bounce_mode_active then
            local current_time = GetGameTimer()
            local player = PlayerPedId()
            local coords = GetEntityCoords(player)
            local vehicles = get_vehicles_in_radius(coords, Config.Radius)
            local time_since_start = (current_time - bounce_time) / 1000.0
            
            local new_bounce_height = Config.BounceAmplitude * math.sin(2 * math.pi * Config.BounceSpeed * time_since_start)
            
            for _, vehicle in ipairs(vehicles) do
                local vehicle_type = GetVehicleClass(vehicle)
                if original_height[vehicle] and table_contains(Config.AllowedClasses, vehicle_type) then
                    SetVehicleSuspensionHeight(vehicle, original_height[vehicle] + new_bounce_height)
                end
            end
        end
    end
end)

RegisterNetEvent('vehicle_bouncemode:cl:start_bounce', function()
    toggle_vehicle_bounce_mode()
end)
