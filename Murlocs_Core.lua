-- Murlocs_Core.lua
-- Main logic and run detection for Murlocs Speedrun

local addonName, Murlocs = ...

-- Initialize addon namespace
Murlocs.currentRun = nil
Murlocs.inInstance = false

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("BOSS_KILL")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- Event handler
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            Murlocs:OnAddonLoaded()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Murlocs:OnPlayerEnteringWorld(...)
    elseif event == "PLAYER_LEAVING_WORLD" then
        Murlocs:OnPlayerLeavingWorld()
    elseif event == "CHALLENGE_MODE_START" then
        Murlocs:OnChallengeModeStart()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        Murlocs:OnChallengeModeCompleted()
    elseif event == "ENCOUNTER_START" then
        Murlocs:OnEncounterStart(...)
    elseif event == "ENCOUNTER_END" then
        Murlocs:OnEncounterEnd(...)
    elseif event == "BOSS_KILL" then
        Murlocs:OnBossKill(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        Murlocs:OnGroupRosterUpdate()
    end
end)

-- Show debug popup (utility function for debugging)
function Murlocs:ShowDebugPopup(text)
    local frame = CreateFrame("Frame", "MurlocsDebugFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(600, 400)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
    frame.title:SetText("Murlocs Debug Info")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -24)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 4)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetSize(scrollFrame:GetWidth(), scrollFrame:GetHeight())
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetText(text)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)
    
    editBox:HighlightText()
    editBox:SetFocus()
    
    frame:Show()
end

-- Addon loaded
function Murlocs:OnAddonLoaded()
    -- Initialize database
    self:InitializeDB()
    
    -- Initialize UI
    self:UI_Init()
    
    -- Initialize config
    self:Config_Init()
    
    -- Register slash commands
    SLASH_MURLOCS1 = "/murlocs"
    SLASH_MURLOCS2 = "/mrl"
    SlashCmdList["MURLOCS"] = function(msg)
        Murlocs:HandleSlashCommand(msg)
    end
    
    print("|cff00ff00Murlocs Speedrun v2.2.0|r loaded. Type /murlocs for options.")
    
    -- Show on login if enabled
    if MurlocsDB.settings.showOnLogin then
        self:UI_ShowMain()
    end
end

-- Test populate with X bosses
function Murlocs:TestPopulate(count)
    count = count or 20
    
    -- Create test run
    local playerInfo = self:GetPlayerInfo()
    
    self.currentRun = {
        dungeonKey = "TEST:1",
        instanceName = string.format("Test Dungeon (%d bosses)", count),
        difficultyID = 1,
        characterName = playerInfo.name,
        realm = playerInfo.realm,
        classID = playerInfo.classID,
        specID = playerInfo.specID,
        startTime = time(),
        startGameTime = GetTime(),
        active = true,
        waitingForMovement = false,
        segments = {},
        expectedBosses = count,
        source = "test"
    }
    
    -- Generate test boss names
    local bossNames = {
        "Commander", "General", "Captain", "Lieutenant", "Warlord",
        "Dark Shaman", "Lava Guard", "Frost Lord", "Shadow Priest",
        "Fire Mage", "Thunder King", "Void Caller", "Blood Knight",
        "Storm Herald", "Plague Doctor", "Death Speaker", "Bone Lord",
        "Crystal Guardian", "Ancient Sentinel", "Corrupted Oracle",
        "Twisted Archon", "Fel Warlock", "Chaos Bringer", "Eternal Watcher",
        "Doom Prophet", "Nightmare King", "Infernal Duke", "Cursed Baron"
    }
    
    -- Add segments
    local currentTime = 0
    for i = 1, count do
        local bossName = bossNames[((i - 1) % #bossNames) + 1]
        currentTime = currentTime + math.random(10, 30)
        
        table.insert(self.currentRun.segments, {
            index = i,
            label = string.format("%s %d", bossName, math.ceil(i / #bossNames)),
            split = currentTime,
            timestamp = time()
        })
    end
    
    -- Update UI
    self:UI_OnRunStarted(self.currentRun, {
        instanceName = self.currentRun.instanceName,
        difficultyID = self.currentRun.difficultyID
    })
    
    -- Mark all segments as complete
    for i = 1, count do
        self:UI_OnSegmentCompleted(self.currentRun, self.currentRun.segments[i])
    end
    
    print(string.format("|cff00ff00Murlocs Speedrun:|r Test populated with %d bosses", count))
    self:UI_ShowMain()
end

-- Handle slash commands
function Murlocs:HandleSlashCommand(msg)
    msg = msg:lower():trim()
    
    if msg == "config" or msg == "options" then
        self:Config_Show()
    elseif msg == "export" then
        self:UI_ShowExport()
    elseif msg == "debug" then
        self:Debug_Show()
    elseif msg == "hide" then
        self:UI_HideMain()
    elseif msg == "show" then
        self:UI_ShowMain()
    elseif msg:match("^test%s+(%d+)$") then
        local count = tonumber(msg:match("^test%s+(%d+)$"))
        self:TestPopulate(count)
    elseif msg == "help" then
        print("|cff00ff00Murlocs Speedrun Commands:|r")
        print("  /murlocs - Toggle main window")
        print("  /murlocs config - Open settings")
        print("  /murlocs show - Show main window")
        print("  /murlocs hide - Hide main window")
        print("  /murlocs export - Export run data")
        print("  /murlocs debug - Show debug info")
        print("  /murlocs test <number> - Test UI with X bosses (e.g., /murlocs test 20)")
    else
        self:UI_ToggleMain()
    end
end

-- Player entering world
function Murlocs:OnPlayerEnteringWorld(isLogin, isReload)
    local ctx = self:GetInstanceContext()
    
    if ctx and ctx.instanceType ~= "none" then
        self.inInstance = true
        
        -- Auto-start run if entering a dungeon/raid
        if not self.currentRun or not self.currentRun.active then
            -- Small delay to ensure everything is loaded
            C_Timer.After(1, function()
                local freshCtx = self:GetInstanceContext()
                if freshCtx and not self.currentRun then
                    self:StartRun(freshCtx)
                end
            end)
        end
    else
        self.inInstance = false
        
        -- End run if leaving instance
        if self.currentRun and self.currentRun.active then
            self:EndRun(false) -- false = not successful completion
        end
        
        -- Show restart button when outside instance if there's any run data
        if self.currentRun and self.frames.restartBtn then
            self.frames.restartBtn:Show()
        end
    end
end

-- Player leaving world
function Murlocs:OnPlayerLeavingWorld()
    -- End current run if active
    if self.currentRun and self.currentRun.active then
        self:EndRun(false)
    end
end

-- Challenge mode start (M+)
function Murlocs:OnChallengeModeStart()
    local ctx = self:GetInstanceContext()
    if ctx then
        self:StartRun(ctx)
    end
end

-- Challenge mode completed (M+)
function Murlocs:OnChallengeModeCompleted()
    if self.currentRun and self.currentRun.active then
        self:EndRun(true)
    end
end

-- Encounter start
function Murlocs:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
    -- If no run is active, start one
    if not self.currentRun or not self.currentRun.active then
        local ctx = self:GetInstanceContext()
        if ctx then
            self:StartRun(ctx)
        end
    end
end

-- Encounter end
function Murlocs:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    if self.currentRun and self.currentRun.active and success == 1 then
        self:AddSegment(encounterName, encounterID)
        
        -- Check if all objectives are complete
        C_Timer.After(1, function()
            if self.currentRun and self.currentRun.active and self:AreAllObjectivesComplete() then
                self:EndRun(true)
            end
        end)
    end
end

-- Group roster update - Cancel run if someone joins
function Murlocs:OnGroupRosterUpdate()
    if self.currentRun and self.currentRun.active then
        -- Check if we're still solo
        if not self:IsSolo() then
            print("|cffff0000Murlocs Speedrun:|r Run cancelled - someone joined your party!")
            self:EndRun(false)
        end
    end
end

-- Boss kill (fallback)
function Murlocs:OnBossKill(encounterID, encounterName)
    if self.currentRun and self.currentRun.active then
        -- Check if we already have this segment
        local alreadyExists = false
        if self.currentRun.segments then
            for _, seg in ipairs(self.currentRun.segments) do
                if seg.label == encounterName then
                    alreadyExists = true
                    break
                end
            end
        end
        
        if not alreadyExists then
            self:AddSegment(encounterName, encounterID)
            
            -- Check if all objectives are complete
            C_Timer.After(1, function()
                if self.currentRun and self.currentRun.active and self:AreAllObjectivesComplete() then
                    self:EndRun(true)
                end
            end)
        end
    end
end

-- Check if all scenario objectives are complete
function Murlocs:AreAllObjectivesComplete()
    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    
    if not scenarioInfo or not scenarioInfo.name then
        return false
    end
    
    -- Check if scenario is complete
    if scenarioInfo.isComplete then
        return true
    end
    
    -- Fallback: Check all criteria
    local allComplete = true
    for i = 1, 20 do
        local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(i)
        if not criteriaInfo then
            break
        end
        
        -- If this is a boss objective and it's not completed, we're not done
        if criteriaInfo.description and 
           (string.find(criteriaInfo.description, "defeated") or string.find(criteriaInfo.description, "slain")) then
            if not criteriaInfo.completed then
                allComplete = false
                break
            end
        end
    end
    
    return allComplete
end

-- Get expected bosses for current instance
function Murlocs:GetExpectedBosses()
    local bossList = {}
    local numBosses = 0
    
    -- Try to get from scenario/dungeon objectives (works for all dungeons)
    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    
    if scenarioInfo and scenarioInfo.name then
        -- Get criteria - loop until we get nil
        for i = 1, 20 do
            local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(i)
            if not criteriaInfo then
                break
            end
            
            if criteriaInfo.description then
                -- Boss objectives usually contain "defeated" or "slain"
                if string.find(criteriaInfo.description, "defeated") or string.find(criteriaInfo.description, "slain") then
                    -- Extract boss name (remove "defeated" or "slain" suffix)
                    local bossName = criteriaInfo.description:gsub(" defeated$", ""):gsub(" slain$", "")
                    table.insert(bossList, bossName)
                    numBosses = numBosses + 1
                end
            end
        end
    end
    
    -- If scenario didn't work, try Encounter Journal
    if numBosses == 0 then
        local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
        
        if instanceID then
            local success = pcall(function()
                EJ_SelectInstance(instanceID)
                local index = 1
                while true do
                    local bossName, description, encounterID, rootSectionID, link = EJ_GetEncounterInfoByIndex(index, instanceID)
                    if not bossName then break end
                    table.insert(bossList, bossName)
                    numBosses = numBosses + 1
                    index = index + 1
                end
            end)
        end
    end
    
    return numBosses, bossList
end

-- Start a new run
function Murlocs:StartRun(ctx)
    if not ctx then return end
    
    -- Only allow dungeon runs (not raids)
    if ctx.instanceType ~= "party" then
        print("|cffff0000Murlocs Speedrun:|r Only dungeon runs are supported (raids coming soon!)")
        return
    end
    
    -- Only allow solo runs
    if not self:IsSolo() then
        print("|cffff0000Murlocs Speedrun:|r Only solo runs are supported!")
        return
    end
    
    local dungeonKey = self:MakeDungeonKey(ctx)
    if not dungeonKey then return end
    
    local playerInfo = self:GetPlayerInfo()
    local expectedBosses, bossList = self:GetExpectedBosses()
    
    self.currentRun = {
        active = true,
        waitingForMovement = true,
        startTime = nil, -- Will be set when player moves
        startGameTime = nil, -- Will be set when player moves
        endTime = nil,
        duration = nil,
        dungeonKey = dungeonKey,
        instanceName = ctx.instanceName,
        difficultyID = ctx.difficultyID,
        characterName = playerInfo.name,
        realm = playerInfo.realm,
        classID = playerInfo.classID,
        specID = playerInfo.specID,
        segments = {},
        expectedBosses = expectedBosses,
        bossList = bossList,
        source = "addon_live",
        gameBuild = select(4, GetBuildInfo()),
    }
    
    -- Notify UI
    self:UI_OnRunStarted(self.currentRun, ctx)
    
    if expectedBosses > 0 then
        print(string.format("|cff00ff00Murlocs Speedrun:|r Timer ready for %s (%d bosses). Move to start!", ctx.instanceName, expectedBosses))
    else
        print(string.format("|cff00ff00Murlocs Speedrun:|r Timer ready for %s. Move to start!", ctx.instanceName))
    end
end

-- Add a segment (boss kill, etc.)
function Murlocs:AddSegment(label, encounterID)
    if not self.currentRun or not self.currentRun.active then
        return
    end
    
    local elapsed = GetTime() - self.currentRun.startGameTime
    local previousSplit = 0
    
    if #self.currentRun.segments > 0 then
        previousSplit = self.currentRun.segments[#self.currentRun.segments].split
    end
    
    -- Try to get creature display ID for boss portrait
    local creatureDisplayId = nil
    if encounterID then
        -- Select the encounter first to load its data
        EJ_SelectEncounter(encounterID)
        local id, name, description, displayInfo = EJ_GetCreatureInfo(1, encounterID)
        if displayInfo then
            creatureDisplayId = displayInfo
            print(string.format("DEBUG: Boss %s has display ID: %d", label, displayInfo))
        else
            print(string.format("DEBUG: No display info for encounter %d (%s)", encounterID, label))
        end
    else
        print(string.format("DEBUG: No encounterID for %s", label))
    end
    
    local segment = {
        index = #self.currentRun.segments + 1,
        label = label,
        split = elapsed,
        duration = elapsed - previousSplit,
        creatureDisplayId = creatureDisplayId,
    }
    
    table.insert(self.currentRun.segments, segment)
    
    -- Notify UI
    self:UI_OnSegmentCompleted(self.currentRun, segment)
    
    -- Get segment delta if we have a PB
    local delta = self:GetSegmentDelta(self.currentRun.dungeonKey, segment.index)
    if delta then
        print(string.format("|cff00ff00Murlocs Speedrun:|r %s - %s %s", 
            label, 
            self:FormatTime(segment.split, true),
            self:FormatDelta(delta, true)))
    else
        print(string.format("|cff00ff00Murlocs Speedrun:|r %s - %s", 
            label, 
            self:FormatTime(segment.split, true)))
    end
end

-- End the current run
function Murlocs:EndRun(successful)
    if not self.currentRun or not self.currentRun.active then
        return
    end
    
    self.currentRun.active = false
    self.currentRun.endTime = time()
    self.currentRun.duration = GetTime() - self.currentRun.startGameTime
    
    -- Only store if successful or has segments
    if successful or #self.currentRun.segments > 0 then
        self:StoreRun(self.currentRun)
        
        -- Save to lastRun for persistence across reloads
        MurlocsDB.lastRun = CopyTable(self.currentRun)
        
        -- Get delta from best
        local delta, best = self:GetDeltaFromBest(self.currentRun)
        
        -- Notify UI
        self:UI_OnRunFinished(self.currentRun)
        
        if delta then
            print(string.format("|cff00ff00Murlocs Speedrun:|r Run completed: %s %s", 
                self:FormatTime(self.currentRun.duration),
                self:FormatDelta(delta, false)))
        else
            print(string.format("|cff00ff00Murlocs Speedrun:|r Run completed: %s (First run!)", 
                self:FormatTime(self.currentRun.duration)))
        end
    else
        print("|cff00ff00Murlocs Speedrun:|r Run ended (not saved).")
    end
    
    -- Keep the run for display but mark as inactive
    -- Don't nil it out so UI can still show the final time
end

-- Manual run control (for testing or manual use)
function Murlocs:ManualStartRun()
    local ctx = self:GetInstanceContext()
    if ctx then
        self:StartRun(ctx)
    else
        print("|cffff0000Murlocs Speedrun:|r Not in an instance!")
    end
end

function Murlocs:ManualEndRun()
    if self.currentRun and self.currentRun.active then
        self:EndRun(true)
    else
        print("|cffff0000Murlocs Speedrun:|r No active run!")
    end
end

function Murlocs:ManualAddSegment(label)
    if self.currentRun and self.currentRun.active then
        self:AddSegment(label or "Manual Segment")
    else
        print("|cffff0000Murlocs Speedrun:|r No active run!")
    end
end

-- Debug: Print current run info
function Murlocs:DebugPrintRun()
    if not self.currentRun then
        print("No current run")
        return
    end
    
    print("Current Run:")
    print("  Active:", self.currentRun.active)
    print("  Instance:", self.currentRun.instanceName)
    print("  Dungeon Key:", self.currentRun.dungeonKey)
    print("  Segments:", #self.currentRun.segments)
    
    if self.currentRun.active then
        local elapsed = GetTime() - self.currentRun.startGameTime
        print("  Elapsed:", self:FormatTime(elapsed))
    else
        print("  Duration:", self:FormatTime(self.currentRun.duration))
    end
end
