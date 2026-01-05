-- Hardcore Deathrace - Live Leaderboard System
-- Shows all player high scores (failed runs) with character name, level reached, score (time), date, and addon version
-- Based on Ultra Hardcore Leaderboard by Chills

-- Initialize leaderboard namespace
HardcoreDeathraceLeaderboard = HardcoreDeathraceLeaderboard or {}
local LB = HardcoreDeathraceLeaderboard

-- Communication prefix for addon messages
local PREFIX = "DRLB"

-- Initialize saved variables for leaderboard data
HardcoreDeathraceDB = HardcoreDeathraceDB or {}
HardcoreDeathraceDB.leaderboard = HardcoreDeathraceDB.leaderboard or {}
HardcoreDeathraceDB.leaderboardIndex = HardcoreDeathraceDB.leaderboardIndex or {}

-- Leaderboard frame and UI elements
local LB_FRAME = nil
local LB_SCROLL = nil
local LB_SCROLL_CHILD = nil
local LB_HEADER = nil

-- Configuration
local ROW_HEIGHT = 18
local VISIBLE_ROWS = 20
local COLUMNS = {
    { key = "name",    title = "Character Name", width = 120, align = "LEFT" },
    { key = "race",    title = "Race",           width = 80,  align = "CENTER" },
    { key = "class",   title = "Class",          width = 80,  align = "CENTER" },
    { key = "level",   title = "Level",          width = 60,  align = "CENTER" },
    { key = "score",   title = "Score (Time)",   width = 120, align = "CENTER" },
    { key = "selfFound", title = "Self-Found",   width = 80,  align = "CENTER" },
    { key = "date",    title = "Date",           width = 100, align = "CENTER" },
    { key = "version", title = "Version",        width = 80,  align = "CENTER" },
}

-- Sort state
local sortState = {
    key = "score",  -- Default sort by score (highest first)
    asc = false     -- Descending by default (highest scores first)
}

-- Track seen entries (for online/offline status)
LB.seen = LB.seen or {}

-- Store reference to WoW API GetServerTime before we define our wrapper
local WoWGetServerTime = GetServerTime

-- Get current server time (wrapper function)
local function GetServerTime()
    return (WoWGetServerTime and WoWGetServerTime()) or time()
end

-- Check if player has the "Self-Found Adventurer" buff
local function IsSelfFound()
    -- Check for the "Self-Found Adventurer" buff
    local buffName = "Self-Found Adventurer"
    
    -- Iterate through buff slots (1-40 for Classic Era)
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then
            break  -- No more buffs
        end
        if name == buffName then
            return true
        end
    end
    
    return false
end

-- Format date from timestamp
local function FormatDate(timestamp)
    if not timestamp or timestamp == 0 then
        return "Unknown"
    end
    
    -- Get server time for date calculation
    local serverTime = GetServerTime()
    
    -- Calculate days ago
    local daysAgo = math.floor((serverTime - timestamp) / 86400)
    
    if daysAgo == 0 then
        return "Today"
    elseif daysAgo == 1 then
        return "Yesterday"
    elseif daysAgo < 7 then
        return daysAgo .. " days ago"
    elseif daysAgo < 30 then
        local weeksAgo = math.floor(daysAgo / 7)
        return weeksAgo .. (weeksAgo == 1 and " week ago" or " weeks ago")
    elseif daysAgo < 365 then
        local monthsAgo = math.floor(daysAgo / 30)
        return monthsAgo .. (monthsAgo == 1 and " month ago" or " months ago")
    else
        local yearsAgo = math.floor(daysAgo / 365)
        return yearsAgo .. (yearsAgo == 1 and " year ago" or " years ago")
    end
end

-- Format time score for display
local function FormatScore(seconds)
    if not seconds or seconds < 0 then
        return "0:00"
    end
    
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if days > 0 then
        return string.format("%dd %02d:%02d:%02d", days, hours, minutes, secs)
    elseif hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%d:%02d", minutes, secs)
    end
end

-- Build player record from current state (when run fails)
function LB:BuildFailureRecord()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local charKey = playerName .. "-" .. realmName
    
    -- Get character race and class
    local playerRace, raceFile = UnitRace("player")
    local playerClass, classFile = UnitClass("player")
    
    -- Get failure data from Core
    local failureLevel = HardcoreDeathrace.GetFailureLevel()
    local totalTimePlayed = HardcoreDeathrace.GetTotalTimePlayed()
    local addonVersion = GetAddOnMetadata("Hardcore Deathrace", "Version") or "1.0.12"
    
    -- Check if character is self-found
    local selfFound = IsSelfFound()
    
    local record = {
        name = charKey,  -- Use name-realm format for uniqueness
        race = playerRace or "Unknown",
        class = playerClass or "Unknown",
        level = failureLevel or 1,
        score = totalTimePlayed or 0,  -- Score is time survived in seconds
        date = GetServerTime(),  -- Timestamp of failure
        version = addonVersion,
        realm = realmName,
        selfFound = selfFound,  -- Self-found status
    }
    
    return record
end

-- Build player record from current state (when run succeeds - reaches level 60)
function LB:BuildSuccessRecord()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local charKey = playerName .. "-" .. realmName
    
    -- Get character race and class
    local playerRace, raceFile = UnitRace("player")
    local playerClass, classFile = UnitClass("player")
    
    -- Get success data from Core
    local currentLevel = HardcoreDeathrace.GetCurrentLevel()
    local totalTimePlayed = HardcoreDeathrace.GetTotalTimePlayed()
    local addonVersion = GetAddOnMetadata("Hardcore Deathrace", "Version") or "1.0.12"
    
    -- Check if character is self-found
    local selfFound = IsSelfFound()
    
    local record = {
        name = charKey,  -- Use name-realm format for uniqueness
        race = playerRace or "Unknown",
        class = playerClass or "Unknown",
        level = currentLevel or 60,  -- Should be 60 for successful runs
        score = totalTimePlayed or 0,  -- Score is time survived in seconds
        date = GetServerTime(),  -- Timestamp of success
        version = addonVersion,
        realm = realmName,
        selfFound = selfFound,  -- Self-found status
    }
    
    return record
end

-- Store a run record (indefinitely) - works for both failed and successful runs
function LB:StoreRecord(record)
    if not record or not record.name or not record.date then
        return false
    end
    
    -- Initialize storage if needed
    HardcoreDeathraceDB.leaderboard = HardcoreDeathraceDB.leaderboard or {}
    HardcoreDeathraceDB.leaderboardIndex = HardcoreDeathraceDB.leaderboardIndex or {}
    
    local cache = HardcoreDeathraceDB.leaderboard
    local index = HardcoreDeathraceDB.leaderboardIndex
    
    -- Check if this is a better score for this character
    local existing = cache[record.name]
    local isNewRecord = false
    
    if not existing or record.score > (existing.score or 0) then
        -- Store the record (only keep best score per character)
        cache[record.name] = {
            name = record.name,
            race = record.race or "Unknown",
            class = record.class or "Unknown",
            level = record.level,
            score = record.score,
            date = record.date,
            version = record.version,
            realm = record.realm,
            selfFound = record.selfFound or false,  -- Self-found status
        }
        
        -- Update index (sorted by date, newest first)
        -- Remove existing entry if present
        for i, entry in ipairs(index) do
            if entry.name == record.name then
                table.remove(index, i)
                break
            end
        end
        
        -- Insert new entry in sorted order (newest first)
        local newEntry = { name = record.name, date = record.date }
        if #index == 0 then
            table.insert(index, newEntry)
        else
            for i, entry in ipairs(index) do
                if record.date > entry.date then
                    table.insert(index, i, newEntry)
                    isNewRecord = true
                    break
                end
            end
            if not isNewRecord then
                table.insert(index, newEntry)  -- Append if oldest
            end
        end
        
        -- Update seen entry
        LB.seen[record.name] = {
            name = record.name,
            race = record.race or "Unknown",
            class = record.class or "Unknown",
            level = record.level,
            score = record.score,
            date = record.date,
            version = record.version,
            realm = record.realm,
            selfFound = record.selfFound or false,  -- Self-found status
            last = GetServerTime(),
        }
        
        return true
    end
    
    return false
end

-- Broadcast record to other players via DeathRace channel exclusively
-- Used for both failed and successful runs
function LB:BroadcastRecord(record)
    if not record then
        return
    end
    
    -- Serialize the record (simple table serialization)
    -- Format: name|race|class|level|score|date|version|selfFound
    local payload = string.format("%s|%s|%s|%d|%d|%d|%s|%d", 
        record.name or "",
        record.race or "Unknown",
        record.class or "Unknown",
        record.level or 0,
        record.score or 0,
        record.date or GetServerTime(),
        record.version or "1.0.12",
        (record.selfFound and 1) or 0  -- Convert boolean to 1/0
    )
    
    -- Broadcast exclusively via DeathRace custom channel (realm-wide, works solo)
    -- Use SendAddonMessage for addon-to-addon communication (invisible to players)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        -- Modern API (Classic Era compatible)
        if HardcoreDeathraceJoinChannel then
            local deathRaceChannelID = HardcoreDeathraceJoinChannel.GetChannelID()
            if deathRaceChannelID > 0 then
                C_ChatInfo.SendAddonMessage(PREFIX, payload, "CHANNEL", deathRaceChannelID)
            else
                -- Not in channel yet, try to join and retry broadcast
                HardcoreDeathraceJoinChannel.JoinChannel()
                C_Timer.After(1, function()
                    local retryChannelID = HardcoreDeathraceJoinChannel.GetChannelID()
                    if retryChannelID > 0 then
                        C_ChatInfo.SendAddonMessage(PREFIX, payload, "CHANNEL", retryChannelID)
                    end
                end)
            end
        end
    elseif SendAddonMessage then
        -- Legacy API fallback
        if HardcoreDeathraceJoinChannel then
            local deathRaceChannelID = HardcoreDeathraceJoinChannel.GetChannelID()
            if deathRaceChannelID > 0 then
                SendAddonMessage(PREFIX, payload, "CHANNEL", deathRaceChannelID)
            else
                -- Not in channel yet, try to join and retry broadcast
                HardcoreDeathraceJoinChannel.JoinChannel()
                C_Timer.After(1, function()
                    local retryChannelID = HardcoreDeathraceJoinChannel.GetChannelID()
                    if retryChannelID > 0 then
                        SendAddonMessage(PREFIX, payload, "CHANNEL", retryChannelID)
                    end
                end)
            end
        end
    end
end

-- Handle incoming leaderboard messages
function LB:OnMessageReceived(prefix, message, channel, sender)
    if prefix ~= PREFIX or not message then
        return
    end
    
    -- Check for snapshot request (SNAP_REQ)
    if message == "SNAP_REQ" then
        -- Someone is requesting all our leaderboard data
        LB:SendSnapshot(sender)
        return
    end
    
    -- Check for snapshot data chunks (SNAP:chunkNum:totalChunks:record1|||record2|||...)
    if message:sub(1, 5) == "SNAP:" then
        -- Bulk snapshot data (may be chunked)
        local snapshotData = message:sub(6)  -- Remove "SNAP:" prefix
        
        -- Check if this is a chunked message (format: chunkNum:totalChunks:data)
        local chunkNum, totalChunks, chunkData = snapshotData:match("^(%d+):(%d+):(.+)$")
        
        if chunkNum and totalChunks and chunkData then
            -- Chunked snapshot - need to reassemble
            chunkNum = tonumber(chunkNum)
            totalChunks = tonumber(totalChunks)
            
            -- Initialize chunk buffer if needed
            if not LB.snapshotChunks then
                LB.snapshotChunks = {}
                LB.snapshotChunkTotal = 0
            end
            
            -- Store chunk
            LB.snapshotChunks[chunkNum] = chunkData
            LB.snapshotChunkTotal = totalChunks
            
            -- Check if we have all chunks
            local haveAllChunks = true
            for i = 1, totalChunks do
                if not LB.snapshotChunks[i] then
                    haveAllChunks = false
                    break
                end
            end
            
            -- If we have all chunks, process the complete snapshot
            if haveAllChunks then
                -- Reassemble full data
                local chunks = {}
                for i = 1, totalChunks do
                    table.insert(chunks, LB.snapshotChunks[i])
                end
                local fullData = table.concat(chunks, "")
                
                -- Parse records
                local records = {}
                fullData = fullData:gsub("%|%|%|", "\001")  -- Replace ||| with delimiter
                
                for recordStr in string.gmatch(fullData, "([^\001]+)") do
                    if recordStr and recordStr ~= "" then
                        local parts = {}
                        for part in string.gmatch(recordStr, "([^:]+)") do
                            table.insert(parts, part)
                        end
                        
                        if #parts >= 7 then
                            table.insert(records, {
                                name = parts[1],
                                race = parts[2] or "Unknown",
                                class = parts[3] or "Unknown",
                                level = tonumber(parts[4]) or 0,
                                score = tonumber(parts[5]) or 0,
                                date = tonumber(parts[6]) or GetServerTime(),
                                version = parts[7] or "1.0.12",
                                selfFound = (#parts >= 8 and tonumber(parts[8]) == 1) or false,  -- Support old format
                            })
                        end
                    end
                end
                
                -- Store all records
                local changed = false
                for _, record in ipairs(records) do
                    if LB:StoreRecord(record) then
                        changed = true
                    end
                end
                
                -- Clear chunk buffer
                LB.snapshotChunks = nil
                LB.snapshotChunkTotal = 0
                
                if changed and LB_FRAME and LB_FRAME:IsShown() then
                    LB:RefreshUI()
                end
            end
        else
            -- Non-chunked snapshot (backwards compatibility or single chunk)
            -- Parse directly
            snapshotData = snapshotData:gsub("%|%|%|", "\001")
            local records = {}
            
            for recordStr in string.gmatch(snapshotData, "([^\001]+)") do
                if recordStr and recordStr ~= "" then
                    local parts = {}
                    for part in string.gmatch(recordStr, "([^:]+)") do
                        table.insert(parts, part)
                    end
                    
                    if #parts >= 7 then
                        table.insert(records, {
                            name = parts[1],
                            race = parts[2] or "Unknown",
                            class = parts[3] or "Unknown",
                            level = tonumber(parts[4]) or 0,
                            score = tonumber(parts[5]) or 0,
                            date = tonumber(parts[6]) or GetServerTime(),
                            version = parts[7] or "1.0.12",
                            selfFound = (#parts >= 8 and tonumber(parts[8]) == 1) or false,  -- Support old format
                        })
                    end
                end
            end
            
            local changed = false
            for _, record in ipairs(records) do
                if LB:StoreRecord(record) then
                    changed = true
                end
            end
            
            if changed and LB_FRAME and LB_FRAME:IsShown() then
                LB:RefreshUI()
            end
        end
        return
    end
    
    -- Regular single record message: name|race|class|level|score|date|version|selfFound
    local parts = {}
    for part in string.gmatch(message, "([^|]+)") do
        table.insert(parts, part)
    end
    
    -- Support old formats (5 parts, 7 parts) and new format (8 parts with selfFound)
    if #parts < 5 then
        return  -- Invalid message format
    end
    
    local record
    if #parts >= 8 then
        -- New format with race, class, and selfFound
        record = {
            name = parts[1],
            race = parts[2] or "Unknown",
            class = parts[3] or "Unknown",
            level = tonumber(parts[4]) or 0,
            score = tonumber(parts[5]) or 0,
            date = tonumber(parts[6]) or GetServerTime(),
            version = parts[7] or "1.0.12",
            selfFound = (tonumber(parts[8]) == 1),  -- Convert 1/0 back to boolean
        }
    elseif #parts >= 7 then
        -- Format with race and class (no selfFound)
        record = {
            name = parts[1],
            race = parts[2] or "Unknown",
            class = parts[3] or "Unknown",
            level = tonumber(parts[4]) or 0,
            score = tonumber(parts[5]) or 0,
            date = tonumber(parts[6]) or GetServerTime(),
            version = parts[7] or "1.0.12",
            selfFound = false,  -- Default to false for old records
        }
    else
        -- Old format (backwards compatibility)
        record = {
            name = parts[1],
            race = "Unknown",
            class = "Unknown",
            level = tonumber(parts[2]) or 0,
            score = tonumber(parts[3]) or 0,
            date = tonumber(parts[4]) or GetServerTime(),
            version = parts[5] or "1.0.12",
            selfFound = false,  -- Default to false for old records
        }
    end
    
    -- Store the received record (works for both failed and successful runs)
    if LB:StoreRecord(record) then
        -- Refresh UI if visible
        if LB_FRAME and LB_FRAME:IsShown() then
            LB:RefreshUI()
        end
    end
end

-- Register for addon messages
function LB:RegisterComm()
    -- Register addon message prefix (required before receiving messages)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
    end
    
    -- Create a frame to receive addon messages
    if not LB.commFrame then
        LB.commFrame = CreateFrame("Frame")
        LB.commFrame:RegisterEvent("CHAT_MSG_ADDON")
        LB.commFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender, ...)
            -- In Classic Era, CHAT_MSG_ADDON event parameters: prefix, message, channel, sender
            if prefix == PREFIX and message then
                LB:OnMessageReceived(prefix, message, channel, sender)
            end
        end)
    end
end

-- Build rows for UI display
function LB:BuildRowsForUI()
    local cache = HardcoreDeathraceDB.leaderboard or {}
    local index = HardcoreDeathraceDB.leaderboardIndex or {}
    local rows = {}
    
    -- Build rows from cache (using index for sorting)
    for _, entry in ipairs(index) do
        local rec = cache[entry.name]
        if rec then
            table.insert(rows, {
                name = rec.name,
                race = rec.race or "Unknown",
                class = rec.class or "Unknown",
                level = rec.level or 0,
                score = rec.score or 0,
                date = rec.date or 0,
                version = rec.version or "1.0.12",
                selfFound = rec.selfFound or false,
            })
        end
    end
    
    return rows
end

-- Sort comparison function
local function valueForSort(row, key)
    if key == "name" or key == "version" or key == "race" or key == "class" then
        return tostring(row[key] or ""):lower()
    elseif key == "score" then
        return tonumber(row.score) or 0
    elseif key == "level" then
        return tonumber(row.level) or 0
    elseif key == "date" then
        return tonumber(row.date) or 0
    elseif key == "selfFound" then
        return (row.selfFound and 1) or 0  -- Sort boolean as 1/0
    else
        return 0
    end
end

-- Apply sorting to rows
local function ApplySort(rows)
    if sortState.key then
        table.sort(rows, function(a, b)
            local va = valueForSort(a, sortState.key)
            local vb = valueForSort(b, sortState.key)
            
            if va == vb then
                -- Tiebreaker: sort by score descending
                return (a.score or 0) > (b.score or 0)
            end
            
            if sortState.asc then
                return va < vb
            else
                return va > vb
            end
        end)
    end
end

-- Update header arrows to show sort direction
local function UpdateHeaderArrows()
    if not LB_HEADER then
        return
    end
    
    for i, col in ipairs(COLUMNS) do
        local txt = col.title
        if sortState.key == col.key then
            -- Add arrow indicator
            txt = txt .. (sortState.asc and " |TInterface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Up:30:25|t" 
                                     or " |TInterface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Up:30:25|t")
        end
        LB_HEADER[i]:SetText(txt)
    end
end

-- Create the leaderboard UI frame
function LB:CreateFrame()
    if LB_FRAME then
        return LB_FRAME
    end
    
    -- Create main frame (wider to accommodate all columns including self-found)
    -- Column widths: 120+80+80+60+120+100+80+80 = 720, plus 7×10 spacing = 70, plus padding = ~80
    local f = CreateFrame("Frame", "HardcoreDeathraceLeaderboardFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetFrameStrata("HIGH")
    f:SetSize(860, 450)  -- Increased width to 860 to properly fit all 8 columns with adequate spacing
    f:SetPoint("CENTER")
    f:Hide()
    
    -- Allow closing with ESC
    local frameName = f:GetName()
    local exists = false
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == frameName then
            exists = true
            break
        end
    end
    if not exists then
        table.insert(UISpecialFrames, frameName)
    end
    
    -- Make frame movable
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("CENTER", f.TitleBg, "CENTER")
    f.title:SetText("|cFFFF0000Hardcore Deathrace Leaderboard|r")
    
    -- Calculate total width for columns
    local totalWidth = 0
    for _, col in ipairs(COLUMNS) do
        totalWidth = totalWidth + col.width + 10
    end
    totalWidth = totalWidth - 10
    
    -- Create header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
    header:SetSize(totalWidth, 20)
    
    LB_HEADER = {}
    local x = 0
    local NAME_COLUMN_LEFT_PADDING = 10  -- Padding for name column
    for i, col in ipairs(COLUMNS) do
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        -- Add left padding for the first column (name)
        local xPos = x
        if i == 1 then
            xPos = xPos + NAME_COLUMN_LEFT_PADDING
        end
        fs:SetPoint("LEFT", header, "LEFT", xPos, 0)
        fs:SetSize(col.width, 20)
        fs:SetJustifyH(col.align or "CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetText(col.title)
        fs:EnableMouse(true)
        fs:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then return end
            if sortState.key == col.key then
                sortState.asc = not sortState.asc
            else
                sortState.key = col.key
                -- Default: numbers desc, strings asc
                local numeric = (col.key == "score" or col.key == "level" or col.key == "date")
                sortState.asc = not numeric
            end
            UpdateHeaderArrows()
            LB:RefreshUI()
        end)
        LB_HEADER[i] = fs
        x = x + col.width + 10
    end
    
    -- Create scroll frame
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 36)
    LB_SCROLL = scroll
    
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(totalWidth, 1)
    scroll:SetScrollChild(child)
    LB_SCROLL_CHILD = child
    
    -- Create row frames
    f.rows = {}
    for i = 1, VISIBLE_ROWS + 2 do
        local row = CreateFrame("Frame", nil, child)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((i-1) * ROW_HEIGHT))
        row:SetSize(totalWidth, ROW_HEIGHT)
        row:EnableMouse(true)
        row.cols = {}
        
        local xOffset = 0
        local NAME_COLUMN_LEFT_PADDING = 10  -- Padding for name column
        for j, col in ipairs(COLUMNS) do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            -- Add left padding for the first column (name)
            local xPos = xOffset
            if j == 1 then
                xPos = xPos + NAME_COLUMN_LEFT_PADDING
            end
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xPos, 0)
            fs:SetWidth(col.width)
            fs:SetHeight(ROW_HEIGHT)
            fs:SetJustifyH(COLUMNS[j].align or "CENTER")
            fs:SetJustifyV("MIDDLE")
            row.cols[j] = fs
            xOffset = xOffset + col.width + 10
        end
        
        -- Highlight on hover
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints(row)
        row.highlight:SetColorTexture(0.95, 0.26, 0.21, 0.25)
        row.highlight:Hide()
        
        row:SetScript("OnEnter", function(self)
            self.highlight:Show()
        end)
        row:SetScript("OnLeave", function(self)
            self.highlight:Hide()
        end)
        
        row:Hide()
        f.rows[i] = row
    end
    
    -- Close button
    f.CloseButton:SetScript("OnClick", function() f:Hide() end)
    
    -- Player count label
    local playerCountLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    playerCountLabel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 14)
    playerCountLabel:SetJustifyH("RIGHT")
    playerCountLabel:SetJustifyV("MIDDLE")
    playerCountLabel:SetText("Total entries: 0")
    f.playerCountLabel = playerCountLabel
    
    LB_FRAME = f
    UpdateHeaderArrows()
    return f
end

-- Refresh the leaderboard UI
function LB:RefreshUI()
    if not LB_FRAME then
        LB:CreateFrame()
    end
    
    local rows = LB:BuildRowsForUI()
    ApplySort(rows)
    
    -- Update player count
    LB_FRAME.playerCountLabel:SetText(string.format("Total entries: %d", #rows))
    
    -- Hide all rows first
    for _, row in ipairs(LB_FRAME.rows) do
        row:Hide()
    end
    
    -- Update scroll child height (ensure minimum height for proper display)
    local totalHeight = math.max(#rows * ROW_HEIGHT, VISIBLE_ROWS * ROW_HEIGHT)
    LB_SCROLL_CHILD:SetHeight(totalHeight)
    
    -- Show "No entries" message if empty
    if #rows == 0 then
        if not LB_FRAME.emptyMessage then
            local emptyMsg = LB_FRAME:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            emptyMsg:SetPoint("CENTER", LB_SCROLL, "CENTER", 0, 0)
            emptyMsg:SetTextColor(0.7, 0.7, 0.7, 1)  -- Gray color
            emptyMsg:SetText("No leaderboard entries yet.\nFailed runs will appear here.")
            LB_FRAME.emptyMessage = emptyMsg
        end
        LB_FRAME.emptyMessage:Show()
    else
        if LB_FRAME.emptyMessage then
            LB_FRAME.emptyMessage:Hide()
        end
    end
    
    -- Show and populate rows
    for i, rowData in ipairs(rows) do
        local row = LB_FRAME.rows[i]
        if not row then
            -- Create new row if needed
            row = CreateFrame("Frame", nil, LB_SCROLL_CHILD)
            row:SetPoint("TOPLEFT", LB_SCROLL_CHILD, "TOPLEFT", 0, -((i-1) * ROW_HEIGHT))
            row:SetSize(LB_SCROLL_CHILD:GetWidth(), ROW_HEIGHT)
            row:EnableMouse(true)
            row.cols = {}
            
            local xOffset = 0
            local NAME_COLUMN_LEFT_PADDING = 10  -- Padding for name column
            for j, col in ipairs(COLUMNS) do
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                -- Add left padding for the first column (name)
                local xPos = xOffset
                if j == 1 then
                    xPos = xPos + NAME_COLUMN_LEFT_PADDING
                end
                fs:SetPoint("TOPLEFT", row, "TOPLEFT", xPos, 0)
                fs:SetWidth(col.width)
                fs:SetHeight(ROW_HEIGHT)
                fs:SetJustifyH(COLUMNS[j].align or "CENTER")
                fs:SetJustifyV("MIDDLE")
                row.cols[j] = fs
                xOffset = xOffset + col.width + 10
            end
            
            row.highlight = row:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetAllPoints(row)
            row.highlight:SetColorTexture(0.95, 0.26, 0.21, 0.25)
            row.highlight:Hide()
            
            row:SetScript("OnEnter", function(self)
                self.highlight:Show()
            end)
            row:SetScript("OnLeave", function(self)
                self.highlight:Hide()
            end)
            
            LB_FRAME.rows[i] = row
        end
        
        -- Populate row data
        local nameDisplay = rowData.name
        -- Remove realm suffix for display if it's a name-realm format
        if nameDisplay:find("-") then
            nameDisplay = nameDisplay:match("^([^-]+)")
        end
        
        row.cols[1]:SetText(nameDisplay)  -- Character name
        row.cols[2]:SetText(rowData.race or "Unknown")  -- Race
        row.cols[3]:SetText(rowData.class or "Unknown")  -- Class
        row.cols[4]:SetText(tostring(rowData.level))  -- Level
        row.cols[5]:SetText(FormatScore(rowData.score))  -- Score (time)
        -- Self-Found column: show checkmark (✓) if self-found, empty otherwise
        if rowData.selfFound then
            row.cols[6]:SetText("✓")  -- Checkmark character
            row.cols[6]:SetTextColor(0, 1, 0)  -- Green color for checkmark
        else
            row.cols[6]:SetText("")  -- Empty for non-self-found
        end
        row.cols[7]:SetText(FormatDate(rowData.date))  -- Date
        row.cols[8]:SetText(rowData.version)  -- Version
        
        -- Color code: highlight top scores (but preserve green checkmark in self-found column)
        local r, g, b = 1, 1, 1  -- Default white
        if i == 1 then
            r, g, b = 1, 0.84, 0  -- Gold for #1
        elseif i == 2 then
            r, g, b = 0.75, 0.75, 0.75  -- Silver for #2
        elseif i == 3 then
            r, g, b = 0.8, 0.5, 0.2  -- Bronze for #3
        end
        
        -- Apply color to all columns except self-found (column 6) which keeps its green checkmark
        for j, fs in ipairs(row.cols) do
            if j ~= 6 then  -- Don't override self-found column color
                fs:SetTextColor(r, g, b)
            end
        end
        
        row:Show()
    end
    
    LB_SCROLL:UpdateScrollChildRect()
end

-- Toggle leaderboard visibility
function LB:Toggle()
    if not LB_FRAME then
        LB:CreateFrame()
    end
    
    if LB_FRAME:IsShown() then
        LB_FRAME:Hide()
    else
        LB_FRAME:Show()
        LB:RefreshUI()
    end
end

-- Send snapshot request to download all leaderboard data
function LB:RequestSnapshot()
    -- Request snapshot from peers in DeathRace channel
    -- We'll broadcast the request on the channel and anyone with data will respond
    if HardcoreDeathraceJoinChannel then
        local deathRaceChannelID = HardcoreDeathraceJoinChannel.GetChannelID()
        if deathRaceChannelID > 0 then
            -- Send snapshot request
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                C_ChatInfo.SendAddonMessage(PREFIX, "SNAP_REQ", "CHANNEL", deathRaceChannelID)
            elseif SendAddonMessage then
                SendAddonMessage(PREFIX, "SNAP_REQ", "CHANNEL", deathRaceChannelID)
            end
        else
            -- Not in channel yet, wait and retry
            C_Timer.After(2, function()
                LB:RequestSnapshot()
            end)
        end
    end
end

-- Send snapshot of all leaderboard data (responds to SNAP_REQ)
-- Sends data in chunks due to 255 character message limit
function LB:SendSnapshot(target)
    -- Get all records from storage
    local cache = HardcoreDeathraceDB.leaderboard or {}
    local index = HardcoreDeathraceDB.leaderboardIndex or {}
    local records = {}
    
    -- Build records list
    for _, entry in ipairs(index) do
        local rec = cache[entry.name]
        if rec then
            table.insert(records, rec)
        end
    end
    
    if #records == 0 then
        return  -- No data to send
    end
    
    -- Serialize records into snapshot format
    -- Format per record: name:race:class:level:score:date:version:selfFound
    local recordStrings = {}
    for _, rec in ipairs(records) do
        local recordStr = string.format("%s:%s:%s:%d:%d:%d:%s:%d",
            rec.name or "",
            rec.race or "Unknown",
            rec.class or "Unknown",
            rec.level or 0,
            rec.score or 0,
            rec.date or GetServerTime(),
            rec.version or "1.0.12",
            (rec.selfFound and 1) or 0  -- Convert boolean to 1/0
        )
        table.insert(recordStrings, recordStr)
    end
    
    -- Send in chunks due to 255 character limit
    -- Format: SNAP:chunkNum:totalChunks:record1|||record2|||...
    local maxChunkSize = 200  -- Conservative limit (leave room for prefix)
    local allRecords = table.concat(recordStrings, "|||")
    local totalLength = #allRecords
    local chunkSize = maxChunkSize - 20  -- Reserve space for "SNAP:X:Y:" prefix
    local totalChunks = math.ceil(totalLength / chunkSize)
    
    -- Send chunks with delays to avoid spam
    for chunkNum = 1, totalChunks do
        local startPos = (chunkNum - 1) * chunkSize + 1
        local endPos = math.min(startPos + chunkSize - 1, totalLength)
        local chunkData = allRecords:sub(startPos, endPos)
        
        -- Format: SNAP:chunkNum:totalChunks:data
        local chunkPayload = string.format("SNAP:%d:%d:%s", chunkNum, totalChunks, chunkData)
        
        -- Send chunk after a delay (stagger chunks to avoid rate limiting)
        C_Timer.After(0.2 * chunkNum, function()
            if HardcoreDeathraceJoinChannel then
                local deathRaceChannelID = HardcoreDeathraceJoinChannel.GetChannelID()
                if deathRaceChannelID > 0 then
                    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                        C_ChatInfo.SendAddonMessage(PREFIX, chunkPayload, "CHANNEL", deathRaceChannelID)
                    elseif SendAddonMessage then
                        SendAddonMessage(PREFIX, chunkPayload, "CHANNEL", deathRaceChannelID)
                    end
                end
            end
        end)
    end
end

-- Initialize leaderboard system
function LB:Initialize()
    -- Register for addon messages
    LB:RegisterComm()
    
    -- Create frame (but don't show it yet)
    LB:CreateFrame()
    
    -- Join DeathRace custom channel (realm-wide, works solo, invisible addon messages)
    -- This creates/joins the "DeathRace" channel for addon communication
    -- The channel is automatically created when the first player joins it
    if HardcoreDeathraceJoinChannel and HardcoreDeathraceJoinChannel.JoinChannel then
        HardcoreDeathraceJoinChannel.JoinChannel()
    end
    
    -- Request snapshot of all leaderboard data after a delay (wait for channel to be ready)
    C_Timer.After(3, function()
        LB:RequestSnapshot()
    end)
end

-- Export functions for external use
HardcoreDeathraceLeaderboard = LB

