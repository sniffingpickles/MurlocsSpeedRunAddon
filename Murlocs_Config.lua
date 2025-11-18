-- Murlocs_Config.lua
-- Options window for Murlocs Speedrun

local addonName, Murlocs = ...

-- Initialize config
function Murlocs:Config_Init()
    if not self.StdUi then return end
    
    -- Config will be created on first show
end

-- Create config window
function Murlocs:Config_CreateWindow()
    if self.frames.configFrame then
        return
    end
    
    local configFrame = self.StdUi:Window(UIParent, 400, 460, "Murlocs Speedrun - Options")
    configFrame:SetPoint("CENTER", 0, 0)
    configFrame:Hide()
    
    self.frames.configFrame = configFrame
    
    local yOffset = 60
    
    -- Title
    local title = self.StdUi:Label(configFrame, "Settings", 16)
    self.StdUi:GlueTop(title, configFrame, 0, -30, "CENTER")
    title:SetTextColor(1, 1, 1, 1)
    
    yOffset = yOffset + 20
    
    -- Show on login checkbox
    local showOnLoginCB = self.StdUi:Checkbox(configFrame, "Show window on login")
    showOnLoginCB:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -yOffset)
    showOnLoginCB:SetChecked(MurlocsDB.settings.showOnLogin)
    showOnLoginCB:HookScript("OnClick", function(checkbox)
        MurlocsDB.settings.showOnLogin = checkbox:GetChecked()
    end)
    self.frames.showOnLoginCB = showOnLoginCB
    
    yOffset = yOffset + 30
    
    -- Lock frame checkbox
    local lockFrameCB = self.StdUi:Checkbox(configFrame, "Lock main window")
    lockFrameCB:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -yOffset)
    lockFrameCB:SetChecked(MurlocsDB.settings.lockFrame)
    lockFrameCB:HookScript("OnClick", function(checkbox)
        MurlocsDB.settings.lockFrame = checkbox:GetChecked()
        Murlocs:UI_UpdateLock(checkbox:GetChecked())
    end)
    self.frames.lockFrameCB = lockFrameCB
    
    yOffset = yOffset + 30
    
    -- Show delta checkbox
    local showDeltaCB = self.StdUi:Checkbox(configFrame, "Show live Δ vs PB")
    showDeltaCB:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -yOffset)
    showDeltaCB:SetChecked(MurlocsDB.settings.showDelta)
    showDeltaCB:HookScript("OnClick", function(checkbox)
        MurlocsDB.settings.showDelta = checkbox:GetChecked()
    end)
    self.frames.showDeltaCB = showDeltaCB
    
    yOffset = yOffset + 30
    
    -- Show segment delta checkbox
    local showSegmentPBCB = self.StdUi:Checkbox(configFrame, "Show per-segment Δ vs PB")
    showSegmentPBCB:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -yOffset)
    showSegmentPBCB:SetChecked(MurlocsDB.settings.showSegmentPB)
    showSegmentPBCB:HookScript("OnClick", function(checkbox)
        MurlocsDB.settings.showSegmentPB = checkbox:GetChecked()
    end)
    self.frames.showSegmentPBCB = showSegmentPBCB
    
    yOffset = yOffset + 50
    
    -- Scale slider
    local scaleLabel = self.StdUi:Label(configFrame, "Main window scale", 12)
    scaleLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -yOffset)
    
    yOffset = yOffset + 25
    
    local scaleSlider = self.StdUi:Slider(configFrame, 340, 20, 1.0, false)
    scaleSlider:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -yOffset)
    scaleSlider:SetMinMaxValues(0.5, 1.5)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetValue(MurlocsDB.settings.scale or 1.0)
    
    -- Make thumb more visible
    if scaleSlider.thumb then
        scaleSlider.thumb:SetBackdropColor(0.4, 0.4, 0.4, 1)
        scaleSlider.thumb:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    end
    
    -- Value label
    local scaleValue = self.StdUi:Label(configFrame, string.format("%.2f", MurlocsDB.settings.scale or 1.0), 12)
    scaleValue:SetPoint("TOP", scaleSlider, "BOTTOM", 0, -5)
    
    scaleSlider:SetScript("OnValueChanged", function(slider, value)
        value = math.floor(value * 20 + 0.5) / 20 -- Round to 0.05
        MurlocsDB.settings.scale = value
        scaleValue:SetText(string.format("%.2f", value))
        Murlocs:UI_UpdateScale(value)
    end)
    
    self.frames.scaleSlider = scaleSlider
    self.frames.scaleValue = scaleValue
    
    yOffset = yOffset + 60
    
    -- Info section
    local infoLabel = self.StdUi:Label(configFrame, "Murlocs Speedrun v2.0.0", 11)
    infoLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -yOffset)
    infoLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    
    yOffset = yOffset + 20
    
    local websiteLabel = self.StdUi:Label(configFrame, "Visit murlocs.com to upload your runs", 10)
    websiteLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -yOffset)
    websiteLabel:SetTextColor(0.5, 0.8, 1, 1)
    
    -- Reset button
    local resetBtn = self.StdUi:Button(configFrame, 120, 24, "Reset All Data")
    resetBtn:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", 10, 10)
    resetBtn:SetScript("OnClick", function()
        Murlocs:Config_ConfirmReset()
    end)
    
    -- Close button
    local closeBtn = self.StdUi:Button(configFrame, 100, 24, "Close")
    closeBtn:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -10, 10)
    closeBtn:SetScript("OnClick", function()
        configFrame:Hide()
    end)
end

-- Show config window
function Murlocs:Config_Show()
    self:Config_CreateWindow()
    
    if self.frames.configFrame then
        -- Update checkbox states
        if self.frames.showOnLoginCB then
            self.frames.showOnLoginCB:SetChecked(MurlocsDB.settings.showOnLogin)
        end
        if self.frames.lockFrameCB then
            self.frames.lockFrameCB:SetChecked(MurlocsDB.settings.lockFrame)
        end
        if self.frames.showDeltaCB then
            self.frames.showDeltaCB:SetChecked(MurlocsDB.settings.showDelta)
        end
        if self.frames.showSegmentPBCB then
            self.frames.showSegmentPBCB:SetChecked(MurlocsDB.settings.showSegmentPB)
        end
        if self.frames.scaleSlider then
            self.frames.scaleSlider:SetValue(MurlocsDB.settings.scale or 1.0)
        end
        
        self.frames.configFrame:Show()
    end
end

-- Hide config window
function Murlocs:Config_Hide()
    if self.frames.configFrame then
        self.frames.configFrame:Hide()
    end
end

-- Toggle config window
function Murlocs:Config_Toggle()
    self:Config_CreateWindow()
    
    if self.frames.configFrame then
        if self.frames.configFrame:IsShown() then
            self.frames.configFrame:Hide()
        else
            self.frames.configFrame:Show()
        end
    end
end

-- Confirm reset dialog
function Murlocs:Config_ConfirmReset()
    if not self.StdUi then return end
    
    StaticPopupDialogs["MURLOCS_CONFIRM_RESET"] = {
        text = "Are you sure you want to reset ALL run data?\n\nThis will delete all your run history and personal bests.\n\n|cffff0000This cannot be undone!|r",
        button1 = "Reset",
        button2 = "Cancel",
        OnAccept = function()
            Murlocs:ResetAllData()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("MURLOCS_CONFIRM_RESET")
end

-- Reset all data
function Murlocs:ResetAllData()
    -- Clear all runs
    MurlocsDB.runs = {}
    
    -- Clear last run
    MurlocsDB.lastRun = nil
    
    -- Clear current run and UI
    self:UI_RestartRun()
    
    -- Reset settings to defaults
    MurlocsDB.settings = {
        showOnLogin = true,
        lockFrame = false,
        scale = 1.0,
        showDelta = true,
        showSegmentPB = true,
        userToken = nil,
        framePosition = nil,
    }
    
    -- Update UI to reflect new settings
    if self.frames.showOnLoginCB then
        self.frames.showOnLoginCB:SetChecked(MurlocsDB.settings.showOnLogin)
    end
    if self.frames.lockFrameCB then
        self.frames.lockFrameCB:SetChecked(MurlocsDB.settings.lockFrame)
    end
    if self.frames.showDeltaCB then
        self.frames.showDeltaCB:SetChecked(MurlocsDB.settings.showDelta)
    end
    if self.frames.showSegmentPBCB then
        self.frames.showSegmentPBCB:SetChecked(MurlocsDB.settings.showSegmentPB)
    end
    if self.frames.scaleSlider then
        self.frames.scaleSlider:SetValue(MurlocsDB.settings.scale)
    end
    if self.frames.mainFrame then
        self.frames.mainFrame:SetScale(MurlocsDB.settings.scale)
    end
    
    print("|cff00ff00Murlocs Speedrun:|r All data has been reset.")
end
