--[[
    SECURITY TEST SUITE FOR DUELS SYSTEM
    =====================================
    PURPOSE: Test for vulnerabilities in the duels system
    USAGE: Run in Studio with a test account or in a private server
    
    WARNING: This is for TESTING YOUR OWN GAME ONLY.
    Do not use on games you do not own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Configuration
local CONFIG = {
    -- Enable/disable specific tests
    TESTS = {
        REMOTE_FLOOD = true,
        LARGE_PAYLOAD = true,
        RAPID_STATE_CHANGE = true,
        ACCEPT_SPAM = true,
        DESYNC_ABUSE = true,
        SYNCHRONIZER_FLOOD = true,
    },
    
    -- Test parameters
    FLOOD_RATE = 100,           -- Requests per second
    FLOOD_DURATION = 5,         -- Seconds
    PAYLOAD_SIZE = 10000,       -- Table entries for large payload test
    STATE_CHANGE_RATE = 50,     -- State changes per second
}

-- Results tracking
local TestResults = {
    passed = {},
    failed = {},
    errors = {},
}

-- Utility functions
local function log(category, message)
    print(string.format("[SecurityTest/%s] %s", category, message))
end

local function logError(category, message)
    warn(string.format("[SecurityTest/%s] ERROR: %s", category, message))
    table.insert(TestResults.errors, {category = category, message = message})
end

local function waitForRemote(name, timeout)
    timeout = timeout or 5
    local Net = require(ReplicatedStorage.Packages.Net)
    local success, remote = pcall(function()
        return Net:RemoteEvent(name)
    end)
    if success then
        return remote
    end
    return nil
end

local function generateLargeTable(size)
    local t = {}
    for i = 1, size do
        t["key_" .. i] = {
            value = string.rep("x", 100),
            nested = {
                a = i,
                b = tostring(i),
                c = {d = {e = {f = i}}}
            }
        }
    end
    return t
end

local function generateMalformedBrainrot()
    return {
        Index = string.rep("A", 10000),  -- Extremely long index
        UUID = HttpService:GenerateGUID(false),
        Mutation = nil,
        Traits = generateLargeTable(100),
    }
end

--[[
    TEST 1: RemoteEvent Flooding
    Tests if the server can handle rapid RemoteEvent calls
]]
local function testRemoteFlood()
    if not CONFIG.TESTS.REMOTE_FLOOD then return end
    log("RemoteFlood", "Starting RemoteEvent flood test...")
    
    local remotes = {
        "DuelsMachineMatchService/SelectBrainrot/Ready",
        "DuelsMachineMatchService/SelectBrainrot/Cancel",
        "DuelsMachineMatchService/SelectBrainrot/Vote",
    }
    
    local callCount = 0
    local startTime = os.clock()
    
    for _, remoteName in ipairs(remotes) do
        local remote = waitForRemote(remoteName)
        if remote then
            log("RemoteFlood", "Testing: " .. remoteName)
            
            local floodStart = os.clock()
            while os.clock() - floodStart < CONFIG.FLOOD_DURATION do
                for _ = 1, CONFIG.FLOOD_RATE do
                    pcall(function()
                        remote:FireServer()
                    end)
                    callCount = callCount + 1
                end
                RunService.Heartbeat:Wait()
            end
        else
            logError("RemoteFlood", "Could not find remote: " .. remoteName)
        end
    end
    
    local elapsed = os.clock() - startTime
    log("RemoteFlood", string.format("Completed: %d calls in %.2f seconds (%.0f calls/sec)", 
        callCount, elapsed, callCount / elapsed))
    
    table.insert(TestResults.passed, {
        test = "RemoteFlood",
        calls = callCount,
        duration = elapsed
    })
end

--[[
    TEST 2: Large Payload Attack
    Tests if the server validates incoming data size
]]
local function testLargePayload()
    if not CONFIG.TESTS.LARGE_PAYLOAD then return end
    log("LargePayload", "Starting large payload test...")
    
    local selectRemote = waitForRemote("DuelsMachineMatchService/SelectBrainrot/Select")
    if not selectRemote then
        logError("LargePayload", "Could not find Select remote")
        return
    end
    
    -- Test with increasingly large payloads
    local sizes = {100, 1000, 5000, 10000, 50000}
    
    for _, size in ipairs(sizes) do
        log("LargePayload", "Testing payload size: " .. size)
        
        local largePayload = generateLargeTable(size)
        local malformedBrainrot = {
            Index = "TestBrainrot",
            UUID = HttpService:GenerateGUID(false),
            Mutation = nil,
            Traits = largePayload,
        }
        
        local success, err = pcall(function()
            selectRemote:FireServer(1, malformedBrainrot)
        end)
        
        if not success then
            log("LargePayload", "Server rejected payload of size " .. size .. ": " .. tostring(err))
        else
            log("LargePayload", "Server accepted payload of size " .. size)
        end
        
        task.wait(0.5)
    end
    
    table.insert(TestResults.passed, {test = "LargePayload"})
end

--[[
    TEST 3: Rapid State Change
    Tests if rapid selection changes can overwhelm the Synchronizer
]]
local function testRapidStateChange()
    if not CONFIG.TESTS.RAPID_STATE_CHANGE then return end
    log("RapidStateChange", "Starting rapid state change test...")
    
    local selectRemote = waitForRemote("DuelsMachineMatchService/SelectBrainrot/Select")
    local cancelRemote = waitForRemote("DuelsMachineMatchService/SelectBrainrot/Cancel")
    
    if not selectRemote or not cancelRemote then
        logError("RapidStateChange", "Could not find required remotes")
        return
    end
    
    local changeCount = 0
    local startTime = os.clock()
    local testDuration = 5 -- seconds
    
    local fakeBrainrot = {
        Index = "Tralalero",
        UUID = HttpService:GenerateGUID(false),
        Mutation = nil,
        Traits = {},
    }
    
    while os.clock() - startTime < testDuration do
        for _ = 1, CONFIG.STATE_CHANGE_RATE do
            pcall(function()
                selectRemote:FireServer(1, fakeBrainrot)
            end)
            changeCount = changeCount + 1
            
            pcall(function()
                cancelRemote:FireServer()
            end)
            changeCount = changeCount + 1
        end
        RunService.Heartbeat:Wait()
    end
    
    local elapsed = os.clock() - startTime
    log("RapidStateChange", string.format("Completed: %d changes in %.2f seconds (%.0f changes/sec)", 
        changeCount, elapsed, changeCount / elapsed))
    
    table.insert(TestResults.passed, {
        test = "RapidStateChange",
        changes = changeCount,
        duration = elapsed
    })
end

--[[
    TEST 4: Accept Spam
    Tests the dupe scenario where accept is spammed during server lag
]]
local function testAcceptSpam()
    if not CONFIG.TESTS.ACCEPT_SPAM then return end
    log("AcceptSpam", "Starting accept spam test...")
    
    local acceptRemote = waitForRemote("DuelsMachineMatchService/SelectBrainrot/Accept")
    local readyRemote = waitForRemote("DuelsMachineMatchService/SelectBrainrot/Ready")
    
    if not acceptRemote then
        logError("AcceptSpam", "Could not find Accept remote")
        return
    end
    
    local callCount = 0
    local startTime = os.clock()
    local testDuration = 3 -- seconds
    
    -- First mark as ready
    if readyRemote then
        pcall(function()
            readyRemote:FireServer()
        end)
    end
    
    -- Now spam accept
    while os.clock() - startTime < testDuration do
        for _ = 1, 200 do  -- Very high rate
            pcall(function()
                acceptRemote:FireServer()
            end)
            callCount = callCount + 1
        end
        -- No wait - maximum speed
    end
    
    local elapsed = os.clock() - startTime
    log("AcceptSpam", string.format("Completed: %d accept calls in %.2f seconds (%.0f calls/sec)", 
        callCount, elapsed, callCount / elapsed))
    
    table.insert(TestResults.passed, {
        test = "AcceptSpam",
        calls = callCount,
        duration = elapsed
    })
end

--[[
    TEST 5: Desync/Position Abuse
    Tests the UnreliableRemoteEvent position sync (duels-specific)
]]
local function testDesyncAbuse()
    if not CONFIG.TESTS.DESYNC_ABUSE then return end
    log("DesyncAbuse", "Starting desync abuse test...")
    
    local Desync = ReplicatedStorage:FindFirstChild("Desync")
    if not Desync then
        log("DesyncAbuse", "Desync folder not found - not on duels server")
        return
    end
    
    local unreliableRemote = Desync:FindFirstChild("UnreliableRemoteEvent")
    if not unreliableRemote then
        logError("DesyncAbuse", "UnreliableRemoteEvent not found")
        return
    end
    
    log("DesyncAbuse", "Found desync remote, testing malformed CFrames...")
    
    -- Test various malformed CFrame data
    local malformedData = {
        CFrame.new(math.huge, math.huge, math.huge),  -- Infinity
        CFrame.new(0/0, 0/0, 0/0),  -- NaN
        CFrame.new(1e308, 1e308, 1e308),  -- Very large
        CFrame.new(-1e308, -1e308, -1e308),  -- Very negative
    }
    
    for i, cf in ipairs(malformedData) do
        log("DesyncAbuse", "Testing malformed CFrame #" .. i)
        pcall(function()
            -- Note: This is client->server, so we're testing if we can send bad data
            unreliableRemote:FireServer(LocalPlayer, cf)
        end)
        task.wait(0.1)
    end
    
    table.insert(TestResults.passed, {test = "DesyncAbuse"})
end

--[[
    TEST 6: Synchronizer Queue Flood
    Attempts to overflow the Synchronizer's internal queue
]]
local function testSynchronizerFlood()
    if not CONFIG.TESTS.SYNCHRONIZER_FLOOD then return end
    log("SynchronizerFlood", "Starting Synchronizer flood test...")
    
    -- Try to access Synchronizer
    local success, Synchronizer = pcall(function()
        return require(ReplicatedStorage.Packages.Synchronizer)
    end)
    
    if not success then
        logError("SynchronizerFlood", "Could not load Synchronizer")
        return
    end
    
    -- Get player channel
    local channel = Synchronizer:Get(LocalPlayer)
    if not channel then
        log("SynchronizerFlood", "Waiting for player channel...")
        channel = Synchronizer:Wait(LocalPlayer)
    end
    
    if channel then
        log("SynchronizerFlood", "Got player channel, monitoring for changes...")
        
        -- We can't directly flood from client, but we can trigger rapid changes
        -- via RemoteEvents that cause server to update the channel
        
        local voteRemote = waitForRemote("DuelsMachineMatchService/SelectBrainrot/Vote")
        if voteRemote then
            local modes = {"Bat Only", "Bat + Medusa", "All Gears"}
            local voteCount = 0
            local startTime = os.clock()
            
            while os.clock() - startTime < 3 do
                for _, mode in ipairs(modes) do
                    pcall(function()
                        voteRemote:FireServer(mode)
                    end)
                    voteCount = voteCount + 1
                end
            end
            
            log("SynchronizerFlood", "Sent " .. voteCount .. " vote changes")
        end
    else
        logError("SynchronizerFlood", "Could not get player channel")
    end
    
    table.insert(TestResults.passed, {test = "SynchronizerFlood"})
end

--[[
    TEST 7: Cross-Server Race Condition Simulation
    Simulates the dupe scenario by checking state consistency
]]
local function testCrossServerRace()
    log("CrossServerRace", "Starting cross-server race condition test...")
    
    -- Check if we're on a duels server
    local ServerData = require(ReplicatedStorage.Datas.ServerData)
    local isDuels = ServerData.IsDuelsServer()
    
    log("CrossServerRace", "Is Duels Server: " .. tostring(isDuels))
    
    if isDuels then
        -- On duels server, check brainrot lock state
        local success, Synchronizer = pcall(function()
            return require(ReplicatedStorage.Packages.Synchronizer)
        end)
        
        if success then
            local channel = Synchronizer:Wait(LocalPlayer)
            if channel then
                local animalPodiums = channel:Get("AnimalPodiums")
                if animalPodiums then
                    log("CrossServerRace", "AnimalPodiums data:")
                    for slot, data in pairs(animalPodiums) do
                        if type(data) == "table" then
                            local machineType = data.Machine and data.Machine.Type or "NONE"
                            log("CrossServerRace", string.format(
                                "  Slot %s: %s (Machine: %s)", 
                                tostring(slot), 
                                data.Index or "Empty",
                                machineType
                            ))
                        end
                    end
                end
            end
        end
    else
        log("CrossServerRace", "Not on duels server - checking for reconnect state")
        
        -- Check if player has active duel flag
        local hasDuelFlag = LocalPlayer:GetAttribute("__duels_tp_back")
        log("CrossServerRace", "Has __duels_tp_back: " .. tostring(hasDuelFlag))
    end
    
    table.insert(TestResults.passed, {test = "CrossServerRace"})
end

--[[
    MAIN TEST RUNNER
]]
local function runAllTests()
    log("Main", "=" .. string.rep("=", 50))
    log("Main", "SECURITY TEST SUITE - STARTING")
    log("Main", "=" .. string.rep("=", 50))
    log("Main", "Player: " .. LocalPlayer.Name)
    log("Main", "PlaceId: " .. game.PlaceId)
    log("Main", "")
    
    -- Check if on duels server
    local success, ServerData = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("ServerData"))
    end)
    
    if success then
        log("Main", "IsDuelsServer: " .. tostring(ServerData.IsDuelsServer()))
    end
    log("Main", "")
    
    -- Run tests
    local tests = {
        {name = "Remote Flood", func = testRemoteFlood},
        {name = "Large Payload", func = testLargePayload},
        {name = "Rapid State Change", func = testRapidStateChange},
        {name = "Accept Spam", func = testAcceptSpam},
        {name = "Desync Abuse", func = testDesyncAbuse},
        {name = "Synchronizer Flood", func = testSynchronizerFlood},
        {name = "Cross-Server Race", func = testCrossServerRace},
    }
    
    for i, test in ipairs(tests) do
        log("Main", string.format("[%d/%d] Running: %s", i, #tests, test.name))
        
        local testSuccess, testError = pcall(test.func)
        
        if not testSuccess then
            logError("Main", "Test crashed: " .. test.name .. " - " .. tostring(testError))
            table.insert(TestResults.failed, {test = test.name, error = testError})
        end
        
        task.wait(1)  -- Brief pause between tests
    end
    
    -- Print summary
    log("Main", "")
    log("Main", "=" .. string.rep("=", 50))
    log("Main", "TEST SUMMARY")
    log("Main", "=" .. string.rep("=", 50))
    log("Main", "Passed: " .. #TestResults.passed)
    log("Main", "Failed: " .. #TestResults.failed)
    log("Main", "Errors: " .. #TestResults.errors)
    
    if #TestResults.errors > 0 then
        log("Main", "")
        log("Main", "ERRORS:")
        for _, err in ipairs(TestResults.errors) do
            log("Main", "  - " .. err.category .. ": " .. err.message)
        end
    end
    
    log("Main", "=" .. string.rep("=", 50))
    log("Main", "SECURITY TEST SUITE - COMPLETE")
    log("Main", "=" .. string.rep("=", 50))
    
    return TestResults
end

-- Export for module usage
return {
    run = runAllTests,
    runTest = function(testName)
        local tests = {
            RemoteFlood = testRemoteFlood,
            LargePayload = testLargePayload,
            RapidStateChange = testRapidStateChange,
            AcceptSpam = testAcceptSpam,
            DesyncAbuse = testDesyncAbuse,
            SynchronizerFlood = testSynchronizerFlood,
            CrossServerRace = testCrossServerRace,
        }
        
        if tests[testName] then
            return tests[testName]()
        else
            error("Unknown test: " .. testName)
        end
    end,
    CONFIG = CONFIG,
    Results = TestResults,
}
