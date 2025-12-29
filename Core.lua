-- Hardcore Deathrace - Core Timer and Darkness Management
-- Timer-based screen darkening addon for hardcore leveling challenge

-- Initialize addon namespace
HardcoreDeathrace = CreateFrame('Frame')

-- Saved variables database
HardcoreDeathraceDB = HardcoreDeathraceDB or {}

-- Time allocation per level (in seconds)
-- Levels 1-5: 10 minutes, 6-10: 20 minutes, 11-15: 45 minutes, 16-20: 60 minutes, 21-30: 120 minutes, 31-40: 240 minutes, 41-50: 360 minutes, 51-60: 480 minutes
local TIME_PER_LEVEL = {
    [1] = 10 * 60,   -- 10 minutes
    [2] = 10 * 60,
    [3] = 10 * 60,
    [4] = 10 * 60,
    [5] = 10 * 60,
    [6] = 20 * 60,   -- 20 minutes
    [7] = 20 * 60,
    [8] = 20 * 60,
    [9] = 20 * 60,
    [10] = 20 * 60,
    [11] = 45 * 60,  -- 45 minutes
    [12] = 45 * 60,
    [13] = 45 * 60,
    [14] = 45 * 60,
    [15] = 45 * 60,
    [16] = 60 * 60,  -- 60 minutes (1 hour)
    [17] = 60 * 60,
    [18] = 60 * 60,
    [19] = 60 * 60,
    [20] = 60 * 60,
    [21] = 120 * 60, -- 120 minutes (2 hours)
    [22] = 120 * 60,
    [23] = 120 * 60,
    [24] = 120 * 60,
    [25] = 120 * 60,
    [26] = 120 * 60,
    [27] = 120 * 60,
    [28] = 120 * 60,
    [29] = 120 * 60,
    [30] = 120 * 60,
    [31] = 240 * 60, -- 240 minutes (4 hours)
    [32] = 240 * 60,
    [33] = 240 * 60,
    [34] = 240 * 60,
    [35] = 240 * 60,
    [36] = 240 * 60,
    [37] = 240 * 60,
    [38] = 240 * 60,
    [39] = 240 * 60,
    [40] = 240 * 60,
    [41] = 360 * 60, -- 360 minutes (6 hours)
    [42] = 360 * 60,
    [43] = 360 * 60,
    [44] = 360 * 60,
    [45] = 360 * 60,
    [46] = 360 * 60,
    [47] = 360 * 60,
    [48] = 360 * 60,
    [49] = 360 * 60,
    [50] = 360 * 60,
    [51] = 480 * 60, -- 480 minutes (8 hours)
    [52] = 480 * 60,
    [53] = 480 * 60,
    [54] = 480 * 60,
    [55] = 480 * 60,
    [56] = 480 * 60,
    [57] = 480 * 60,
    [58] = 480 * 60,
    [59] = 480 * 60,
    [60] = 480 * 60,
}

-- XP tracking table (total XP required to reach each level)
-- Used for anti-cheat protection
local TOTAL_XP_TABLE = {
    [1]=400, [2]=900, [3]=1400, [4]=2100, [5]=2800, [6]=3600, [7]=4500, [8]=5400, [9]=6500, [10] = 7600,
    [11] = 8800, [12] = 10100, [13] = 11400, [14] = 12900, [15] = 14400, [16] = 16000, [17] = 17700, [18] = 19400, [19] = 21300, [20] = 23200,
    [21] = 25200, [22] = 27300, [23] = 29400, [24] = 31700, [25] = 34000, [26] = 36400, [27] = 38900, [28] = 41400, [29] = 44300, [30] = 47400,
    [31] = 50800, [32] = 54500, [33] = 58600, [34] = 62800, [35] = 67100, [36] = 71600, [37] = 76100, [38] = 80800, [39] = 85700, [40] = 90700,
    [41] = 95800, [42] = 101000, [43] = 106300, [44] = 111800, [45] = 117500, [46] = 123200, [47] = 129100, [48] = 135100, [49] = 141200, [50] = 147500,
    [51] = 153900, [52] = 160400, [53] = 167100, [54] = 173900, [55] = 180800, [56] = 187900, [57] = 195000, [58] = 202300, [59] = 209800, [60] = 217400
}

-- Current state variables
local currentLevel = 1
local timeRemainingThisLevel = 0  -- Time remaining for current level (in seconds)
local originalTimeAllocationThisLevel = 0  -- Original time allocation for current level (base + rolled-over, excluding bonuses) - used for darkness percentage calculation
local totalTimePlayed = 0         -- Total time played excluding rested areas (in seconds)
local timeAtLastUpdate = 0        -- Timestamp of last update
local isResting = false           -- Whether player is currently in a rested area
local isOnFlightPath = false      -- Whether player is currently on a flight path
local isPaused = false            -- Whether timer is paused
local hasFailed = false           -- Whether the deathrace has failed
local hasWon = false              -- Whether the deathrace has been won (reached level 60)
local failureLevel = 1            -- Level at which the player failed
local previousDarknessLevel = 0   -- Track previous darkness level for proper overlay management
local trackedTotalXP = 0          -- Total XP tracked while addon is active (anti-cheat)

-- Tunnel vision frames storage (similar to UltraHardcore)
HardcoreDeathrace.tunnelVisionFrames = {}

-- Calculate minimum XP required to reach a level
local function GetMinXPForLevel(level)
    local totalXP = 0
    for i = 1, level - 1 do
        if TOTAL_XP_TABLE[i] then
            totalXP = totalXP + TOTAL_XP_TABLE[i]
        end
    end
    return totalXP
end

-- Calculate total XP from current level and current XP
local function GetCurrentTotalXP()
    local playerLevel = UnitLevel('player')
    local currentXP = UnitXP('player')
    return GetMinXPForLevel(playerLevel) + currentXP
end

-- Check for XP cheating (if current XP > tracked XP, addon was disabled)
local function CheckXPCheat()
    if hasFailed or hasWon then
        return false
    end
    
    local currentTotalXP = GetCurrentTotalXP()
    
    -- If tracked XP is 0, initialize it (first time)
    if trackedTotalXP == 0 then
        trackedTotalXP = currentTotalXP
        return false
    end
    
    -- If current XP is greater than tracked XP, cheating detected
    if currentTotalXP > trackedTotalXP then
        hasFailed = true
        failureLevel = UnitLevel('player')
        -- Clear tunnel vision (no black screen for XP cheat detection)
        RemoveTunnelVision()
        previousDarknessLevel = 0
        -- Don't show failure screen, just update tracker
        SaveCharacterData()
        UpdateStatisticsPanel()
        return true
    end
    
    -- Update tracked XP to current XP (normal progression)
    trackedTotalXP = currentTotalXP
    return false
end

-- Initialize character data
local function InitializeCharacterData()
    local playerName = UnitName('player')
    local realmName = GetRealmName()
    local charKey = playerName .. '-' .. realmName
    
    local playerLevel = UnitLevel('player')
    local currentXP = UnitXP('player')
    
    -- Check if this is a fresh character (level 1, 0 XP earned)
    -- If so, wipe saved variables and start fresh
    if playerLevel == 1 and currentXP == 0 then
        -- Fresh character detected - wipe saved data for this character
        HardcoreDeathraceDB[charKey] = nil
    end
    
    -- Initialize character data if it doesn't exist
    if not HardcoreDeathraceDB[charKey] then
        -- Check if player is loading addon for first time at level > 1
        if playerLevel > 1 then
            -- First-time load at level > 1 - mark as failed (anti-cheat)
            HardcoreDeathraceDB[charKey] = {
                level = playerLevel,
                timeRemainingThisLevel = 0,
                totalTimePlayed = 0,
                lastUpdateTime = time(),
                hasFailed = true,
                hasWon = false,
                failureLevel = playerLevel,
                trackedTotalXP = 0
            }
        else
            -- First-time load at level 1 - start normally
            HardcoreDeathraceDB[charKey] = {
                level = playerLevel,
                timeRemainingThisLevel = 0,
                totalTimePlayed = 0,
                lastUpdateTime = time(),
                hasFailed = false,
                hasWon = false,
                failureLevel = 1,
                trackedTotalXP = 0
            }
        end
    end
    
    -- Load character data
    local charData = HardcoreDeathraceDB[charKey]
    currentLevel = charData.level or playerLevel
    
    -- Load state variables first
    totalTimePlayed = charData.totalTimePlayed or 0
    hasFailed = charData.hasFailed or false
    hasWon = charData.hasWon or false
    failureLevel = charData.failureLevel or currentLevel
    trackedTotalXP = charData.trackedTotalXP or 0
    timeAtLastUpdate = time()
    
    -- Check if this is a first-time load failure (level > 1 on first load)
    -- Detected by: failed, no time played, level > 1, and level matches current (just initialized)
    local isFirstTimeFailure = hasFailed and totalTimePlayed == 0 and playerLevel > 1 and (charData.level == playerLevel)
    
    -- If character leveled up since last save, roll over time
    if charData.level and charData.level < playerLevel then
        -- Player leveled up - roll over unused time
        local previousTimeRemaining = charData.timeRemainingThisLevel or 0
        local newLevelTime = TIME_PER_LEVEL[playerLevel] or TIME_PER_LEVEL[1]
        timeRemainingThisLevel = previousTimeRemaining + newLevelTime
        -- Set original allocation to base + rolled-over time (for darkness percentage calculation)
        originalTimeAllocationThisLevel = previousTimeRemaining + newLevelTime
        currentLevel = playerLevel
    elseif charData.timeRemainingThisLevel and charData.timeRemainingThisLevel > 0 then
        -- Use saved time remaining
        timeRemainingThisLevel = charData.timeRemainingThisLevel
        -- Load original allocation if saved, otherwise calculate it (for backwards compatibility)
        if charData.originalTimeAllocationThisLevel then
            originalTimeAllocationThisLevel = charData.originalTimeAllocationThisLevel
        else
            -- Backwards compatibility: estimate original allocation as base level time
            -- This won't be perfect for old saves with rolled-over time, but it's better than nothing
            originalTimeAllocationThisLevel = TIME_PER_LEVEL[playerLevel] or TIME_PER_LEVEL[1]
        end
    elseif not isFirstTimeFailure then
        -- Starting fresh - allocate time for current level (unless first-time failure)
        local baseTime = TIME_PER_LEVEL[playerLevel] or TIME_PER_LEVEL[1]
        timeRemainingThisLevel = baseTime
        originalTimeAllocationThisLevel = baseTime
        currentLevel = playerLevel
    else
        -- First-time failure - don't allocate time, keep at 0
        timeRemainingThisLevel = 0
        originalTimeAllocationThisLevel = 0
        currentLevel = playerLevel
    end
    
    -- If failed on first-time load at level > 1, don't start timer and don't check XP cheat
    if isFirstTimeFailure then
        -- First-time load failure - don't start timer, just show FAILED in tracker
        isPaused = true
        -- Don't check XP cheat for first-time failures
    else
        -- Check for XP cheating on login (only if not first-time load failure)
        CheckXPCheat()
    end
end

-- Save character data
local function SaveCharacterData()
    local playerName = UnitName('player')
    local realmName = GetRealmName()
    local charKey = playerName .. '-' .. realmName
    
    HardcoreDeathraceDB[charKey] = {
        level = currentLevel,
        timeRemainingThisLevel = timeRemainingThisLevel,
        originalTimeAllocationThisLevel = originalTimeAllocationThisLevel,
        totalTimePlayed = totalTimePlayed,
        lastUpdateTime = timeAtLastUpdate,
        hasFailed = hasFailed,
        hasWon = hasWon,
        failureLevel = failureLevel,
        trackedTotalXP = trackedTotalXP
    }
end

-- Get time allocation for a level
local function GetTimeForLevel(level)
    return TIME_PER_LEVEL[level] or TIME_PER_LEVEL[1]
end

-- Calculate darkness level based on time remaining percentage
-- Darkness starts at 50% time remaining
-- Thresholds: 50% -> level 1, 25% -> level 2, 10% -> level 3, 5% -> level 4
-- Returns 0 (no darkness) to 4 (maximum darkness)
-- Uses originalTimeAllocationThisLevel (base + rolled-over time) for percentage calculation
-- Bonus time from professions/achievements extends timer but doesn't affect thresholds
local function GetDarknessLevel()
    if hasFailed or isResting or isOnFlightPath then
        return 0
    end
    
    -- Use original time allocation (base + rolled-over, excluding bonuses) for percentage calculation
    local timeForLevel = originalTimeAllocationThisLevel
    if timeForLevel == 0 then
        return 0
    end
    
    local timePercent = (timeRemainingThisLevel / timeForLevel) * 100
    
    -- Darkness thresholds: 50%, 25%, 10%, 5%
    if timePercent > 50 then
        return 0
    elseif timePercent > 25 then
        return 1
    elseif timePercent > 10 then
        return 2
    elseif timePercent > 5 then
        return 3
    else
        return 4
    end
end

-- Show tunnel vision overlay (based on UltraHardcore implementation)
-- fadeIn: true to fade in smoothly, false to show instantly
function ShowTunnelVision(blurIntensity, fadeIn)
    if blurIntensity == 0 then
        RemoveTunnelVision()
        return
    end
    
    -- Default to fade in if not specified
    if fadeIn == nil then
        fadeIn = true
    end
    
    local frameName = 'HardcoreDeathraceTunnelVision_' .. blurIntensity
    
    -- Check if frame already exists and is visible
    if HardcoreDeathrace.tunnelVisionFrames[frameName] and HardcoreDeathrace.tunnelVisionFrames[frameName]:IsShown() then
        local existingFrame = HardcoreDeathrace.tunnelVisionFrames[frameName]
        local currentAlpha = existingFrame:GetAlpha() or 0
        -- If it's mid-fade-out, cancel fade-out and fade back in
        if currentAlpha < 1 then
            if UIFrameFadeRemoveFrame then
                UIFrameFadeRemoveFrame(existingFrame)
            end
            if fadeIn then
                UIFrameFadeIn(existingFrame, 0.2, currentAlpha, 1)
            else
                existingFrame:SetAlpha(1)
            end
        end
        return
    end
    
    -- Create the frame if it doesn't exist
    if not HardcoreDeathrace.tunnelVisionFrames[frameName] then
        local tunnelVisionFrame = CreateFrame('Frame', frameName, UIParent)
        tunnelVisionFrame:SetAllPoints(UIParent)
        tunnelVisionFrame:SetFrameStrata('FULLSCREEN_DIALOG')
        -- Use higher frame level for tunnel_vision_5 (complete failure)
        local frameLevel = blurIntensity > 4 and 2000 or (1000 + blurIntensity)
        tunnelVisionFrame:SetFrameLevel(frameLevel)
        
        tunnelVisionFrame.texture = tunnelVisionFrame:CreateTexture(nil, 'BACKGROUND')
        tunnelVisionFrame.texture:SetAllPoints()
        tunnelVisionFrame.texture:SetColorTexture(0, 0, 0, 0)
        
        HardcoreDeathrace.tunnelVisionFrames[frameName] = tunnelVisionFrame
    end
    
    local frame = HardcoreDeathrace.tunnelVisionFrames[frameName]
    
    -- For tunnel_vision_5, use solid black color texture (guaranteed to work)
    if blurIntensity == 5 then
        frame.texture:SetColorTexture(0, 0, 0, 1) -- Solid black
    else
        -- For other levels, load PNG texture
        local texturePath = 'Interface\\AddOns\\Hardcore Deathrace\\Textures\\tunnel_vision_' .. blurIntensity .. '.png'
        frame.texture:SetTexture(texturePath)
    end
    
    frame:Show()
    
    if fadeIn then
        -- Smooth fade in
        frame:SetAlpha(0)
        local fadeDuration = 0.5
        UIFrameFadeIn(frame, fadeDuration, 0, 1)
    else
        -- Show instantly
        frame:SetAlpha(1)
    end
end

-- Remove specific tunnel vision overlay
function RemoveSpecificTunnelVision(blurIntensity)
    local frameName = 'HardcoreDeathraceTunnelVision_' .. blurIntensity
    
    if HardcoreDeathrace.tunnelVisionFrames and HardcoreDeathrace.tunnelVisionFrames[frameName] then
        local frame = HardcoreDeathrace.tunnelVisionFrames[frameName]
        if frame and frame:IsShown() and frame:GetAlpha() > 0 then
            local fadeDuration = 0.5
            UIFrameFadeOut(frame, fadeDuration, frame:GetAlpha(), 0)
            C_Timer.After(fadeDuration + 0.1, function()
                if frame:GetAlpha() == 0 then
                    frame:Hide()
                end
            end)
        end
    end
end

-- Remove all tunnel vision overlays
function RemoveTunnelVision()
    local fadeDuration = 0.5
    
    if HardcoreDeathrace.tunnelVisionFrames then
        for frameName, frame in pairs(HardcoreDeathrace.tunnelVisionFrames) do
            if frame and frame:IsShown() and frame:GetAlpha() > 0 then
                UIFrameFadeOut(frame, fadeDuration, frame:GetAlpha(), 0)
                C_Timer.After(fadeDuration + 0.1, function()
                    if frame:GetAlpha() == 0 then
                        frame:Hide()
                    end
                end)
            end
        end
    end
end

-- Update darkness overlay based on current time remaining
-- Textures replace each other sequentially (1 -> 2 -> 3 -> 4), not stack
-- instant: true to show instantly (on login/reload), false to fade in (timer updates)
local function UpdateDarkness(instant)
    if hasFailed then
        RemoveTunnelVision()
        previousDarknessLevel = 0
        return
    end
    
    local darknessLevel = GetDarknessLevel()
    
    -- If darkness level changed, replace the texture with smooth cross-fade
    if darknessLevel ~= previousDarknessLevel then
        local fadeDuration = 0.5
        
        -- If we have a previous overlay, fade it out while fading in the new one
        if previousDarknessLevel > 0 then
            local oldFrameName = 'HardcoreDeathraceTunnelVision_' .. previousDarknessLevel
            if HardcoreDeathrace.tunnelVisionFrames[oldFrameName] then
                local oldFrame = HardcoreDeathrace.tunnelVisionFrames[oldFrameName]
                if oldFrame and oldFrame:IsShown() and oldFrame:GetAlpha() > 0 then
                    -- Fade out the old overlay
                    UIFrameFadeOut(oldFrame, fadeDuration, oldFrame:GetAlpha(), 0)
                    C_Timer.After(fadeDuration + 0.1, function()
                        if oldFrame:GetAlpha() == 0 then
                            oldFrame:Hide()
                        end
                    end)
                end
            end
        end
        
        -- Show the new overlay (fade in if not instant)
        if darknessLevel > 0 then
            ShowTunnelVision(darknessLevel, not instant)
        end
        
        -- Update previous darkness level for next comparison
        previousDarknessLevel = darknessLevel
    end
end

-- Forward declaration for AnnounceFailure (defined later after FormatPlayedTime)
local AnnounceFailure

-- Handle player death - pause timer and fail the run
local function OnPlayerDeath()
    -- Only process death if not already failed or won
    if hasFailed or hasWon then
        return
    end
    
    -- Pause the timer immediately
    isPaused = true
    
    -- Mark as failed
    hasFailed = true
    failureLevel = currentLevel -- Save the level at which they died
    
    -- Save the current time played up to this point
    -- Calculate any remaining time that should be added to totalTimePlayed
    local currentTime = time()
    local deltaTime = currentTime - timeAtLastUpdate
    
    -- Only add time if not resting and not on flight path (same logic as UpdateTimer)
    if not isResting and not isOnFlightPath and deltaTime > 0 then
        -- Add the time that passed since last update to totalTimePlayed
        if timeRemainingThisLevel - deltaTime > 0 then
            -- Time remaining would still be positive, so add the deltaTime to totalTimePlayed
            totalTimePlayed = totalTimePlayed + deltaTime
            timeRemainingThisLevel = timeRemainingThisLevel - deltaTime
        else
            -- Time would have run out anyway, add remaining time
            local remainingTime = timeRemainingThisLevel
            totalTimePlayed = totalTimePlayed + remainingTime
            timeRemainingThisLevel = 0
        end
        timeAtLastUpdate = currentTime
    end
    
    -- Save character data
    SaveCharacterData()
    
    -- Announce failure
    AnnounceFailure()
    
    -- Show tunnel_vision_5.png (all black) when player dies
    RemoveTunnelVision()
    ShowTunnelVision(5, false) -- Show instantly, no fade
    
    -- Show failure screen
    ShowFailureScreen()
    
    -- Update UI to show FAILED
    UpdateStatisticsPanel()
end

-- Update timer and check for failure
local function UpdateTimer()
    if hasFailed or hasWon or isPaused then
        return
    end
    
    -- Check if player is dead (backup check in case UNIT_DIED event doesn't fire)
    if UnitIsDead and UnitIsDead("player") then
        OnPlayerDeath()
        return
    end
    
    -- Check if player is on a flight path (check every update)
    local wasOnFlightPath = isOnFlightPath
    isOnFlightPath = UnitOnTaxi and UnitOnTaxi("player") or false
    
    -- If flight path status changed, update darkness overlay
    if isOnFlightPath ~= wasOnFlightPath then
        if isOnFlightPath then
            -- Just boarded flight path - remove darkness
            RemoveTunnelVision()
            previousDarknessLevel = 0
        else
            -- Just disembarked flight path - restore darkness if needed
            UpdateDarkness(false)
        end
        -- Update UI to reflect status change
        UpdateStatisticsPanel()
    end
    
    local currentTime = time()
    local deltaTime = currentTime - timeAtLastUpdate
    
    -- Only count time if not resting and not on flight path
    if not isResting and not isOnFlightPath then
        -- Check for failure BEFORE updating (to capture correct score)
        if timeRemainingThisLevel - deltaTime <= 0 then
            -- Timer ran out - add remaining time to totalTimePlayed before failing
            -- This ensures the score includes the full time survived
            local remainingTime = timeRemainingThisLevel
            totalTimePlayed = totalTimePlayed + remainingTime
            
            -- Set to exactly 0 and mark as failed
            timeRemainingThisLevel = 0
            hasFailed = true
            failureLevel = currentLevel -- Save the level at which they failed
            SaveCharacterData()
            -- Announce failure
            AnnounceFailure()
            -- Show tunnel_vision_5.png (all black) when timer runs out
            RemoveTunnelVision()
            ShowTunnelVision(5, false) -- Show instantly, no fade
            ShowFailureScreen()
            UpdateStatisticsPanel() -- Update UI to show FAILED
            return
        end
        
        -- Update time remaining (only if not failed)
        timeRemainingThisLevel = timeRemainingThisLevel - deltaTime
        
        -- Update total time played
        totalTimePlayed = totalTimePlayed + deltaTime
    end
    
    timeAtLastUpdate = currentTime
    
    -- Update darkness overlay
    UpdateDarkness()
    
    -- Update UI
    UpdateStatisticsPanel()
    
    -- Save data periodically
    SaveCharacterData()
end

-- Forward declaration for AnnounceLevelUp (defined later after FormatPlayedTime)
local AnnounceLevelUp

-- Handle level up
local function OnLevelUp(newLevel)
    if hasFailed or hasWon then
        return
    end
    
    -- Update tracked XP on level up (XP resets to 0, so add XP for the new level)
    local currentTotalXP = GetCurrentTotalXP()
    if currentTotalXP >= trackedTotalXP then
        trackedTotalXP = currentTotalXP
    end
    
    -- Ensure we have the most up-to-date time remaining by updating timer one last time
    -- This accounts for any time that passed since the last UpdateTimer call
    if not isPaused and not isResting then
        local currentTime = time()
        local deltaTime = currentTime - timeAtLastUpdate
        if deltaTime > 0 and timeRemainingThisLevel > 0 then
            -- Only update if we have time remaining and time has passed
            if timeRemainingThisLevel - deltaTime > 0 then
                timeRemainingThisLevel = timeRemainingThisLevel - deltaTime
                totalTimePlayed = totalTimePlayed + deltaTime
            else
                -- Time would have run out, but we're leveling up so set to 0
                timeRemainingThisLevel = 0
            end
            timeAtLastUpdate = currentTime
        end
    end
    
    -- Check if player reached level 60 (win condition)
    if newLevel >= 60 then
        hasWon = true
        currentLevel = 60
        SaveCharacterData()
        -- Clear tunnel vision on win
        RemoveTunnelVision()
        previousDarknessLevel = 0
        ShowWinScreen()
        UpdateStatisticsPanel()
        return
    end
    
    -- Roll over unused time (timeRemainingThisLevel now has the accurate leftover time)
    local previousTimeRemaining = timeRemainingThisLevel
    local newLevelTime = GetTimeForLevel(newLevel)
    
    currentLevel = newLevel
    timeRemainingThisLevel = previousTimeRemaining + newLevelTime
    -- Set original allocation to base + rolled-over time (for darkness percentage calculation)
    -- This excludes any bonus time that may have been added from professions/achievements
    originalTimeAllocationThisLevel = previousTimeRemaining + newLevelTime
    
    -- Remove darkness on level up
    RemoveTunnelVision()
    previousDarknessLevel = 0
    
    -- Announce level up
    AnnounceLevelUp(newLevel)
    
    SaveCharacterData()
    UpdateStatisticsPanel()
end

-- Format time as MM:SS or HH:MM:SS
local function FormatTime(seconds)
    if seconds < 0 then
        seconds = 0
    end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%d:%02d", minutes, secs)
    end
end

-- Format time in /played format: "X days, Y mins, Z secs"
-- When days > 0, only show "X days, Y mins" to save space
-- When days = 0, always show mins and secs (even if secs is 0)
local function FormatPlayedTime(seconds)
    if seconds < 0 then
        seconds = 0
    end
    
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    local parts = {}
    
    -- If days > 0, only show days and minutes (hide hours and seconds)
    if days > 0 then
        table.insert(parts, string.format("%d day%s", days, days == 1 and "" or "s"))
        if minutes > 0 then
            table.insert(parts, string.format("%d min%s", minutes, minutes == 1 and "" or "s"))
        end
    else
        -- No days, show hours (if > 0), minutes, and seconds
        -- If hours > 0, hide seconds and only show hours and minutes
        if hours > 0 then
            table.insert(parts, string.format("%d hour%s", hours, hours == 1 and "" or "s"))
            if minutes > 0 then
                table.insert(parts, string.format("%d min%s", minutes, minutes == 1 and "" or "s"))
            end
            -- Don't show seconds when hours are present
        else
            -- No hours, show minutes and seconds
            if minutes > 0 then
                table.insert(parts, string.format("%d min%s", minutes, minutes == 1 and "" or "s"))
            end
            -- Always show seconds when no hours (even if 0)
            table.insert(parts, string.format("%d sec%s", secs, secs == 1 and "" or "s"))
        end
    end
    
    return table.concat(parts, ", ")
end

-- Format time in full /played format: "X days, Y hours, Z mins, W secs" (always show all units)
local function FormatPlayedTimeFull(seconds)
    if seconds < 0 then
        seconds = 0
    end
    
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    local parts = {}
    
    -- Always show all units for full format
    table.insert(parts, string.format("%d day%s", days, days == 1 and "" or "s"))
    table.insert(parts, string.format("%d hour%s", hours, hours == 1 and "" or "s"))
    table.insert(parts, string.format("%d min%s", minutes, minutes == 1 and "" or "s"))
    table.insert(parts, string.format("%d sec%s", secs, secs == 1 and "" or "s"))
    
    return table.concat(parts, ", ")
end

-- Announce failure to guild/party or say chat (assign to forward-declared variable)
AnnounceFailure = function()
    -- Format time played in full format
    local timeText = FormatPlayedTimeFull(totalTimePlayed)
    
    -- Build message
    local message = string.format("I have just failed my Hardcore Deathrace run at level %d after %s.", 
                                   failureLevel, timeText)
    
    -- Check if in guild or party (Classic Era compatible)
    local inGuild = IsInGuild()
    local numGroupMembers = GetNumGroupMembers and GetNumGroupMembers() or 1
    local inRaid = IsInRaid and IsInRaid() or false
    local inParty = not inRaid and numGroupMembers > 1
    
    -- Send to appropriate channel (priority: raid > party > guild > say)
    if inRaid then
        local success = pcall(function()
            SendChatMessage(message, "RAID")
        end)
        if not success then
            ChatFrame1:AddMessage("|cFFFF0000[Hardcore Deathrace]|r " .. message)
        end
    elseif inParty then
        local success = pcall(function()
            SendChatMessage(message, "PARTY")
        end)
        if not success then
            ChatFrame1:AddMessage("|cFFFF0000[Hardcore Deathrace]|r " .. message)
        end
    elseif inGuild then
        local success = pcall(function()
            SendChatMessage(message, "GUILD")
        end)
        if not success then
            ChatFrame1:AddMessage("|cFFFF0000[Hardcore Deathrace]|r " .. message)
        end
    else
        -- For say channel, use AddMessage to avoid protected function issues
        ChatFrame1:AddMessage("|cFFFF0000[Hardcore Deathrace]|r " .. message)
    end
end

-- Announce level up to guild/party or say chat (assign to forward-declared variable)
AnnounceLevelUp = function(level)
    -- Calculate next level and time remaining
    local nextLevel = level + 1
    local timeRemainingText = FormatPlayedTime(timeRemainingThisLevel)
    
    -- Build message (removed score, kept next level info)
    local message = string.format("I just hit level %d using the Hardcore Deathrace addon. I have %s to hit level %d before I fail the run.", 
                                   level, timeRemainingText, nextLevel)
    
    -- Check if in guild or party (Classic Era compatible)
    local inGuild = IsInGuild()
    -- In Classic Era, use GetNumGroupMembers() which returns party+self count
    -- If > 1, player is in a group (party or raid)
    local numGroupMembers = GetNumGroupMembers and GetNumGroupMembers() or 1
    -- Check if in raid first (Classic Era)
    local inRaid = IsInRaid and IsInRaid() or false
    -- If not in raid but have more than 1 group member, we're in a party
    local inParty = not inRaid and numGroupMembers > 1
    
    -- Check if level is a multiple of 10 (for guild announcements)
    local isMilestoneLevel = (level % 10 == 0)
    
    -- Send to appropriate channel
    -- Party: every level
    -- Guild: only at levels 10, 20, 30, 40, 50, 60
    -- Raid and Say: disabled
    
    if inParty then
        -- Announce to party every level
        local success = pcall(function()
            SendChatMessage(message, "PARTY")
        end)
        if not success then
            -- Fallback to chat frame if SendChatMessage fails
            ChatFrame1:AddMessage("|cFF00FF00[Hardcore Deathrace]|r " .. message)
        end
    end
    
    -- Guild announcement only at milestone levels (10, 20, 30, etc.)
    if inGuild and isMilestoneLevel then
        local success = pcall(function()
            SendChatMessage(message, "GUILD")
        end)
        if not success then
            -- Fallback to chat frame if SendChatMessage fails
            ChatFrame1:AddMessage("|cFF00FF00[Hardcore Deathrace]|r " .. message)
        end
    end
end

-- Integration with HardcoreAchievements addon
-- Hook into achievement completion to add time bonus
local function SetupAchievementIntegration()
    -- Check if HardcoreAchievements addon is loaded
    if not _G.HCA_MarkRowCompleted then
        return false
    end
    
    -- Save the original function
    local originalMarkRowCompleted = _G.HCA_MarkRowCompleted
    
    -- Wrap the function to detect achievement completion
    _G.HCA_MarkRowCompleted = function(row, ...)
        -- Call the original function first
        local result = originalMarkRowCompleted(row, ...)
        
        -- Only add time if not failed/won and HardcoreAchievements is available
        if not hasFailed and not hasWon and HardcoreAchievements then
            -- Add 1 hour (3600 seconds) to failure timer when achievement is completed
            timeRemainingThisLevel = timeRemainingThisLevel + 3600
            
            -- Update UI to reflect the bonus time
            UpdateStatisticsPanel()
            
            -- Save the updated time
            SaveCharacterData()
        end
        
        return result
    end
    
    return true
end

--/*******************/ PARTY JOIN ANNOUNCEMENT SYSTEM /*************************/--
-- System to announce Hardcore Deathrace addon usage when joining or when others join party

-- Track group members to detect when new members join
local currentGroupMembers = {}
local previousGroupMembers = {}
local previousGroupCount = 0
local groupInitialized = false
local groupMessageTimerFrame = CreateFrame("Frame")
local groupMessageTimerElapsed = 0
local lastMessageTime = 0
local MESSAGE_COOLDOWN = 3.0 -- Minimum seconds between messages to prevent spam

-- Function to get current group member names
local function GetCurrentGroupMembers()
    local members = {}
    if IsInRaid and IsInRaid() then
        -- In raid, use GetNumGroupMembers() and GetRaidRosterInfo()
        local numMembers = GetNumGroupMembers()
        for i = 1, numMembers do
            local name = GetRaidRosterInfo(i)
            if name then
                members[name] = true
            end
        end
    elseif IsInGroup and IsInGroup() then
        -- In party, use GetNumGroupMembers() and UnitName("party" .. i)
        local numMembers = GetNumGroupMembers()
        for i = 1, numMembers do
            local name = UnitName("party" .. i)
            if name then
                members[name] = true
            end
        end
    end
    -- Always include player name
    local playerName = UnitName("player")
    if playerName then
        members[playerName] = true
    end
    return members
end

-- Helper function to actually send the Hardcore Deathrace warning message
-- Only sends when party is full (5 members including the player)
local function SendDeathraceMessageNow()
    local currentTime = GetTime()
    
    -- Check cooldown to prevent spam
    if currentTime - lastMessageTime >= MESSAGE_COOLDOWN then
        -- Reset timer and start counting
        groupMessageTimerElapsed = 0
        groupMessageTimerFrame:SetScript("OnUpdate", function(self, delta)
            groupMessageTimerElapsed = groupMessageTimerElapsed + delta
            
            -- Wait 1 second before sending to ensure group is fully formed
            if groupMessageTimerElapsed >= 1.0 then
                -- Stop the timer
                self:SetScript("OnUpdate", nil)
                groupMessageTimerElapsed = 0
                
                -- Double-check we're still in a party (not raid) and party is full
                local stillInGroup = IsInGroup and IsInGroup()
                local stillInRaid = IsInRaid and IsInRaid()
                
                -- Only send if in a party (not raid) and party is full (5 members)
                if stillInGroup and not stillInRaid then
                    local partySize = GetNumGroupMembers and GetNumGroupMembers() or 1
                    
                    -- Only send message when party is full (5 members including player)
                    if partySize == 5 then
                        -- Message to send to party chat
                        local message = "Warning: I am using the Hardcore Deathrace addon and will be pushing the pace to survive."
                        
                        local success = pcall(function()
                            SendChatMessage(message, "PARTY")
                        end)
                        if not success then
                            -- Fallback to chat frame if SendChatMessage fails
                            ChatFrame1:AddMessage("|cFFFF0000[Hardcore Deathrace]|r " .. message)
                        end
                        
                        -- Update last message time
                        lastMessageTime = GetTime()
                    end
                end
            end
        end)
    end
end

-- Function to send Hardcore Deathrace warning message to party chat
-- Only sends when party is full (5 members including the player)
local function SendGroupDeathraceMessage()
    -- Check if we're in a party (not raid) using Classic WoW API
    local inGroup = IsInGroup and IsInGroup()
    local inRaid = IsInRaid and IsInRaid()
    
    -- Only process if we're in a party (not raid)
    if inGroup and not inRaid then
        -- Skip if not initialized yet (prevents false triggers on addon load)
        if not groupInitialized then
            previousGroupMembers = GetCurrentGroupMembers()
            previousGroupCount = GetNumGroupMembers and GetNumGroupMembers() or 1
            groupInitialized = true
            return
        end
        
        -- Get current group state
        local currentMembers = GetCurrentGroupMembers()
        local currentGroupCount = GetNumGroupMembers and GetNumGroupMembers() or 1
        
        -- Only check for new members if the group count has increased
        -- This prevents sending messages when someone levels up or leaves
        if currentGroupCount > previousGroupCount then
            -- Group count increased, someone actually joined
            local playerName = UnitName("player")
            local hasNewMember = false
            
            -- Check if there are new members (excluding ourselves)
            for name, _ in pairs(currentMembers) do
                if not previousGroupMembers[name] and name ~= playerName then
                    hasNewMember = true
                    break
                end
            end
            
            -- Only send message if there's a new member AND party is full (5 members)
            if hasNewMember and currentGroupCount == 5 then
                SendDeathraceMessageNow()
            end
            
            -- Update tracking when someone joins
            previousGroupMembers = currentMembers
            previousGroupCount = currentGroupCount
        elseif currentGroupCount < previousGroupCount then
            -- Group count decreased, someone left - update tracking but don't send message
            previousGroupMembers = GetCurrentGroupMembers()
            previousGroupCount = currentGroupCount
        else
            -- Group count unchanged, just update member list in case of name changes
            previousGroupMembers = currentMembers
        end
    else
        -- Not in a party anymore (or in raid), reset tracking
        previousGroupMembers = {}
        currentGroupMembers = {}
        previousGroupCount = 0
        groupInitialized = false
        
        -- Stop any pending timer
        groupMessageTimerFrame:SetScript("OnUpdate", nil)
        groupMessageTimerElapsed = 0
    end
end

-- Register events
HardcoreDeathrace:RegisterEvent('ADDON_LOADED')
HardcoreDeathrace:RegisterEvent('PLAYER_LOGIN')
HardcoreDeathrace:RegisterEvent('PLAYER_LEVEL_UP')
HardcoreDeathrace:RegisterEvent('PLAYER_UPDATE_RESTING')
HardcoreDeathrace:RegisterEvent('PLAYER_LOGOUT')
HardcoreDeathrace:RegisterEvent('PLAYER_ENTERING_WORLD')
HardcoreDeathrace:RegisterEvent('PLAYER_XP_UPDATE') -- Track XP changes for anti-cheat
HardcoreDeathrace:RegisterEvent('CHAT_MSG_SKILL') -- Detect profession skill level ups
HardcoreDeathrace:RegisterEvent('PLAYER_CONTROL_GAINED') -- Detect when flight path ends (player regains control)
HardcoreDeathrace:RegisterEvent('GROUP_JOINED') -- Detect when player joins a party/raid
HardcoreDeathrace:RegisterEvent('GROUP_ROSTER_UPDATE') -- Detect when party/raid roster changes
HardcoreDeathrace:RegisterEvent('PLAYER_DEAD') -- Detect when player dies

-- Event handler
HardcoreDeathrace:SetScript('OnEvent', function(self, event, ...)
    if event == 'ADDON_LOADED' then
        local addonName = ...
        if addonName == 'Hardcore Deathrace' then
            -- Addon loaded, wait for PLAYER_LOGIN
        elseif addonName == 'HardcoreAchievements' then
            -- HardcoreAchievements addon loaded, set up integration
            C_Timer.After(1, function()
                SetupAchievementIntegration()
            end)
        end
    elseif event == 'PLAYER_LOGIN' then
        InitializeCharacterData()
        -- Check if player is resting on login
        isResting = IsResting()
        -- Check if player is on a flight path on login
        isOnFlightPath = UnitOnTaxi and UnitOnTaxi("player") or false
        
        if isResting or isOnFlightPath then
            RemoveTunnelVision()
            previousDarknessLevel = 0
        else
            -- Apply darkness instantly on login (no fade)
            UpdateDarkness(true)
        end
        InitializeUI()
        -- Update UI immediately with loaded data
        UpdateStatisticsPanel()
        -- Set up HardcoreAchievements integration if available
        C_Timer.After(2, function()
            SetupAchievementIntegration()
        end)
        -- Start update timer (update every second)
        C_Timer.NewTicker(1, UpdateTimer)
    elseif event == 'PLAYER_LEVEL_UP' then
        local newLevel = ...
        OnLevelUp(newLevel)
    elseif event == 'PLAYER_UPDATE_RESTING' then
        local wasResting = isResting
        isResting = IsResting()
        
        -- If just entered rested area, remove darkness
        if isResting and not wasResting then
            RemoveTunnelVision()
            previousDarknessLevel = 0
        end
        
        -- Update UI
        UpdateStatisticsPanel()
    elseif event == 'PLAYER_LOGOUT' then
        SaveCharacterData()
    elseif event == 'PLAYER_ENTERING_WORLD' then
        -- Check if player is resting when entering world (handles zoning/reload)
        isResting = IsResting()
        -- Check if player is on a flight path when entering world
        isOnFlightPath = UnitOnTaxi and UnitOnTaxi("player") or false
        
        if isResting or isOnFlightPath then
            RemoveTunnelVision()
            previousDarknessLevel = 0
        else
            -- Apply darkness instantly on reload/zone (no fade)
            UpdateDarkness(true)
        end
        -- Reinitialize when entering world (handles zoning)
        if not isPaused then
            timeAtLastUpdate = time()
        end
        -- Check for XP cheating when entering world
        CheckXPCheat()
        -- Update UI to reflect flight path status
        UpdateStatisticsPanel()
    elseif event == 'PLAYER_XP_UPDATE' then
        -- Track XP changes and check for cheating
        if not hasFailed and not hasWon then
            local currentTotalXP = GetCurrentTotalXP()
            -- Update tracked XP if it's normal progression
            if currentTotalXP >= trackedTotalXP then
                trackedTotalXP = currentTotalXP
                SaveCharacterData()
            else
                -- XP went down (shouldn't happen normally, but check anyway)
                CheckXPCheat()
            end
        end
    elseif event == 'CHAT_MSG_SKILL' then
        -- Detect profession skill level ups (only actual professions, not weapon/defense skills)
        if not hasFailed and not hasWon then
            local message = ...
            
            -- List of Classic Era professions (including secondary professions)
            local professions = {
                "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism",
                "Leatherworking", "Mining", "Skinning", "Tailoring",
                "Cooking", "Fishing", "First Aid"
            }
            
            -- Parse "Your skill in [SkillName] has increased to [X]." format
            local skillName, skillLevel = message:match("Your skill in (.+) has increased to (%d+)")
            
            -- Check if the skill name matches a profession
            local isProfession = false
            if skillName then
                -- Normalize skill name (remove trailing period and whitespace)
                skillName = skillName:gsub("%.", ""):gsub("^%s+", ""):gsub("%s+$", "")
                
                -- Check against profession list (case-insensitive)
                for _, profName in ipairs(professions) do
                    if skillName:lower() == profName:lower() then
                        isProfession = true
                        break
                    end
                end
            end
            
            -- Only add time if it's a profession skill increase (not weapon/defense)
            if isProfession and skillLevel then
                -- Profession skill leveled up - add 1 minute (60 seconds) to failure timer
                timeRemainingThisLevel = timeRemainingThisLevel + 60
                
                -- Update UI to reflect the bonus time
                UpdateStatisticsPanel()
                
                -- Save the updated time
                SaveCharacterData()
            end
        end
    elseif event == 'PLAYER_CONTROL_GAINED' then
        -- Player regained control (flight path ended, or other control loss ended)
        -- Check if we were on a flight path and update status accordingly
        -- This event fires when the flight path ends (player lands)
        local wasOnFlightPath = isOnFlightPath
        isOnFlightPath = UnitOnTaxi and UnitOnTaxi("player") or false
        
        -- If we just landed from a flight path, restore darkness overlay
        if wasOnFlightPath and not isOnFlightPath then
            -- Just disembarked flight path - restore darkness if needed
            UpdateDarkness(false)
            -- Update UI to reflect status change
            UpdateStatisticsPanel()
        end
    elseif event == 'GROUP_JOINED' then
        -- Initialize group tracking when first joining a group
        previousGroupMembers = GetCurrentGroupMembers()
        previousGroupCount = GetNumGroupMembers and GetNumGroupMembers() or 1
        groupInitialized = true
        
        -- Only send message if in a party (not raid) and party is full (5 members)
        local inGroup = IsInGroup and IsInGroup()
        local inRaid = IsInRaid and IsInRaid()
        
        if inGroup and not inRaid then
            local numMembers = GetNumGroupMembers and GetNumGroupMembers() or 1
            
            -- Only send Hardcore Deathrace warning message when party is full (5 members)
            if numMembers == 5 then
                SendDeathraceMessageNow()
            end
        end
    elseif event == 'GROUP_ROSTER_UPDATE' then
        -- Send Hardcore Deathrace warning message when group roster updates (someone joins/leaves)
        SendGroupDeathraceMessage()
    elseif event == 'PLAYER_DEAD' then
        -- Player died - pause timer and fail the run
        OnPlayerDeath()
    end
end)

-- Export functions for UI
HardcoreDeathrace.GetCurrentLevel = function() return currentLevel end
HardcoreDeathrace.GetTimeRemaining = function() return timeRemainingThisLevel end
HardcoreDeathrace.GetTotalTimePlayed = function() return totalTimePlayed end
HardcoreDeathrace.IsResting = function() return isResting end
HardcoreDeathrace.IsOnFlightPath = function() return isOnFlightPath end
HardcoreDeathrace.HasFailed = function() return hasFailed end
HardcoreDeathrace.HasWon = function() return hasWon end
HardcoreDeathrace.GetFailureLevel = function() return failureLevel end
HardcoreDeathrace.FormatTime = FormatTime
HardcoreDeathrace.FormatPlayedTime = FormatPlayedTime
HardcoreDeathrace.FormatPlayedTimeFull = FormatPlayedTimeFull
HardcoreDeathrace.GetTimeForLevel = function(level) return TIME_PER_LEVEL[level] or TIME_PER_LEVEL[1] end
HardcoreDeathrace.GetOriginalTimeAllocation = function() return originalTimeAllocationThisLevel end


