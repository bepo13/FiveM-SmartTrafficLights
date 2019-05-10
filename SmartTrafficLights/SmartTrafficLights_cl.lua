-- PARAMETERS --
local SEARCH_STEP_SIZE = 10.0                   -- Step size to search for traffic lights
local SEARCH_MIN_DISTANCE = 20.0                -- Minimum distance to search for traffic lights
local SEARCH_MAX_DISTANCE = 60.0                -- Maximum distance to search for traffic lights
local SEARCH_RADIUS = 10.0                      -- Radius to search for traffic light after translating coordinates
local HEADING_THRESHOLD = 20.0                  -- Player must match traffic light orientation within threshold (degrees)
local TRAFFIC_LIGHT_POLL_FREQUENCY_MS = 1000    -- How often to check if a light is red (ms)
local TRAFFIC_LIGHT_DURATION_MS = 5000          -- Duration to turn light green (ms)

-- Array of all traffic light hashes
local trafficLightObjects = {
    [0] = 0x3e2b73a4,   -- prop_traffic_01a
    [1] = 0x336e5e2a,   -- prop_traffic_01b
    [2] = 0xd8eba922,   -- prop_traffic_01d
    [3] = 0xd4729f50,   -- prop_traffic_02a
    [4] = 0x272244b2,   -- prop_traffic_02b
    [5] = 0x33986eae,   -- prop_traffic_03a
    [6] = 0x2323cdc5    -- prop_traffic_03b
}

-- Client side event to set traffic light green, wait and reset state
RegisterNetEvent("SmartTrafficLights:setLight")
AddEventHandler("SmartTrafficLights:setLight", function(coords)
    -- Find traffic light using trafficLightObjects array
    for _, trafficLightObject in pairs(trafficLightObjects) do
        trafficLight = GetClosestObjectOfType(coords, 1.0, trafficLightObject, false, false, false)
        if trafficLight ~= 0 then
            -- Set traffic light green, delay and reset state
            SetEntityTrafficlightOverride(trafficLight, 0)
            Citizen.Wait(TRAFFIC_LIGHT_DURATION_MS)
            SetEntityTrafficlightOverride(trafficLight, -1)
            break
        end
    end
end)

-- Main thread --
Citizen.CreateThread(function()
    -- Initialize local variables
    local lastTrafficLight = 0

    -- Loop forever and check traffic lights at set interval
    while true do
        Citizen.Wait(TRAFFIC_LIGHT_POLL_FREQUENCY_MS)
        
        -- Get player and check traffic lights when in a vehicle and stopped
        local player = GetPlayerPed(-1)
        if IsPedInAnyVehicle(player) and IsVehicleStopped(GetVehiclePedIsIn(player)) then
            -- Get player position, heading and search coordinates
            local playerPosition = GetEntityCoords(player)
            local playerHeading = GetEntityHeading(player)

            -- Search in front of car for traffic light that matches player heading
            local trafficLight = 0
            for searchDistance = SEARCH_MAX_DISTANCE, SEARCH_MIN_DISTANCE, -SEARCH_STEP_SIZE do
                -- Get search coordinates and search for all traffic lights using trafficLightObjects array
                local searchPosition = translateVector3(playerPosition, playerHeading, searchDistance)
                for _, trafficLightObject in pairs(trafficLightObjects) do
                    -- Check if there is a traffic light in front of player
                    trafficLight = GetClosestObjectOfType(searchPosition, SEARCH_RADIUS, trafficLightObject, false, false, false)
                    if trafficLight ~= 0 then
                        -- Check traffic light heading relative to player heading (to prevent setting the wrong lights)
                        local lightHeading = GetEntityHeading(trafficLight)
                        local headingDiff = math.abs(playerHeading - lightHeading)
                        if ((headingDiff < HEADING_THRESHOLD) or (headingDiff > (360.0 - HEADING_THRESHOLD))) then
                            -- Within threshold, stop searching
                            break
                        else
                            -- Outside threshold, skip and keep searching
                            trafficLight = 0
                        end
                    end
                end

                -- If traffic light found stop searching
                if trafficLight ~= 0 then
                    break
                end
            end

            -- If traffic light found and not the same as the last one
            if (trafficLight ~= 0) and (trafficLight ~= lastTrafficLight) then
                -- Trigger server event to change light for everyone
                -- TODO: verify this works for all clients, network/entity ID same or different for players?
                TriggerServerEvent('SmartTrafficLights:setLight', GetEntityCoords(trafficLight, false))

                -- Save last light changed and delay to avoid setting other lights temporarily
                lastTrafficLight = trafficLight
                Citizen.Wait(TRAFFIC_LIGHT_DURATION_MS)
            end
        end
    end
end)

-- Translate vector3 using 2D polar notation (ignoring z-axis)
function translateVector3(pos, angle, distance)
    local angleRad = angle * 2.0 * math.pi / 360.0
    return vector3(pos.x - distance*math.sin(angleRad), pos.y + distance*math.cos(angleRad), pos.z)
end

-- Get all nearby vehicles
-- TODO, can you force nearby vehicles to stop/go at lights using this and SetDriveTaskDrivingStyle()?
function getNearbyVehicles()
    local vehicles = {}
    local findHandle, vehicle = FindFirstVehicle()
    if findHandle then
        local retval = true
        while retval and vehicle ~= 0 do
            table.insert(vehicles, vehicle)
            retval, vehicle = FindNextVehicle()
        end
        EndFindVehicle(findHandle)
    end
    return vehicles
end
