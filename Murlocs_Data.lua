-- Murlocs_Data.lua
-- Data model and storage layer for Murlocs Speedrun

local addonName, Murlocs = ...

-- Initialize the addon namespace if not already done
if not Murlocs then
    Murlocs = {}
end

-- Default database structure
local defaultDB = {
    settings = {
        showOnLogin = true,
        lockFrame = false,
        scale = 1.0,
        showDelta = true,
        showSegmentPB = true,
        userToken = nil,
        framePosition = nil, -- {point, relativeTo, relativePoint, x, y}
    },
    runs = {},
    lastRun = nil, -- Persist last run for display across reloads
    migratedFromSpeedy = false,
}

-- Initialize the database
function Murlocs:InitializeDB()
    if not MurlocsDB then
        MurlocsDB = {}
    end
    
    -- Merge with defaults
    if not MurlocsDB.settings then
        MurlocsDB.settings = CopyTable(defaultDB.settings)
    else
        -- Fill in any missing settings
        for k, v in pairs(defaultDB.settings) do
            if MurlocsDB.settings[k] == nil then
                MurlocsDB.settings[k] = v
            end
        end
    end
    
    if not MurlocsDB.runs then
        MurlocsDB.runs = {}
    end
    
    -- Migrate from old Speedy.gg addon if present
    if not MurlocsDB.migratedFromSpeedy and speedyggDB then
        self:MigrateFromSpeedy()
        MurlocsDB.migratedFromSpeedy = true
    end
end

-- Migrate data from Speedy.gg addon
function Murlocs:MigrateFromSpeedy()
    -- Simple migration: just mark as migrated
    -- The old structure is too different to easily migrate
    print("|cff00ff00Murlocs Speedrun:|r Detected old Speedy.gg data. Starting fresh with new data structure.")
end

-- Create a dungeon key from context
function Murlocs:MakeDungeonKey(ctx)
    if not ctx or not ctx.mapID or not ctx.difficultyID then
        return nil
    end
    return string.format("%d:%d", ctx.mapID, ctx.difficultyID)
end

-- Get or create a run bucket for a dungeon key
function Murlocs:GetRunBucket(dungeonKey)
    if not dungeonKey then return nil end
    
    if not MurlocsDB.runs[dungeonKey] then
        MurlocsDB.runs[dungeonKey] = {
            best = nil,
            history = {},
        }
    end
    
    return MurlocsDB.runs[dungeonKey]
end

-- Store a completed run
function Murlocs:StoreRun(run)
    if not run or not run.dungeonKey then
        return
    end
    
    local bucket = self:GetRunBucket(run.dungeonKey)
    if not bucket then return end
    
    -- Add to history (make a copy)
    local runCopy = CopyTable(run)
    table.insert(bucket.history, 1, runCopy) -- Insert at beginning (newest first)
    
    -- Keep only last 50 runs per dungeon
    while #bucket.history > 50 do
        table.remove(bucket.history)
    end
    
    -- Update best if this run is faster
    if not bucket.best or run.duration < bucket.best.duration then
        bucket.best = CopyTable(run)
        print(string.format("|cff00ff00Murlocs Speedrun:|r New personal best for %s: %s!", 
            run.instanceName or "dungeon", 
            self:FormatTime(run.duration)))
    end
end

-- Get personal best for a dungeon
function Murlocs:GetPersonalBest(dungeonKey)
    local bucket = self:GetRunBucket(dungeonKey)
    if not bucket then return nil end
    return bucket.best
end

-- Get delta from best for a completed run
function Murlocs:GetDeltaFromBest(run)
    if not run or not run.dungeonKey then
        return nil, nil
    end
    
    local best = self:GetPersonalBest(run.dungeonKey)
    if not best then
        return nil, nil
    end
    
    local delta = run.duration - best.duration
    return delta, best
end

-- Get live delta for current run
function Murlocs:GetLiveDeltaForCurrentRun()
    if not self.currentRun or not self.currentRun.active then
        return nil, nil, nil
    end
    
    local elapsed = GetTime() - self.currentRun.startGameTime
    local best = self:GetPersonalBest(self.currentRun.dungeonKey)
    
    if not best then
        return nil, nil, elapsed
    end
    
    local delta = elapsed - best.duration
    return delta, best, elapsed
end

-- Get segment delta vs best
function Murlocs:GetSegmentDelta(dungeonKey, segmentIndex)
    if not dungeonKey or not segmentIndex then
        return nil
    end
    
    local best = self:GetPersonalBest(dungeonKey)
    if not best or not best.segments or not best.segments[segmentIndex] then
        return nil
    end
    
    if not self.currentRun or not self.currentRun.segments or not self.currentRun.segments[segmentIndex] then
        return nil
    end
    
    local currentSplit = self.currentRun.segments[segmentIndex].split
    local bestSplit = best.segments[segmentIndex].split
    
    return currentSplit - bestSplit
end

-- Format time as MM:SS.mmm
function Murlocs:FormatTime(seconds, short)
    if not seconds then return "--:--.---" end
    
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    local msecs = (seconds - math.floor(seconds)) * 1000
    
    if short and mins == 0 then
        return string.format("%02d.%03d", secs, msecs)
    end
    
    return string.format("%02d:%02d.%03d", mins, secs, msecs)
end

-- Format delta with color and sign
function Murlocs:FormatDelta(delta, short)
    if not delta then return "" end
    
    local sign = delta >= 0 and "+" or "-"
    local color = delta < 0 and "|cff00ff00" or "|cffff0000" -- Green if ahead, red if behind
    local resetColor = "|r"
    
    return string.format("%s%s%s%s", color, sign, self:FormatTime(math.abs(delta), short), resetColor)
end

-- Export a specific run as encoded string
function Murlocs:ExportRun(run)
    if not run then
        return "No run to export"
    end
    
    -- Build segment array
    local segments = {}
    if run.segments then
        for _, seg in ipairs(run.segments) do
            table.insert(segments, {
                i = seg.index,
                l = seg.label,
                s = seg.split,
                d = seg.duration,
            })
        end
    end
    
    -- Build run object
    local runData = {
        dk = run.dungeonKey,
        cn = run.characterName,
        r = run.realm,
        c = run.classID,
        sp = run.specID,
        dn = run.instanceName,
        di = run.difficultyID,
        st = run.startTime,
        et = run.endTime,
        dur = run.duration,
        seg = segments,
        src = run.source or "addon_live",
        gb = run.gameBuild,
        v = "2.1.0"
    }
    
    -- Convert to JSON
    local json = self:TableToJSON(runData)
    
    -- Base64 encode
    local encoded = self:Base64Encode(json)
    
    return encoded
end

-- Export current run as encoded string
function Murlocs:ExportCurrentRun()
    local run = self.currentRun or MurlocsDB.lastRun
    
    if not run then
        return "No completed run to export"
    end
    
    return self:ExportRun(run)
end

-- Base64 encoding
function Murlocs:Base64Encode(data)
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = {}
    
    for i = 1, #data, 3 do
        local a, b, c = string.byte(data, i, i + 2)
        b = b or 0
        c = c or 0
        
        local n = a * 65536 + b * 256 + c
        local n1 = math.floor(n / 262144) + 1
        local n2 = math.floor((n % 262144) / 4096) + 1
        local n3 = math.floor((n % 4096) / 64) + 1
        local n4 = (n % 64) + 1
        
        result[#result + 1] = b64chars:sub(n1, n1)
        result[#result + 1] = b64chars:sub(n2, n2)
        result[#result + 1] = (i + 1 <= #data) and b64chars:sub(n3, n3) or '='
        result[#result + 1] = (i + 2 <= #data) and b64chars:sub(n4, n4) or '='
    end
    
    return table.concat(result)
end

-- Export recent runs to JSON-like string
function Murlocs:ExportRecentRuns(maxRuns)
    maxRuns = maxRuns or 20
    
    local runs = {}
    local count = 0
    
    -- Collect runs from all dungeons
    for dungeonKey, bucket in pairs(MurlocsDB.runs) do
        for _, run in ipairs(bucket.history) do
            if count >= maxRuns then break end
            
            -- Build segment array
            local segments = {}
            if run.segments then
                for _, seg in ipairs(run.segments) do
                    table.insert(segments, {
                        i = seg.index,
                        l = seg.label,
                        s = seg.split,
                        d = seg.duration,
                    })
                end
            end
            
            -- Build run object
            table.insert(runs, {
                dk = run.dungeonKey,
                cn = run.characterName,
                r = run.realm,
                c = run.classID,
                sp = run.specID,
                dn = run.instanceName,
                di = run.difficultyID,
                st = run.startTime,
                et = run.endTime,
                dur = run.duration,
                seg = segments,
                src = run.source or "addon_live",
                gb = run.gameBuild,
            })
            
            count = count + 1
        end
        
        if count >= maxRuns then break end
    end
    
    -- Convert to JSON-like string (simple implementation)
    local json = "["
    for i, run in ipairs(runs) do
        if i > 1 then json = json .. "," end
        json = json .. self:TableToJSON(run)
    end
    json = json .. "]"
    
    return json
end

-- Simple table to JSON converter
function Murlocs:TableToJSON(tbl)
    if type(tbl) ~= "table" then
        if type(tbl) == "string" then
            return '"' .. tbl:gsub('"', '\\"') .. '"'
        elseif type(tbl) == "number" then
            return tostring(tbl)
        elseif type(tbl) == "boolean" then
            return tbl and "true" or "false"
        else
            return "null"
        end
    end
    
    -- Check if array or object
    local isArray = true
    local count = 0
    for k, v in pairs(tbl) do
        count = count + 1
        if type(k) ~= "number" or k ~= count then
            isArray = false
            break
        end
    end
    
    if isArray then
        local result = "["
        for i, v in ipairs(tbl) do
            if i > 1 then result = result .. "," end
            result = result .. self:TableToJSON(v)
        end
        return result .. "]"
    else
        local result = "{"
        local first = true
        for k, v in pairs(tbl) do
            if not first then result = result .. "," end
            first = false
            result = result .. '"' .. tostring(k) .. '":' .. self:TableToJSON(v)
        end
        return result .. "}"
    end
end

-- Stub for future import functionality
function Murlocs:ImportRunData(str)
    -- Reserved for future: parse imported data from murlocs.com and merge
    print("|cff00ff00Murlocs Speedrun:|r Import functionality coming soon!")
end

-- Get player info
function Murlocs:GetPlayerInfo()
    return {
        name = UnitName("player"),
        realm = GetRealmName(),
        classID = select(3, UnitClass("player")),
        specID = GetSpecialization() and GetSpecializationInfo(GetSpecialization()) or 0,
    }
end

-- Check if player is solo (no party or raid members)
function Murlocs:IsSolo()
    local numGroupMembers = GetNumGroupMembers()
    -- GetNumGroupMembers returns 0 if solo, 1+ if in party/raid
    return numGroupMembers == 0
end

-- Get instance context
function Murlocs:GetInstanceContext()
    local name, instanceType, difficultyID, difficultyName, maxPlayers, 
          dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize = GetInstanceInfo()
    
    if not name or name == "" then
        return nil
    end
    
    return {
        instanceName = name,
        instanceType = instanceType,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        maxPlayers = maxPlayers,
        mapID = instanceMapID,
        groupSize = instanceGroupSize,
    }
end
