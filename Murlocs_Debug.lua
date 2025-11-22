-- Debug window for troubleshooting
local debugFrame = nil

function Murlocs:Debug_Init()
    if debugFrame then return end
    
    debugFrame = CreateFrame("Frame", "MurlocsDebugFrame", UIParent, "BasicFrameTemplateWithInset")
    debugFrame:SetSize(600, 400)
    debugFrame:SetPoint("CENTER")
    debugFrame:SetMovable(true)
    debugFrame:EnableMouse(true)
    debugFrame:RegisterForDrag("LeftButton")
    debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
    debugFrame:SetScript("OnDragStop", debugFrame.StopMovingOrSizing)
    debugFrame:Hide()
    
    debugFrame.title = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    debugFrame.title:SetPoint("TOP", 0, -5)
    debugFrame.title:SetText("Murlocs Debug Info")
    
    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, debugFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetSize(550, 1)
    
    debugFrame.text = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugFrame.text:SetPoint("TOPLEFT", 5, -5)
    debugFrame.text:SetWidth(540)
    debugFrame.text:SetJustifyH("LEFT")
    debugFrame.text:SetJustifyV("TOP")
    debugFrame.text:SetText("Run a dungeon to see debug info...")
    
    -- Copy button
    local copyBtn = CreateFrame("Button", nil, debugFrame, "GameMenuButtonTemplate")
    copyBtn:SetSize(100, 25)
    copyBtn:SetPoint("BOTTOM", 0, 10)
    copyBtn:SetText("Refresh")
    copyBtn:SetScript("OnClick", function()
        Murlocs:Debug_Update()
    end)
    
    debugFrame.scrollFrame = scrollFrame
    debugFrame.scrollChild = scrollChild
end

function Murlocs:Debug_Show()
    self:Debug_Init()
    debugFrame:Show()
    self:Debug_Update()
end

function Murlocs:Debug_Hide()
    if debugFrame then
        debugFrame:Hide()
    end
end

function Murlocs:Debug_Update()
    if not debugFrame then return end
    
    local run = self.currentRun or MurlocsDB.lastRun
    
    if not run then
        debugFrame.text:SetText("No run data available.\nComplete a dungeon run first!")
        return
    end
    
    local lines = {}
    
    table.insert(lines, "|cff00ff00=== RUN INFO ===|r")
    table.insert(lines, string.format("Dungeon: %s", run.instanceName or "Unknown"))
    table.insert(lines, string.format("Key: %s", run.dungeonKey or "Unknown"))
    table.insert(lines, string.format("Duration: %.2fs", run.duration or 0))
    table.insert(lines, string.format("Active: %s", tostring(run.active)))
    table.insert(lines, "")
    
    table.insert(lines, "|cff00ff00=== SEGMENTS ===|r")
    if run.segments and #run.segments > 0 then
        for i, seg in ipairs(run.segments) do
            table.insert(lines, string.format("|cffffff00[%d] %s|r", i, seg.label))
            table.insert(lines, string.format("  Split: %.3fs", seg.split or 0))
            table.insert(lines, string.format("  Duration: %.3fs", seg.duration or 0))
            table.insert(lines, string.format("  Creature Display ID: %s", seg.creatureDisplayId or "nil"))
            table.insert(lines, "")
        end
    else
        table.insert(lines, "No segments captured")
    end
    
    table.insert(lines, "")
    table.insert(lines, "|cff00ff00=== EXPORT JSON ===|r")
    
    -- Build export preview
    local segments = {}
    if run.segments then
        for _, seg in ipairs(run.segments) do
            local s = string.format('{"i":%d,"l":"%s","s":%.3f,"d":%.3f', 
                seg.index, seg.label, seg.split, seg.duration)
            if seg.creatureDisplayId then
                s = s .. string.format(',"cid":%d', seg.creatureDisplayId)
            end
            s = s .. "}"
            table.insert(segments, s)
        end
    end
    
    local json = string.format('{"dk":"%s","dn":"%s","seg":[%s],"v":"2.2.0"}',
        run.dungeonKey or "unknown",
        run.instanceName or "unknown",
        table.concat(segments, ","))
    
    table.insert(lines, json)
    
    local text = table.concat(lines, "\n")
    debugFrame.text:SetText(text)
    
    -- Adjust scroll child height
    local height = debugFrame.text:GetStringHeight() + 20
    debugFrame.scrollChild:SetHeight(height)
end

-- Add to slash command handler
function Murlocs:HandleDebugCommand()
    self:Debug_Show()
end
