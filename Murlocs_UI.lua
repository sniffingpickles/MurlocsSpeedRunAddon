-- Murlocs_UI.lua
-- StdUi-based user interface for Murlocs Speedrun

local addonName, Murlocs = ...

-- Initialize StdUi
local StdUi = LibStub and LibStub('StdUi', true)
if not StdUi then
    print("|cffff0000Murlocs Speedrun:|r StdUi library not found! UI will not work properly.")
    
    -- Define stub functions so addon doesn't error out
    Murlocs.frames = {}
    function Murlocs:UI_Init() end
    function Murlocs:UI_CreateMainFrame() end
    function Murlocs:UI_UpdateLiveTimer() end
    function Murlocs:UI_CreateSegmentRows() end
    function Murlocs:UI_OnRunStarted() end
    function Murlocs:UI_OnSegmentCompleted() end
    function Murlocs:UI_OnRunFinished() end
    function Murlocs:UI_ShowMain() end
    function Murlocs:UI_HideMain() end
    function Murlocs:UI_ToggleMain() end
    function Murlocs:UI_CreateExportFrame() end
    function Murlocs:UI_ShowExport() end
    function Murlocs:UI_RefreshExport() end
    function Murlocs:UI_UpdateScale() end
    function Murlocs:UI_UpdateLock() end
    function Murlocs:UI_SavePosition() end
    function Murlocs:UI_RestorePosition() end
    function Murlocs:UI_RestartRun() end
    function Murlocs:UI_RestoreLastRun() end
    function Murlocs:TruncateBossName(name) return name end
    function Murlocs:UI_CreateMinimapButton() end
    function Murlocs:UI_ShowHistory() end
    function Murlocs:UI_CreateHistoryFrame() end
    function Murlocs:UI_PopulateHistory() end
    function Murlocs:UI_CreateHistoryRunFrame() end
    function Murlocs:UI_ShowRunDetails() end
    function Murlocs:UI_GetHistoryTotalPages() return 1 end
    
    return
end

Murlocs.StdUi = StdUi
Murlocs.frames = {}

-- Initialize UI
function Murlocs:UI_Init()
    if not self.StdUi then return end
    
    self:UI_CreateMainFrame()
    self:UI_CreateMinimapButton()
    
    -- Restore last run if exists
    if MurlocsDB.lastRun and not self.currentRun then
        self.currentRun = MurlocsDB.lastRun
        self:UI_RestoreLastRun()
    end
end

-- Create main timer window
function Murlocs:UI_CreateMainFrame()
    local mainFrame = self.StdUi:Window(UIParent, 300, 400, "")
    mainFrame:SetPoint("CENTER", 0, 0)
    mainFrame:Hide()
    
    -- Make movable unless locked
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if not MurlocsDB.settings.lockFrame then
            self:StartMoving()
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Murlocs:UI_SavePosition()
    end)
    
    -- Apply scale
    mainFrame:SetScale(MurlocsDB.settings.scale or 1.0)
    
    self.frames.mainFrame = mainFrame
    
    -- Custom title in header
    local headerTitle = mainFrame:CreateFontString(nil, "OVERLAY")
    headerTitle:SetFontObject("GameFontNormalLarge")
    headerTitle:SetPoint("TOP", mainFrame, "TOP", 0, -8)
    headerTitle:SetText("|cff00ff00Murlocs|r Speedruns")
    
    -- History button (top left corner)
    local historyBtn = CreateFrame("Button", nil, mainFrame)
    historyBtn:SetSize(24, 24)
    historyBtn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 5, -5)
    historyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    historyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    historyBtn:SetScript("OnClick", function()
        Murlocs:UI_ShowHistory()
    end)
    historyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff00ff00Run History|r")
        GameTooltip:AddLine("View all your speedrun attempts", 1, 1, 1)
        GameTooltip:Show()
    end)
    historyBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.frames.historyBtn = historyBtn
    
    -- Restore saved position
    self:UI_RestorePosition()
    
    -- Instance name label
    local instanceLabel = self.StdUi:Label(mainFrame, "", 14)
    self.StdUi:GlueTop(instanceLabel, mainFrame, 0, -30, "CENTER")
    instanceLabel:SetTextColor(0.8, 0.8, 1, 1)
    self.frames.instanceLabel = instanceLabel
    
    -- Main timer text (big)
    local timerText = self.StdUi:Label(mainFrame, "00:00.000", 32)
    self.StdUi:GlueTop(timerText, instanceLabel, 0, -25, "CENTER")
    timerText:SetTextColor(1, 1, 1, 1)
    self.frames.timerText = timerText
    
    -- PB label
    local pbLabel = self.StdUi:Label(mainFrame, "PB: --:--.---", 12)
    self.StdUi:GlueTop(pbLabel, timerText, 0, -30, "CENTER")
    pbLabel:SetTextColor(0.5, 0.8, 1, 1)
    self.frames.pbLabel = pbLabel
    
    -- Delta label
    local deltaLabel = self.StdUi:Label(mainFrame, "", 14)
    self.StdUi:GlueTop(deltaLabel, pbLabel, 0, -20, "CENTER")
    self.frames.deltaLabel = deltaLabel
    
    -- Segments container with scroll
    local segmentsContainer = CreateFrame("Frame", nil, mainFrame)
    segmentsContainer:SetSize(280, 215)
    self.StdUi:GlueTop(segmentsContainer, deltaLabel, 0, -25, "CENTER")
    self.frames.segmentsContainer = segmentsContainer
    
    -- Table header (outside scroll frame)
    local headerFrame = CreateFrame("Frame", nil, segmentsContainer)
    headerFrame:SetSize(280, 18)
    headerFrame:SetPoint("TOPLEFT", 0, 0)
    
    -- Header background
    local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Header separator line
    local headerLine = headerFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("BOTTOMLEFT")
    headerLine:SetPoint("BOTTOMRIGHT")
    headerLine:SetColorTexture(0.5, 0.5, 0.5, 1)
    
    local headerName = self.StdUi:Label(headerFrame, "Boss", 10)
    headerName:SetPoint("LEFT", 8, 0)
    headerName:SetTextColor(1, 0.82, 0, 1)
    
    local headerTime = self.StdUi:Label(headerFrame, "Time", 10)
    headerTime:SetPoint("RIGHT", -8, 0)
    headerTime:SetTextColor(1, 0.82, 0, 1)
    
    -- Scroll frame for segments
    local scrollFrame = self.StdUi:ScrollFrame(segmentsContainer, 280, 195)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -1)
    
    -- Content frame for segments
    local scrollContent = CreateFrame("Frame", nil, scrollFrame.scrollChild)
    scrollContent:SetSize(260, 1)
    scrollContent:SetPoint("TOPLEFT", 0, 0)
    
    self.frames.segmentScrollFrame = scrollFrame
    self.frames.segmentScrollContent = scrollContent
    self.frames.segmentLabels = {}
    
    -- Buttons container
    local buttonY = -340
    
    -- Options button
    local optionsBtn = self.StdUi:Button(mainFrame, 90, 24, "Options")
    optionsBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 10, 10)
    optionsBtn:SetScript("OnClick", function()
        Murlocs:Config_Show()
    end)
    self.frames.optionsBtn = optionsBtn
    
    -- Restart button (only visible outside dungeons)
    local restartBtn = self.StdUi:Button(mainFrame, 90, 24, "Restart")
    restartBtn:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 10)
    restartBtn:SetScript("OnClick", function()
        Murlocs:UI_RestartRun()
    end)
    restartBtn:Hide() -- Hidden by default
    self.frames.restartBtn = restartBtn
    
    -- Export button
    local exportBtn = self.StdUi:Button(mainFrame, 90, 24, "Export")
    exportBtn:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)
    exportBtn:SetScript("OnClick", function()
        Murlocs:UI_ShowExport()
    end)
    self.frames.exportBtn = exportBtn
    
    -- OnUpdate for live timer
    mainFrame:SetScript("OnUpdate", function(self, elapsed)
        Murlocs:UI_UpdateLiveTimer()
    end)
end

-- Truncate boss name to fit in table
function Murlocs:TruncateBossName(name, maxLen)
    maxLen = maxLen or 10
    if #name <= maxLen then
        return name
    end
    
    -- Try common abbreviations first
    name = name:gsub("Commander", "Cmdr")
    name = name:gsub("General", "Gen")
    name = name:gsub("Captain", "Capt")
    name = name:gsub("Lieutenant", "Lt")
    name = name:gsub("Dark Shaman", "Dk Sham")
    name = name:gsub("Lava Guard", "Lv Guard")
    name = name:gsub("the ", "")
    name = name:gsub("  ", " ")
    
    -- If still too long, truncate with ellipsis
    if #name > maxLen then
        return name:sub(1, maxLen)
    end
    
    return name
end

-- Update live timer
function Murlocs:UI_UpdateLiveTimer()
    if not self.currentRun or not self.currentRun.active then
        return
    end
    
    -- Check for movement to start timer
    if self.currentRun.waitingForMovement then
        -- Check if player is moving using speed
        local speed = GetUnitSpeed("player")
        
        -- Start timer if player is moving (speed > 0)
        if speed and speed > 0 then
            self.currentRun.waitingForMovement = false
            self.currentRun.startTime = time()
            self.currentRun.startGameTime = GetTime()
            print("|cff00ff00Murlocs Speedrun:|r Timer started!")
        else
            -- Show "Ready..." while waiting
            if self.frames.timerText then
                self.frames.timerText:SetText("Ready...")
            end
            return
        end
    end
    
    local delta, best, elapsed = self:GetLiveDeltaForCurrentRun()
    
    -- Update timer text
    if self.frames.timerText then
        self.frames.timerText:SetText(self:FormatTime(elapsed))
    end
    
    -- Update delta
    if self.frames.deltaLabel and MurlocsDB.settings.showDelta then
        if delta then
            self.frames.deltaLabel:SetText("Δ " .. self:FormatDelta(delta, false))
            self.frames.deltaLabel:Show()
        else
            self.frames.deltaLabel:SetText("")
            self.frames.deltaLabel:Hide()
        end
    end
end

-- Create segment rows dynamically
function Murlocs:UI_CreateSegmentRows(count)
    if not self.frames.segmentScrollContent then return end
    
    -- Clear existing rows
    local children = {self.frames.segmentScrollContent:GetChildren()}
    for _, child in ipairs(children) do
        if child then
            child:Hide()
            child:SetParent(nil)
        end
    end
    
    self.frames.segmentLabels = {}
    
    local scrollContent = self.frames.segmentScrollContent
    local yOffset = 0
    
    -- Create rows
    for i = 1, count do
        local segFrame = CreateFrame("Frame", nil, scrollContent)
        segFrame:SetSize(260, 18)
        segFrame:SetPoint("TOPLEFT", 0, -yOffset)
        
        -- Alternating row background
        local rowBg = segFrame:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        if i % 2 == 0 then
            rowBg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
        else
            rowBg:SetColorTexture(0.05, 0.05, 0.05, 0.3)
        end
        
        -- Row separator line
        local rowLine = segFrame:CreateTexture(nil, "ARTWORK")
        rowLine:SetHeight(1)
        rowLine:SetPoint("BOTTOMLEFT")
        rowLine:SetPoint("BOTTOMRIGHT")
        rowLine:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        
        local segName = self.StdUi:Label(segFrame, "", 10)
        segName:SetPoint("LEFT", 8, 0)
        segName:SetWidth(90)
        segName:SetJustifyH("LEFT")
        segName:SetTextColor(0.6, 0.6, 0.6, 1)
        
        local segTime = self.StdUi:Label(segFrame, "", 9)
        segTime:SetPoint("RIGHT", -8, 0)
        segTime:SetWidth(150)
        segTime:SetJustifyH("RIGHT")
        
        self.frames.segmentLabels[i] = {
            frame = segFrame,
            name = segName,
            time = segTime,
        }
        
        yOffset = yOffset + 19
    end
    
    -- Update scroll content height
    scrollContent:SetHeight(math.max(yOffset, 1))
end

-- Run started callback
function Murlocs:UI_OnRunStarted(run, ctx)
    if not self.frames.mainFrame then return end
    
    -- Update instance label
    if self.frames.instanceLabel then
        local diffName = ctx.difficultyName or ""
        self.frames.instanceLabel:SetText(string.format("%s (%s)", ctx.instanceName, diffName))
    end
    
    -- Update PB label
    local best = self:GetPersonalBest(run.dungeonKey)
    if self.frames.pbLabel then
        if best then
            self.frames.pbLabel:SetText("PB: " .. self:FormatTime(best.duration))
        else
            self.frames.pbLabel:SetText("PB: --:--.---")
        end
    end
    
    -- Determine boss count
    local bossCount = 0
    if run.bossList then
        bossCount = #run.bossList
    elseif run.expectedBosses then
        bossCount = run.expectedBosses
    else
        bossCount = 10 -- Default fallback
    end
    
    -- Create segment rows dynamically
    self:UI_CreateSegmentRows(bossCount)
    
    -- Pre-populate boss names if available
    if run.bossList then
        for i = 1, #run.bossList do
            if self.frames.segmentLabels[i] then
                local segLabel = self.frames.segmentLabels[i]
                local truncatedName = self:TruncateBossName(run.bossList[i])
                segLabel.name:SetText(truncatedName)
                segLabel.name:SetTextColor(0.6, 0.6, 0.6, 1)
                segLabel.time:SetText("")
            end
        end
    end
    
    -- Hide restart button during active runs (prevent cheating)
    if self.frames.restartBtn then
        self.frames.restartBtn:Hide()
    end
    
    -- Show main frame
    self:UI_ShowMain()
end

-- Segment completed callback
function Murlocs:UI_OnSegmentCompleted(run, segment)
    if not self.frames.segmentLabels then return end
    
    local index = segment.index
    local segLabel = self.frames.segmentLabels[index]
    if not segLabel then return end
    
    -- If no boss list was pre-populated, set the name now
    if not run.bossList or #run.bossList == 0 then
        local truncatedName = self:TruncateBossName(segment.label)
        segLabel.name:SetText(truncatedName)
    end
    
    -- Update segment name color to green for completed
    segLabel.name:SetTextColor(0.5, 1, 0.5, 1)
    
    -- Set segment time with delta
    local timeText = self:FormatTime(segment.split, true)
    
    if MurlocsDB.settings.showSegmentPB then
        local delta = self:GetSegmentDelta(run.dungeonKey, index)
        if delta then
            timeText = timeText .. " " .. self:FormatDelta(delta, true)
        end
    end
    
    segLabel.time:SetText(timeText)
    
    -- Auto-scroll to bottom during active run
    if run.active and self.frames.segmentScrollFrame then
        C_Timer.After(0.1, function()
            if self.frames.segmentScrollFrame and self.frames.segmentScrollFrame.ScrollBar then
                self.frames.segmentScrollFrame.ScrollBar:SetValue(self.frames.segmentScrollFrame.ScrollBar:GetMaxValue())
            end
        end)
    end
end

-- Run finished callback
function Murlocs:UI_OnRunFinished(run)
    -- Timer will show final time
    -- Delta will show final delta
    -- Just update the display one more time
    if self.frames.timerText then
        self.frames.timerText:SetText(self:FormatTime(run.duration))
    end
    
    if self.frames.deltaLabel then
        local delta, best = self:GetDeltaFromBest(run)
        if delta and MurlocsDB.settings.showDelta then
            self.frames.deltaLabel:SetText("Δ " .. self:FormatDelta(delta, false))
        end
    end
    
    -- Show restart button when run is finished and outside instance
    if self.frames.restartBtn and not self.inInstance then
        self.frames.restartBtn:Show()
    end
end

-- Create history window
function Murlocs:UI_CreateHistoryFrame()
    if self.frames.historyFrame then
        return
    end
    
    local historyFrame = self.StdUi:Window(UIParent, 700, 550, "Run History")
    historyFrame:SetPoint("CENTER", 0, 0)
    historyFrame:Hide()
    
    self.frames.historyFrame = historyFrame
    self.frames.historyPage = 1
    self.frames.historyRowsPerPage = 15
    
    -- Table header
    local headerFrame = CreateFrame("Frame", nil, historyFrame)
    headerFrame:SetSize(660, 25)
    headerFrame:SetPoint("TOP", historyFrame, "TOP", 0, -35)
    
    local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    local headerLine = headerFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("BOTTOMLEFT")
    headerLine:SetPoint("BOTTOMRIGHT")
    headerLine:SetColorTexture(0.5, 0.5, 0.5, 1)
    
    -- Column headers
    local col1 = self.StdUi:Label(headerFrame, "Dungeon", 11)
    col1:SetPoint("LEFT", 10, 0)
    col1:SetTextColor(1, 0.82, 0, 1)
    
    local col2 = self.StdUi:Label(headerFrame, "Difficulty", 11)
    col2:SetPoint("LEFT", 250, 0)
    col2:SetTextColor(1, 0.82, 0, 1)
    
    local col3 = self.StdUi:Label(headerFrame, "Time", 11)
    col3:SetPoint("LEFT", 370, 0)
    col3:SetTextColor(1, 0.82, 0, 1)
    
    local col4 = self.StdUi:Label(headerFrame, "Bosses", 11)
    col4:SetPoint("LEFT", 470, 0)
    col4:SetTextColor(1, 0.82, 0, 1)
    
    local col5 = self.StdUi:Label(headerFrame, "Date", 11)
    col5:SetPoint("LEFT", 550, 0)
    col5:SetTextColor(1, 0.82, 0, 1)
    
    -- Table content container
    local content = CreateFrame("Frame", nil, historyFrame)
    content:SetSize(660, 400)
    content:SetPoint("TOP", headerFrame, "BOTTOM", 0, 0)
    
    self.frames.historyContent = content
    
    -- Pagination controls
    local pageLabel = self.StdUi:Label(historyFrame, "Page 1 of 1", 11)
    pageLabel:SetPoint("BOTTOM", historyFrame, "BOTTOM", 0, 45)
    pageLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    self.frames.historyPageLabel = pageLabel
    
    local prevBtn = self.StdUi:Button(historyFrame, 80, 24, "< Previous")
    prevBtn:SetPoint("BOTTOMLEFT", historyFrame, "BOTTOMLEFT", 10, 10)
    prevBtn:SetScript("OnClick", function()
        if self.frames.historyPage > 1 then
            self.frames.historyPage = self.frames.historyPage - 1
            self:UI_PopulateHistory()
        end
    end)
    self.frames.historyPrevBtn = prevBtn
    
    local nextBtn = self.StdUi:Button(historyFrame, 80, 24, "Next >")
    nextBtn:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -10, 10)
    nextBtn:SetScript("OnClick", function()
        local totalPages = self:UI_GetHistoryTotalPages()
        if self.frames.historyPage < totalPages then
            self.frames.historyPage = self.frames.historyPage + 1
            self:UI_PopulateHistory()
        end
    end)
    self.frames.historyNextBtn = nextBtn
    
    -- Close button
    local closeBtn = self.StdUi:Button(historyFrame, 80, 24, "Close")
    closeBtn:SetPoint("BOTTOM", historyFrame, "BOTTOM", 0, 10)
    closeBtn:SetScript("OnClick", function()
        historyFrame:Hide()
    end)
end

-- Get total pages for history
function Murlocs:UI_GetHistoryTotalPages()
    local allRuns = {}
    for dungeonKey, bucket in pairs(MurlocsDB.runs or {}) do
        if bucket.history then
            for _, run in ipairs(bucket.history) do
                table.insert(allRuns, run)
            end
        end
    end
    
    local rowsPerPage = self.frames.historyRowsPerPage or 15
    return math.max(1, math.ceil(#allRuns / rowsPerPage))
end

-- Show history window
function Murlocs:UI_ShowHistory()
    self:UI_CreateHistoryFrame()
    self:UI_PopulateHistory()
    self.frames.historyFrame:Show()
end

-- Populate history with runs
function Murlocs:UI_PopulateHistory()
    if not self.frames.historyContent then return end
    
    -- Clear existing content
    local content = self.frames.historyContent
    local children = {content:GetChildren()}
    for _, child in ipairs(children) do
        if child then
            child:Hide()
            child:SetParent(nil)
        end
    end
    
    -- Collect all runs from bucket.history
    local allRuns = {}
    for dungeonKey, bucket in pairs(MurlocsDB.runs or {}) do
        if bucket.history then
            for _, run in ipairs(bucket.history) do
                table.insert(allRuns, run)
            end
        end
    end
    
    -- Sort by date (newest first)
    table.sort(allRuns, function(a, b)
        return (a.endTime or 0) > (b.endTime or 0)
    end)
    
    -- Pagination
    local page = self.frames.historyPage or 1
    local rowsPerPage = self.frames.historyRowsPerPage or 15
    local totalPages = math.max(1, math.ceil(#allRuns / rowsPerPage))
    local startIndex = (page - 1) * rowsPerPage + 1
    local endIndex = math.min(startIndex + rowsPerPage - 1, #allRuns)
    
    -- Update page label
    if self.frames.historyPageLabel then
        self.frames.historyPageLabel:SetText(string.format("Page %d of %d", page, totalPages))
    end
    
    -- Enable/disable pagination buttons
    if self.frames.historyPrevBtn then
        if page > 1 then
            self.frames.historyPrevBtn:Enable()
        else
            self.frames.historyPrevBtn:Disable()
        end
    end
    
    if self.frames.historyNextBtn then
        if page < totalPages then
            self.frames.historyNextBtn:Enable()
        else
            self.frames.historyNextBtn:Disable()
        end
    end
    
    -- Display runs for current page
    local yOffset = 0
    for i = startIndex, endIndex do
        if allRuns[i] then
            local runFrame = self:UI_CreateHistoryRunFrame(content, allRuns[i], yOffset, i - startIndex + 1)
            yOffset = yOffset + runFrame:GetHeight()
        end
    end
end

-- Create a single run entry (table row)
function Murlocs:UI_CreateHistoryRunFrame(parent, run, yOffset, rowIndex)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(660, 25)
    frame:SetPoint("TOPLEFT", 0, -yOffset)
    
    -- Alternating row background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if rowIndex % 2 == 0 then
        bg:SetColorTexture(0.08, 0.08, 0.08, 0.5)
    else
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.5)
    end
    
    -- Row separator
    local border = frame:CreateTexture(nil, "ARTWORK")
    border:SetPoint("BOTTOMLEFT")
    border:SetPoint("BOTTOMRIGHT")
    border:SetHeight(1)
    border:SetColorTexture(0.3, 0.3, 0.3, 0.3)
    
    -- Column 1: Dungeon name (truncated)
    local dungeonName = run.instanceName or "Unknown"
    if #dungeonName > 28 then
        dungeonName = dungeonName:sub(1, 25) .. "..."
    end
    local nameLabel = self.StdUi:Label(frame, dungeonName, 10)
    nameLabel:SetPoint("LEFT", 10, 0)
    nameLabel:SetWidth(230)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetTextColor(1, 1, 1, 1)
    
    -- Column 2: Difficulty
    local diffText = run.difficultyID == 2 and "Heroic" or "Normal"
    local diffLabel = self.StdUi:Label(frame, diffText, 10)
    diffLabel:SetPoint("LEFT", 250, 0)
    diffLabel:SetWidth(110)
    diffLabel:SetJustifyH("LEFT")
    diffLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    
    -- Column 3: Time
    local timeLabel = self.StdUi:Label(frame, self:FormatTime(run.duration), 10)
    timeLabel:SetPoint("LEFT", 370, 0)
    timeLabel:SetWidth(90)
    timeLabel:SetJustifyH("LEFT")
    timeLabel:SetTextColor(0.5, 1, 0.5, 1)
    
    -- Column 4: Bosses
    local bossCount = run.segments and #run.segments or 0
    local bossLabel = self.StdUi:Label(frame, tostring(bossCount), 10)
    bossLabel:SetPoint("LEFT", 470, 0)
    bossLabel:SetWidth(70)
    bossLabel:SetJustifyH("LEFT")
    bossLabel:SetTextColor(1, 1, 1, 1)
    
    -- Column 5: Date
    local dateStr = ""
    if run.endTime then
        dateStr = date("%m/%d/%y", run.endTime)
    end
    local dateLabel = self.StdUi:Label(frame, dateStr, 10)
    dateLabel:SetPoint("LEFT", 550, 0)
    dateLabel:SetWidth(100)
    dateLabel:SetJustifyH("LEFT")
    dateLabel:SetTextColor(0.6, 0.6, 0.6, 1)
    
    -- Make clickable to show details
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if rowIndex % 2 == 0 then
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)
        else
            bg:SetColorTexture(0.12, 0.12, 0.12, 0.7)
        end
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Click to view details")
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        if rowIndex % 2 == 0 then
            bg:SetColorTexture(0.08, 0.08, 0.08, 0.5)
        else
            bg:SetColorTexture(0.05, 0.05, 0.05, 0.5)
        end
        GameTooltip:Hide()
    end)
    frame:SetScript("OnMouseUp", function(self)
        Murlocs:UI_ShowRunDetails(run)
    end)
    
    return frame
end

-- Show detailed view of a run
function Murlocs:UI_ShowRunDetails(run)
    if not run then return end
    
    -- Create or get detail frame
    if not self.frames.runDetailFrame then
        local detailFrame = self.StdUi:Window(UIParent, 500, 450, "Run Details")
        detailFrame:SetPoint("CENTER", 0, 0)
        detailFrame:Hide()
        
        local scrollFrame = self.StdUi:ScrollFrame(detailFrame, 460, 370)
        scrollFrame:SetPoint("TOP", detailFrame, "TOP", 0, -40)
        
        local content = CreateFrame("Frame", nil, scrollFrame.scrollChild)
        content:SetSize(440, 1)
        content:SetPoint("TOPLEFT", 0, 0)
        
        local closeBtn = self.StdUi:Button(detailFrame, 100, 24, "Close")
        closeBtn:SetPoint("BOTTOM", detailFrame, "BOTTOM", 0, 10)
        closeBtn:SetScript("OnClick", function()
            detailFrame:Hide()
        end)
        
        self.frames.runDetailFrame = detailFrame
        self.frames.runDetailContent = content
        self.frames.runDetailScroll = scrollFrame
    end
    
    -- Populate details
    local content = self.frames.runDetailContent
    
    -- Clear existing children properly
    local children = {content:GetChildren()}
    for _, child in ipairs(children) do
        if child then
            child:Hide()
            child:SetParent(nil)
        end
    end
    
    local yOffset = 0
    
    -- Dungeon info
    local nameLabel = self.StdUi:Label(content, run.instanceName or "Unknown", 16)
    nameLabel:SetPoint("TOPLEFT", 10, -yOffset)
    nameLabel:SetTextColor(1, 0.82, 0, 1)
    yOffset = yOffset + 25
    
    local diffText = run.difficultyID == 2 and "Heroic" or "Normal"
    local diffLabel = self.StdUi:Label(content, diffText, 12)
    diffLabel:SetPoint("TOPLEFT", 10, -yOffset)
    diffLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    yOffset = yOffset + 25
    
    -- Total time
    local timeLabel = self.StdUi:Label(content, "Total Time: " .. self:FormatTime(run.duration), 14)
    timeLabel:SetPoint("TOPLEFT", 10, -yOffset)
    timeLabel:SetTextColor(1, 1, 1, 1)
    yOffset = yOffset + 30
    
    -- Date
    if run.endTime then
        local dateStr = date("%B %d, %Y at %H:%M", run.endTime)
        local dateLabel = self.StdUi:Label(content, "Completed: " .. dateStr, 11)
        dateLabel:SetPoint("TOPLEFT", 10, -yOffset)
        dateLabel:SetTextColor(0.6, 0.6, 0.6, 1)
        yOffset = yOffset + 25
    end
    
    -- Segments header
    if run.segments and #run.segments > 0 then
        yOffset = yOffset + 10
        local segHeader = self.StdUi:Label(content, "Boss Splits:", 13)
        segHeader:SetPoint("TOPLEFT", 10, -yOffset)
        segHeader:SetTextColor(1, 0.82, 0, 1)
        yOffset = yOffset + 25
        
        -- Each segment
        for i, segment in ipairs(run.segments) do
            local segFrame = CreateFrame("Frame", nil, content)
            segFrame:SetSize(420, 20)
            segFrame:SetPoint("TOPLEFT", 10, -yOffset)
            
            local segName = self.StdUi:Label(segFrame, string.format("%d. %s", i, segment.label), 11)
            segName:SetPoint("LEFT", 0, 0)
            segName:SetTextColor(0.5, 1, 0.5, 1)
            
            local segTime = self.StdUi:Label(segFrame, self:FormatTime(segment.split, true), 11)
            segTime:SetPoint("RIGHT", 0, 0)
            segTime:SetTextColor(1, 1, 1, 1)
            
            yOffset = yOffset + 22
        end
    end
    
    content:SetHeight(math.max(yOffset + 20, 1))
    self.frames.runDetailFrame:Show()
end

-- Create minimap button
function Murlocs:UI_CreateMinimapButton()
    local button = CreateFrame("Button", "MurlocsMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Icon
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    
    -- Try custom icon, fallback to default murloc
    local iconLoaded = icon:SetTexture("Interface\\AddOns\\MurlocsSpeedrun\\icon")
    if not iconLoaded then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_02")
    end
    
    -- Border
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- Position
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -15, 0)
    
    -- Make draggable
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    local function UpdatePosition()
        local x, y = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        x = x / scale
        y = y / scale
        
        local cx, cy = Minimap:GetCenter()
        local angle = math.atan2(y - cy, x - cx)
        local cos = math.cos(angle)
        local sin = math.sin(angle)
        local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
        local round = true
        if minimapShape == "SQUARE" then
            round = false
        end
        
        local r = 80
        if round then
            button:SetPoint("CENTER", Minimap, "CENTER", r * cos, r * sin)
        else
            local diagRadius = r * 1.414
            button:SetPoint("CENTER", Minimap, "CENTER", diagRadius * cos, diagRadius * sin)
        end
    end
    
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", UpdatePosition)
    end)
    
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            Murlocs:UI_ToggleMain()
        elseif btn == "RightButton" then
            Murlocs:Config_Toggle()
        end
    end)
    
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff00ff00Murlocs Speedruns|r")
        GameTooltip:AddLine("|cffffffffLeft-click:|r Toggle timer", 1, 1, 1)
        GameTooltip:AddLine("|cffffffffRight-click:|r Open settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    self.frames.minimapButton = button
end

-- Show/hide/toggle main frame
function Murlocs:UI_ShowMain()
    if self.frames.mainFrame then
        self.frames.mainFrame:Show()
    end
end

function Murlocs:UI_HideMain()
    if self.frames.mainFrame then
        self.frames.mainFrame:Hide()
    end
end

function Murlocs:UI_ToggleMain()
    if self.frames.mainFrame then
        if self.frames.mainFrame:IsShown() then
            self:UI_HideMain()
        else
            self:UI_ShowMain()
        end
    end
end

-- Create export popup
function Murlocs:UI_CreateExportFrame()
    if self.frames.exportFrame then
        return
    end
    
    local exportFrame = self.StdUi:Window(UIParent, 500, 350, "Murlocs Speedrun Export")
    exportFrame:SetPoint("CENTER", 0, 0)
    exportFrame:Hide()
    
    self.frames.exportFrame = exportFrame
    
    -- Info label
    local infoLabel = self.StdUi:Label(exportFrame, "Copy this data to import on murlocs.com", 12)
    self.StdUi:GlueTop(infoLabel, exportFrame, 0, -30, "CENTER")
    
    -- Export text box
    local exportBox = self.StdUi:MultiLineBox(exportFrame, 480, 220, "")
    self.StdUi:GlueTop(exportBox, infoLabel, 0, -25, "CENTER")
    if exportBox.editBox then
        exportBox.editBox:SetMaxLetters(0)
    end
    self.frames.exportBox = exportBox
    
    -- Refresh button
    local refreshBtn = self.StdUi:Button(exportFrame, 100, 24, "Refresh")
    refreshBtn:SetPoint("BOTTOMLEFT", exportFrame, "BOTTOMLEFT", 10, 10)
    refreshBtn:SetScript("OnClick", function()
        Murlocs:UI_RefreshExport()
    end)
    
    -- Close button
    local closeBtn = self.StdUi:Button(exportFrame, 100, 24, "Close")
    closeBtn:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -10, 10)
    closeBtn:SetScript("OnClick", function()
        exportFrame:Hide()
    end)
end

-- Show export popup
function Murlocs:UI_ShowExport()
    self:UI_CreateExportFrame()
    
    if self.frames.exportFrame then
        self:UI_RefreshExport()
        self.frames.exportFrame:Show()
    end
end

-- Refresh export data
function Murlocs:UI_RefreshExport()
    if not self.frames.exportBox then return end
    
    local exportData = self:ExportCurrentRun()
    self.frames.exportBox:SetText(exportData)
    if self.frames.exportBox.editBox then
        self.frames.exportBox.editBox:HighlightText()
        self.frames.exportBox.editBox:SetFocus()
    end
end

-- Update main frame scale
function Murlocs:UI_UpdateScale(scale)
    if self.frames.mainFrame then
        self.frames.mainFrame:SetScale(scale)
    end
end

-- Update lock state
function Murlocs:UI_UpdateLock(locked)
    -- Lock state is checked in the OnDragStart handler
    -- No need to do anything here
end

-- Save frame position
function Murlocs:UI_SavePosition()
    if not self.frames.mainFrame then return end
    
    local point, relativeTo, relativePoint, x, y = self.frames.mainFrame:GetPoint()
    MurlocsDB.settings.framePosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

-- Restore frame position
function Murlocs:UI_RestorePosition()
    if not self.frames.mainFrame then return end
    
    local pos = MurlocsDB.settings.framePosition
    if pos and pos.point then
        self.frames.mainFrame:ClearAllPoints()
        self.frames.mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
end

-- Restore last run UI display
function Murlocs:UI_RestoreLastRun()
    if not self.currentRun then return end
    
    -- Update instance label
    if self.frames.instanceLabel then
        local difficulty = self.currentRun.difficultyID == 2 and " (Heroic)" or " (Normal)"
        self.frames.instanceLabel:SetText(self.currentRun.instanceName .. difficulty)
    end
    
    -- Update timer
    if self.frames.timerText and self.currentRun.duration then
        self.frames.timerText:SetText(self:FormatTime(self.currentRun.duration))
    end
    
    -- Update PB
    local best = self:GetPersonalBest(self.currentRun.dungeonKey)
    if self.frames.pbLabel then
        if best then
            self.frames.pbLabel:SetText("PB: " .. self:FormatTime(best.duration))
        end
    end
    
    -- Update delta
    if self.frames.deltaLabel then
        local delta, best = self:GetDeltaFromBest(self.currentRun)
        if delta and MurlocsDB.settings.showDelta then
            self.frames.deltaLabel:SetText("Δ " .. self:FormatDelta(delta, false))
        end
    end
    
    -- Restore segments
    if self.currentRun.segments and #self.currentRun.segments > 0 then
        -- Create segment rows
        self:UI_CreateSegmentRows(#self.currentRun.segments)
        
        -- Populate them
        for i, segment in ipairs(self.currentRun.segments) do
            if self.frames.segmentLabels[i] then
                local segLabel = self.frames.segmentLabels[i]
                local truncatedName = self:TruncateBossName(segment.label)
                segLabel.name:SetText(truncatedName)
                segLabel.name:SetTextColor(0.5, 1, 0.5, 1)
                
                local timeText = self:FormatTime(segment.split, true)
                if MurlocsDB.settings.showSegmentPB then
                    local delta = self:GetSegmentDelta(self.currentRun.dungeonKey, i)
                    if delta then
                        timeText = timeText .. " " .. self:FormatDelta(delta, true)
                    end
                end
                segLabel.time:SetText(timeText)
            end
        end
    end
    
    -- Show restart button if outside instance
    if self.frames.restartBtn and not self.inInstance then
        self.frames.restartBtn:Show()
    end
    
    -- Show main frame
    self:UI_ShowMain()
end

-- Restart run (clear current run)
function Murlocs:UI_RestartRun()
    -- Clear the run
    if self.currentRun then
        self.currentRun = nil
    end
    
    -- Clear saved run
    MurlocsDB.lastRun = nil
    
    -- Reset display
    if self.frames.timerText then
        self.frames.timerText:SetText("00:00.000")
    end
    if self.frames.deltaLabel then
        self.frames.deltaLabel:SetText("")
        self.frames.deltaLabel:Hide()
    end
    if self.frames.instanceLabel then
        self.frames.instanceLabel:SetText("")
    end
    
    -- Clear segments
    for i = 1, 10 do
        if self.frames.segmentLabels and self.frames.segmentLabels[i] then
            self.frames.segmentLabels[i].frame:Hide()
        end
    end
    
    -- Hide restart button
    if self.frames.restartBtn then
        self.frames.restartBtn:Hide()
    end
    
    print("|cff00ff00Murlocs Speedrun:|r Run cleared. Ready for new run.")
end
