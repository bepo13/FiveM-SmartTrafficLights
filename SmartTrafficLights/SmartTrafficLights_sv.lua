
-- Send request to change traffic light to all clients
RegisterServerEvent("SmartTrafficLights:setLight")
AddEventHandler("SmartTrafficLights:setLight", function(coords)
    TriggerClientEvent("SmartTrafficLights:setLight", -1, coords)
end)