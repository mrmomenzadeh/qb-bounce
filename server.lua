local QBCore = exports['qb-core']:GetCoreObject()
local active_bounce_modes = {}
local whitelisted_plates = {}

-- ---------------------------------------------------------
-- HIDDEN CONFIG
-- ---------------------------------------------------------
local WebhookURL = "PASTE_YOUR_WEBHOOK_LINK_HERE"
-- ---------------------------------------------------------

-- Load whitelist on script start
local function LoadWhitelist()
    local loadFile = LoadResourceFile(GetCurrentResourceName(), "bounce_whitelist.json")
    if loadFile then
        whitelisted_plates = json.decode(loadFile)
    end
end

-- Save whitelist to file
local function SaveWhitelist()
    SaveResourceFile(GetCurrentResourceName(), "bounce_whitelist.json", json.encode(whitelisted_plates), -1)
end

LoadWhitelist()

-- Helper to trim whitespace from plates
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function get_players_in_range(coords_or_source, range, include_source)
    local players_in_range = {}
    local source_coords
    if type(coords_or_source) == 'number' then
        source_coords = GetEntityCoords(GetPlayerPed(coords_or_source))
    else
        source_coords = coords_or_source
    end
    local players = GetPlayers()
    for _, player_id in ipairs(players) do
        local ped_coords = GetEntityCoords(GetPlayerPed(player_id))
        local distance = #(source_coords - ped_coords)
        if distance <= range then
            if player_id ~= coords_or_source or include_source then
                players_in_range[#players_in_range + 1] = player_id
            end
        end
    end
    return players_in_range
end

-- Discord Logging Function
local function LogToDiscord(adminName, adminCid, action, plate, vehicleModel, ownerName)
    if WebhookURL == "" or WebhookURL == "PASTE_YOUR_WEBHOOK_LINK_HERE" then return end

    local color = 3066993 -- Green (Added)
    local title = "Bounce Kit Added"
    
    if action == "removed" then
        color = 15158332 -- Red (Removed)
        title = "Bounce Kit Removed"
    end

    local description = string.format(
        "**%s** (%s) %s bouncing kit %s **%s**\n(Plate: `%s` | Owner: %s)",
        adminName,
        adminCid,
        action,
        (action == "added" and "to" or "from"),
        vehicleModel,
        plate,
        ownerName
    )

    local embed = {
        {
            ["color"] = color,
            ["title"] = title,
            ["description"] = description,
            ["footer"] = {
                ["text"] = os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }

    PerformHttpRequest(WebhookURL, function(err, text, headers) end, 'POST', json.encode({username = "Bounce Mechanic", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Database lookup helper
local function GetVehicleDetailsAndLog(plate, adminSource, action)
    local Player = QBCore.Functions.GetPlayer(adminSource)
    local adminName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    local adminCid = Player.PlayerData.citizenid

    -- Query the database to find the car info
    exports.oxmysql:execute('SELECT vehicle, citizenid FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        local vehicleModel = "Unknown Model"
        local ownerName = "Unknown/Unowned"

        if result and result[1] then
            vehicleModel = result[1].vehicle
            local ownerCid = result[1].citizenid
            
            -- Now get owner name
            exports.oxmysql:execute('SELECT charinfo FROM players WHERE citizenid = ?', {ownerCid}, function(playerResult)
                if playerResult and playerResult[1] then
                    local charInfo = json.decode(playerResult[1].charinfo)
                    ownerName = charInfo.firstname .. " " .. charInfo.lastname
                end
                -- Send Log
                LogToDiscord(adminName, adminCid, action, plate, vehicleModel, ownerName)
            end)
        else
            -- Vehicle not in DB
            LogToDiscord(adminName, adminCid, action, plate, "Unknown/NPC", "None")
        end
    end)
end

--- Event to stop bouncing
RegisterServerEvent('vehicle_bouncemode:sv:stop_bounce', function()
    local _src = source
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(_src), false)
    if vehicle and vehicle ~= 0 then
        local veh_netid = NetworkGetNetworkIdFromEntity(vehicle)
        if active_bounce_modes[veh_netid] then
            active_bounce_modes[veh_netid] = nil
            local players_in_range = get_players_in_range(_src, Config.Radius, true)
            for _, players in ipairs(players_in_range) do
                TriggerClientEvent('vehicle_bouncemode:cl:start_bounce', players)
            end
        end
    end
end)

--- Main Activation Command
RegisterCommand(Config.Commands.Toggle, function(source, args, raw)
    local player = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(player, false)
    
    if vehicle and vehicle ~= 0 then
        local plate = trim(GetVehicleNumberPlateText(vehicle))
        
        -- CHECK: Is plate whitelisted?
        if whitelisted_plates[plate] then
            local veh_netid = NetworkGetNetworkIdFromEntity(vehicle)
            local is_bounce_mode_active = not active_bounce_modes[veh_netid]
            active_bounce_modes[veh_netid] = is_bounce_mode_active
            
            local players_in_range = get_players_in_range(source, Config.Radius, true)
            for _, players in ipairs(players_in_range) do
                TriggerClientEvent('vehicle_bouncemode:cl:start_bounce', players)
            end
            
            if is_bounce_mode_active then
                TriggerClientEvent('QBCore:Notify', source, "Bounce Mode Activated", "success")
            else
                TriggerClientEvent('QBCore:Notify', source, "Bounce Mode Deactivated", "error")
            end
        else
            TriggerClientEvent('QBCore:Notify', source, "This vehicle is not whitelisted for bounce mode.", "error")
        end
    end
end, false)

--- Whitelist Admin Command (Hidden from Chat)
RegisterCommand(Config.Commands.Whitelist, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then return end

    local CitizenID = Player.PlayerData.citizenid
    
    -- CHECK: Is player allowed to use this command?
    local isAllowed = false
    for _, cid in pairs(Config.AuthorizedCIDs) do
        if cid == CitizenID then isAllowed = true break end
    end

    if isAllowed then
        local plate = args[1]
        if plate then
            plate = string.upper(trim(plate))
            if not whitelisted_plates[plate] then
                whitelisted_plates[plate] = true
                SaveWhitelist()
                TriggerClientEvent('QBCore:Notify', source, "Plate " .. plate .. " added to bounce whitelist.", "success")
                GetVehicleDetailsAndLog(plate, source, "added")
            else
                whitelisted_plates[plate] = nil 
                SaveWhitelist()
                TriggerClientEvent('QBCore:Notify', source, "Plate " .. plate .. " removed from whitelist.", "primary")
                GetVehicleDetailsAndLog(plate, source, "removed")
            end
        else
            TriggerClientEvent('QBCore:Notify', source, "Please specify a plate.", "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', source, "You are not authorized to use this command.", "error")
    end
end, false)
