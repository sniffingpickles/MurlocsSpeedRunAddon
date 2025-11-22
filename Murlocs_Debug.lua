-- Debug output to chat
local addonName, Murlocs = ...

print("|cff00ff00Murlocs_Debug.lua loaded|r")

function Murlocs:Debug_Show()
    local run = self.currentRun or MurlocsDB.lastRun
    
    if not run then
        print("|cffff0000No run data available. Complete a dungeon run first!|r")
        return
    end
    
    print("|cff00ff00=== MURLOCS DEBUG INFO ===|r")
    print(string.format("Dungeon: %s", run.instanceName or "Unknown"))
    print(string.format("Key: %s", run.dungeonKey or "Unknown"))
    print(string.format("Duration: %.2fs", run.duration or 0))
    print(string.format("Active: %s", tostring(run.active)))
    print("")
    
    print("|cff00ff00=== SEGMENTS ===|r")
    if run.segments and #run.segments > 0 then
        for i, seg in ipairs(run.segments) do
            print(string.format("|cffffff00[%d] %s|r", i, seg.label))
            print(string.format("  Split: %.3fs | Duration: %.3fs", seg.split or 0, seg.duration or 0))
            print(string.format("  Creature Display ID: %s", seg.creatureDisplayId or "nil"))
        end
    else
        print("No segments captured")
    end
    
    print("")
    print("|cff00ff00=== EXPORT JSON ===|r")
    
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
    
    print(json)
    print("|cff00ff00=== END DEBUG ===|r")
end
