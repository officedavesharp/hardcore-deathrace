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

-- Get current server time
local function GetServerTime()
    return (GetServerTime and GetServerTime()) or time()
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
    
    local record = {
        name = charKey,  -- Use name-realm format for uniqueness
        race = playerRace or "Unknown",
        class = playerClass or "Unknown",
        level = failureLevel or 1,
        score = totalTimePlayed or 0,  -- Score is time survived in seconds
        date = GetServerTime(),  -- Timestamp of failure
        version = addonVersion,
        realm = realmName,
    }
    
    return record
end

-- Store a failed run record (indefinitely)
function LB:StoreFailureRecord(record)
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
            last = GetServerTime(),
        }
        
        return true
    end
    
    return false
end

-- Broadcast failure record to other players
function LB:BroadcastFailure(record)
    if not record then
        return
    end
    
    -- Serialize the record (simple table serialization)
    -- Format: name|race|class|level|score|date|version
    local payload = string.format("%s|%s|%s|%d|%d|%d|%s", 
        record.name or "",
        record.race or "Unknown",
        record.class or "Unknown",
        record.level or 0,
        record.score or 0,
        record.date or GetServerTime(),
        record.version or "1.0.12"
    )
    
    -- Broadcast via GUILD and YELL channels (similar to UHLB)
    -- Use SendAddonMessage for addon-to-addon communication
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        -- Modern API (Classic Era compatible)
        C_ChatInfo.SendAddonMessage(PREFIX, payload, "GUILD")
        C_ChatInfo.SendAddonMessage(PREFIX, payload, "YELL")
    elseif SendAddonMessage then
        -- Legacy API fallback
        SendAddonMessage(PREFIX, payload, "GUILD")
        SendAddonMessage(PREFIX, payload, "YELL")
    end
end

-- Handle incoming leaderboard messages
function LB:OnMessageReceived(prefix, message, channel, sender)
    if prefix ~= PREFIX or not message then
        return
    end
    
    -- Parse the message: name|race|class|level|score|date|version
    local parts = {}
    for part in string.gmatch(message, "([^|]+)") do
        table.insert(parts, part)
    end
    
    -- Support both old format (5 parts) and new format (7 parts)
    if #parts < 5 then
        return  -- Invalid message format
    end
    
    local record
    if #parts >= 7 then
        -- New format with race and class
        record = {
            name = parts[1],
            race = parts[2] or "Unknown",
            class = parts[3] or "Unknown",
            level = tonumber(parts[4]) or 0,
            score = tonumber(parts[5]) or 0,
            date = tonumber(parts[6]) or GetServerTime(),
            version = parts[7] or "1.0.12",
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
        }
    end
    
    -- Store the received record
    if LB:StoreFailureRecord(record) then
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
    
    -- Create main frame (wider to accommodate race and class columns)
    -- Column widths: 120+80+80+60+120+100+80 = 640, plus 6×10 spacing = 60, plus padding = ~80
    local f = CreateFrame("Frame", "HardcoreDeathraceLeaderboardFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetFrameStrata("HIGH")
    f:SetSize(780, 450)  -- Increased width to 780 to properly fit all 7 columns with adequate spacing
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
    for i, col in ipairs(COLUMNS) do
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", header, "LEFT", x, 0)
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
        for j, col in ipairs(COLUMNS) do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOffset, 0)
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
            for j, col in ipairs(COLUMNS) do
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetPoint("TOPLEFT", row, "TOPLEFT", xOffset, 0)
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
        row.cols[6]:SetText(FormatDate(rowData.date))  -- Date
        row.cols[7]:SetText(rowData.version)  -- Version
        
        -- Color code: highlight top scores
        local r, g, b = 1, 1, 1  -- Default white
        if i == 1 then
            r, g, b = 1, 0.84, 0  -- Gold for #1
        elseif i == 2 then
            r, g, b = 0.75, 0.75, 0.75  -- Silver for #2
        elseif i == 3 then
            r, g, b = 0.8, 0.5, 0.2  -- Bronze for #3
        end
        
        for _, fs in ipairs(row.cols) do
            fs:SetTextColor(r, g, b)
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

-- Initialize leaderboard system
function LB:Initialize()
    -- Register for addon messages
    LB:RegisterComm()
    
    -- Create frame (but don't show it yet)
    LB:CreateFrame()
end

-- Export functions for external use
HardcoreDeathraceLeaderboard = LB

