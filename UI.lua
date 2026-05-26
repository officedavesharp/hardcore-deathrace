-- Hardcore Deathrace - UI Elements (Statistics Panel, Failure Screen, Welcome Screen)

-- Statistics Panel Frame
local statsFrame = nil
local failureFrame = nil
local welcomeFrame = nil  -- Welcome / Start Race modal shown before the race begins

-- Initialize global settings if needed
HardcoreDeathraceDB = HardcoreDeathraceDB or {}
HardcoreDeathraceDB.settings = HardcoreDeathraceDB.settings or {}

-- UI Scaling Configuration
-- Calculate font/ spacing scale to ensure text fits properly at all resolutions
-- Box size stays fixed, only fonts and spacing scale
local function GetFontScale()
    -- Get current screen resolution
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    
    -- Reference resolution: 1920x1080 (where the UI was designed and text overflow was reported)
    -- At this resolution, scale should be 1.0 (no scaling)
    local REFERENCE_WIDTH = 1920
    local REFERENCE_HEIGHT = 1080
    
    -- Calculate scale based on both width and height
    -- Use the smaller scale to ensure text fits both horizontally and vertically
    -- This prevents overflow in both dimensions
    local scaleX = screenWidth / REFERENCE_WIDTH
    local scaleY = screenHeight / REFERENCE_HEIGHT
    local scale = math.min(scaleX, scaleY)
    
    -- Apply more aggressive scaling at lower resolutions
    -- Use a slightly more aggressive curve to ensure fonts scale down enough
    -- This helps prevent text overflow at very low resolutions
    if scale < 1.0 then
        -- At lower resolutions, apply additional scaling factor to be more aggressive
        -- This ensures fonts scale down enough to prevent overflow
        scale = scale * 0.95  -- Additional 5% reduction for safety margin
    end
    
    -- Clamp scale to ensure fonts scale DOWN at lower resolutions
    -- Minimum 0.55 ensures fonts scale down enough at very low resolutions (e.g., 720p, 800x600)
    -- Maximum 1.0 ensures fonts never exceed original size (prevents overflow)
    -- Lowered minimum from 0.65 to 0.55 to be more aggressive at preventing overflow
    scale = math.max(0.55, math.min(1.0, scale))
    
    return scale
end

-- Initialize UI elements
function InitializeUI()
    CreateStatisticsPanel()
    CreateFailureScreen()
end

-- Create statistics panel
function CreateStatisticsPanel()
    -- Get font/spacing scale factor for current resolution
    -- Box size stays fixed, only fonts and spacing scale
    local fontScale = GetFontScale()
    
    -- Create main frame
    statsFrame = CreateFrame('Frame', 'HardcoreDeathraceStatsFrame', UIParent)
    -- Reduced width from 250 to 230 to account for shorter "Failure:" text (was "Failure Timer:")
    -- Height reduced from 132 to 112 since Score row is hidden (shown on failure screen only)
    statsFrame:SetSize(230, 112)
    
    -- Load saved position or use default
    -- Ensure settings table exists
    if not HardcoreDeathraceDB then
        HardcoreDeathraceDB = {}
    end
    if not HardcoreDeathraceDB.settings then
        HardcoreDeathraceDB.settings = {}
    end
    
    local settings = HardcoreDeathraceDB.settings
    if settings.statsFramePoint and settings.statsFrameRelativePoint and 
       settings.statsFrameX and settings.statsFrameY then
        -- Use saved position (always relative to UIParent)
        -- Saved positions are in original coordinates, use as-is
        statsFrame:SetPoint(settings.statsFramePoint, UIParent, settings.statsFrameRelativePoint, 
                           settings.statsFrameX, settings.statsFrameY)
    else
        -- Use default position (original offsets: -40, 80)
        statsFrame:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', -40, 80)
    end
    
    -- Ensure panel stays above darkness overlays (darkness uses FULLSCREEN_DIALOG with level 1000+)
    statsFrame:SetFrameStrata('FULLSCREEN_DIALOG')
    statsFrame:SetFrameLevel(2000) -- Higher than darkness overlays (max darkness is level 1004)
    
    -- Create background texture (Classic Era compatible) - solid dark background
    local bg = statsFrame:CreateTexture(nil, 'BACKGROUND')
    bg:SetColorTexture(0, 0, 0, 0.85) -- Dark semi-transparent background
    bg:SetAllPoints(statsFrame)
    statsFrame.bg = bg
    
    -- Create simple border using solid color lines (Classic Era compatible)
    -- Keep border size fixed (base size: 2) - don't scale borders
    local borderSize = 2
    local borderColor = {0.6, 0.6, 0.6, 1} -- Light gray border
    
    -- Top border line
    local topBorder = statsFrame:CreateTexture(nil, 'BORDER')
    topBorder:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    topBorder:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 0, 0)
    topBorder:SetPoint('TOPRIGHT', statsFrame, 'TOPRIGHT', 0, 0)
    topBorder:SetHeight(borderSize)
    
    -- Bottom border line
    local bottomBorder = statsFrame:CreateTexture(nil, 'BORDER')
    bottomBorder:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    bottomBorder:SetPoint('BOTTOMLEFT', statsFrame, 'BOTTOMLEFT', 0, 0)
    bottomBorder:SetPoint('BOTTOMRIGHT', statsFrame, 'BOTTOMRIGHT', 0, 0)
    bottomBorder:SetHeight(borderSize)
    
    -- Left border line
    local leftBorder = statsFrame:CreateTexture(nil, 'BORDER')
    leftBorder:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    leftBorder:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 0, 0)
    leftBorder:SetPoint('BOTTOMLEFT', statsFrame, 'BOTTOMLEFT', 0, 0)
    leftBorder:SetWidth(borderSize)
    
    -- Right border line
    local rightBorder = statsFrame:CreateTexture(nil, 'BORDER')
    rightBorder:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    rightBorder:SetPoint('TOPRIGHT', statsFrame, 'TOPRIGHT', 0, 0)
    rightBorder:SetPoint('BOTTOMRIGHT', statsFrame, 'BOTTOMRIGHT', 0, 0)
    rightBorder:SetWidth(borderSize)
    
    statsFrame:SetMovable(true)
    statsFrame:EnableMouse(true)
    statsFrame:RegisterForDrag('LeftButton')
    statsFrame:SetScript('OnDragStart', statsFrame.StartMoving)
    statsFrame:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
        -- Ensure settings table exists
        if not HardcoreDeathraceDB then
            HardcoreDeathraceDB = {}
        end
        if not HardcoreDeathraceDB.settings then
            HardcoreDeathraceDB.settings = {}
        end
        -- Save the new position (always relative to UIParent)
        -- Positions are saved in scaled coordinates, which is correct
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        HardcoreDeathraceDB.settings.statsFramePoint = point
        HardcoreDeathraceDB.settings.statsFrameRelativePoint = relativePoint
        HardcoreDeathraceDB.settings.statsFrameX = xOfs
        HardcoreDeathraceDB.settings.statsFrameY = yOfs
    end)
    statsFrame:Show()
    
    -- Title
    local title = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    -- Even padding: 12px from top (was 10px)
    title:SetPoint('TOP', statsFrame, 'TOP', 0, -12)
    -- Increased font size from 20 to 22
    title:SetFont('Fonts\\MORPHEUS.TTF', 22 * fontScale, 'OUTLINE') -- Morpheus gothic font
    title:SetText('|cFFFF0000Hardcore Deathrace|r')
    statsFrame.title = title
    
    -- Current Level
    local levelLabel = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    -- Increased left padding from 10px to 14px for better spacing from left edge
    -- Increased padding from title: moved from -38 to -42 to add more space between title and Level row
    levelLabel:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 14, -42)
    -- Increased font size from 13 to 14
    levelLabel:SetFont('Fonts\\FRIZQT__.TTF', 14 * fontScale)
    levelLabel:SetText('Level:')
    statsFrame.levelLabel = levelLabel
    
    local levelValue = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    -- Position value at fixed X offset to align all values vertically
    -- 76px from left (increased from 72 to match increased label padding)
    levelValue:SetPoint('LEFT', statsFrame, 'LEFT', 76 * fontScale, 0)
    -- Align vertically with its label
    levelValue:SetPoint('TOP', levelLabel, 'TOP', 0, 0)
    -- Increased font size from 13 to 14
    levelValue:SetFont('Fonts\\FRIZQT__.TTF', 14 * fontScale)
    levelValue:SetText('1')
    statsFrame.levelValue = levelValue
    
    -- Darkness Falls (Time until next darkness level)
    local darknessLabel = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    -- Position after Level row with 20px gap
    darknessLabel:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 14, -62)
    -- Increased font size from 13 to 14
    darknessLabel:SetFont('Fonts\\FRIZQT__.TTF', 14 * fontScale)
    darknessLabel:SetText('Darkness Falls:')
    statsFrame.darknessLabel = darknessLabel
    
    local darknessValue = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    -- Position value independently after the label (no alignment with other values)
    darknessValue:SetPoint('LEFT', darknessLabel, 'RIGHT', 8, 0)
    -- Increased font size from 13 to 14
    darknessValue:SetFont('Fonts\\FRIZQT__.TTF', 14 * fontScale)
    darknessValue:SetText('') -- Blank until data loads
    statsFrame.darknessValue = darknessValue
    
    -- Time Remaining (This Level)
    local timeRemainingLabel = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    -- Increased left padding from 10px to 14px
    -- Adjusted to maintain 20px gap after Darkness Falls row moved to -62
    timeRemainingLabel:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 14, -82)
    -- Increased font size from 13 to 14
    timeRemainingLabel:SetFont('Fonts\\FRIZQT__.TTF', 14 * fontScale)
    timeRemainingLabel:SetText('Failure:')
    statsFrame.timeRemainingLabel = timeRemainingLabel
    
    local timeRemainingValue = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    -- Position value at same fixed X offset to align with other values
    timeRemainingValue:SetPoint('LEFT', statsFrame, 'LEFT', 76 * fontScale, 0)
    -- Align vertically with its label
    timeRemainingValue:SetPoint('TOP', timeRemainingLabel, 'TOP', 0, 0)
    -- Increased font size from 13 to 14
    timeRemainingValue:SetFont('Fonts\\FRIZQT__.TTF', 14 * fontScale)
    timeRemainingValue:SetText('') -- Blank until data loads
    statsFrame.timeRemainingValue = timeRemainingValue
    
    -- Status indicator (Resting/Paused)
    local statusLabel = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    -- Position relative to Failure row (will be repositioned when failed)
    statusLabel:SetPoint('TOP', timeRemainingValue, 'BOTTOM', 0, -4)
    -- Increased left padding from 10px to 14px to match other elements
    statusLabel:SetPoint('LEFT', statsFrame, 'LEFT', 14, 0)
    statusLabel:SetPoint('RIGHT', statsFrame, 'RIGHT', -5, 0)
    statusLabel:SetJustifyH('CENTER')
    -- Increased font size from 13 to 14
    statusLabel:SetFont('Fonts\\FRIZQT__.TTF', 14 * fontScale)
    statusLabel:SetText('')
    statsFrame.statusLabel = statusLabel
end

-- Update statistics panel
function UpdateStatisticsPanel()
    if not statsFrame then
        return
    end
    
    local currentLevel = HardcoreDeathrace.GetCurrentLevel()
    local timeRemaining = HardcoreDeathrace.GetTimeRemaining()
    local totalTimePlayed = HardcoreDeathrace.GetTotalTimePlayed()
    local isResting = HardcoreDeathrace.IsResting()
    local isOnFlightPath = HardcoreDeathrace.IsOnFlightPath()
    local hasFailed = HardcoreDeathrace.HasFailed()
    local hasWon = HardcoreDeathrace.HasWon()
    local failureLevel = HardcoreDeathrace.GetFailureLevel()
    
    -- Update level - show failure level if failed, otherwise current level
    if hasFailed then
        statsFrame.levelValue:SetText(tostring(failureLevel))
    else
        statsFrame.levelValue:SetText(tostring(currentLevel))
    end
    
    -- Update darkness falls timer and visibility
    if hasFailed or hasWon then
        -- Hide darkness falls row when failed/won
        statsFrame.darknessLabel:Hide()
        statsFrame.darknessValue:Hide()
    else
        -- Show darkness falls row when not failed/won
        statsFrame.darknessLabel:Show()
        statsFrame.darknessValue:Show()
        
        local timeUntilDarkness = HardcoreDeathrace.GetTimeUntilNextDarkness()
        
        -- Always use white color for darkness falls timer
        statsFrame.darknessValue:SetTextColor(1, 1, 1) -- White
        
        if timeUntilDarkness == nil or timeUntilDarkness < 0 then
            -- Should not happen, but fallback
            statsFrame.darknessValue:SetText('N/A')
        elseif timeUntilDarkness == 0 then
            -- Already at threshold - calculate current darkness level based on time percentage
            local timeRemaining = HardcoreDeathrace.GetTimeRemaining()
            local timeForLevel = HardcoreDeathrace.GetOriginalTimeAllocation() or 1800
            local timePercent = (timeRemaining / timeForLevel) * 100
            local currentDarknessLevel = 0
            
            -- Calculate darkness level (same logic as GetDarknessLevel but without resting check)
            if timePercent > 50 then
                currentDarknessLevel = 0
            elseif timePercent > 25 then
                currentDarknessLevel = 1
            elseif timePercent > 10 then
                currentDarknessLevel = 2
            elseif timePercent > 5 then
                currentDarknessLevel = 3
            else
                currentDarknessLevel = 4
            end
            
            if currentDarknessLevel == 4 then
                statsFrame.darknessValue:SetText('Max Darkness')
            else
                statsFrame.darknessValue:SetText('Level ' .. (currentDarknessLevel + 1))
            end
        else
            -- Show time until next darkness level
            local darknessFormatted = HardcoreDeathrace.FormatPlayedTime(timeUntilDarkness)
            statsFrame.darknessValue:SetText(darknessFormatted)
        end
    end
    
    -- Update time remaining with color coding (in /played format)
    -- If won, show "Score:" label and total time in green (compact UI like failure)
    -- If failed, show total time in red (compact UI)
    if hasWon then
        -- When won: show "Score:" label and total time played in green, use compact UI
        local totalTimeFormatted = HardcoreDeathrace.FormatPlayedTime(totalTimePlayed)
        statsFrame.timeRemainingLabel:SetText('Score:')
        statsFrame.timeRemainingValue:SetText('|cFF00FF00' .. totalTimeFormatted .. '|r')
        statsFrame.timeRemainingValue:SetTextColor(0, 1, 0)
        
        -- Reduce frame height since Darkness Falls row is removed (20px reduction)
        -- Original height: 112, reduced height: 92
        statsFrame:SetHeight(92)
        
        -- Move Score row up to -62 (where Darkness Falls was)
        statsFrame.timeRemainingLabel:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 14, -62)
        
        -- Reposition Status row below Score row
        statsFrame.statusLabel:SetPoint('TOP', statsFrame.timeRemainingValue, 'BOTTOM', 0, -4)
    elseif hasFailed then
        -- When failed: show total time played in red, move Failure row up (to where Darkness Falls was)
        local totalTimeFormatted = HardcoreDeathrace.FormatPlayedTime(totalTimePlayed)
        statsFrame.timeRemainingLabel:SetText('Failure:')
        statsFrame.timeRemainingValue:SetText('|cFFFF0000' .. totalTimeFormatted .. '|r')
        statsFrame.timeRemainingValue:SetTextColor(1, 0, 0)
        
        -- Reduce frame height since Darkness Falls row is removed (20px reduction)
        -- Original height: 112, reduced height: 92
        statsFrame:SetHeight(92)
        
        -- Move Failure row up to -62 (where Darkness Falls was)
        statsFrame.timeRemainingLabel:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 14, -62)
        
        -- Reposition Status row below Failure row
        statsFrame.statusLabel:SetPoint('TOP', statsFrame.timeRemainingValue, 'BOTTOM', 0, -4)
    else
        -- When not failed/won: restore normal positions and frame height
        -- Restore frame height to original (112)
        statsFrame:SetHeight(112)
        
        -- Restore label text to "Failure:"
        statsFrame.timeRemainingLabel:SetText('Failure:')
        
        -- Restore Failure row to original position (-82)
        statsFrame.timeRemainingLabel:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 14, -82)
        
        -- Restore Status row position (below Failure row)
        statsFrame.statusLabel:SetPoint('TOP', statsFrame.timeRemainingValue, 'BOTTOM', 0, -4)
        
        local timeRemainingFormatted = HardcoreDeathrace.FormatPlayedTime(timeRemaining)
        -- Use original time allocation (base + rolled-over, excluding bonuses) for percentage calculation
        -- This matches the darkness calculation so colors sync with darkness levels
        local originalTimeAllocation = HardcoreDeathrace.GetOriginalTimeAllocation() or 1800
        local timePercent = (timeRemaining / originalTimeAllocation) * 100
        
        -- Set color based on time remaining percentage
        if isResting or isOnFlightPath then
            -- Light blue/cyan when resting or on flight path (timer paused)
            statsFrame.timeRemainingValue:SetTextColor(0, 1, 1)
        elseif timePercent > 75 then
            -- Green from 100% to 75%
            statsFrame.timeRemainingValue:SetTextColor(0, 1, 0)
        elseif timePercent > 50 then
            -- White from 75% to 50%
            statsFrame.timeRemainingValue:SetTextColor(1, 1, 1)
        elseif timePercent > 25 then
            -- Yellow from 50% to 25%
            statsFrame.timeRemainingValue:SetTextColor(1, 1, 0)
        elseif timePercent > 10 then
            -- Orange from 25% to 10%
            statsFrame.timeRemainingValue:SetTextColor(1, 0.65, 0)
        else
            -- Red from 10% to 0%
            statsFrame.timeRemainingValue:SetTextColor(1, 0, 0)
        end
        
        statsFrame.timeRemainingValue:SetText(timeRemainingFormatted)
    end
    
    -- Status label is intentionally blank in all states
    -- (flight path pause is conveyed by the cyan timer colour; no extra text needed)
    statsFrame.statusLabel:SetText('')
end

-- Create failure/win screen (reusable for both)
function CreateFailureScreen()
    -- Get font scale factor for current resolution
    local fontScale = GetFontScale()
    
    -- Destroy old frame if it exists to ensure fresh creation
    if failureFrame then
        failureFrame:Hide()
        failureFrame:SetParent(nil)
        -- Clear all scripts and children
        failureFrame:SetScript('OnMouseDown', nil)
        failureFrame:SetScript('OnMouseUp', nil)
        failureFrame:SetScript('OnEnter', nil)
        failureFrame:SetScript('OnLeave', nil)
        failureFrame = nil
    end
    
    -- Use nil name to avoid caching issues
    failureFrame = CreateFrame('Frame', nil, UIParent)
    failureFrame:SetAllPoints(UIParent)
    failureFrame:SetFrameStrata('FULLSCREEN_DIALOG')
    failureFrame:SetFrameLevel(3000) -- Above tunnel_vision_5 (level 2000)
    
    -- Background is handled by tunnel_vision_5.png for failure, transparent for win
    failureFrame:Hide()
    
    -- Failure/Win message (centered) - same font as tracker title, much larger
    local failureText = failureFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
    -- Apply font scale to vertical offset (base offset: 120, moved up to make room for condensed race/class/level)
    failureText:SetPoint('CENTER', failureFrame, 'CENTER', 0, 120 * fontScale)
    -- Apply font scale to font size (base size: 36)
    failureText:SetFont('Fonts\\MORPHEUS.TTF', 36 * fontScale, 'OUTLINE') -- Much larger font
    failureText:SetText('')
    failureFrame.failureText = failureText
    
    -- Combined race, level, and class display (centered, below failure message)
    -- Format: "Level 1 Gnome Warrior"
    local characterInfoText = failureFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    characterInfoText:SetPoint('CENTER', failureFrame, 'CENTER', 0, 70 * fontScale)
    -- Apply font scale to font size (base size: 16)
    characterInfoText:SetFont('Fonts\\FRIZQT__.TTF', 16 * fontScale)
    characterInfoText:SetText('')
    characterInfoText:SetTextColor(1, 1, 1) -- White color
    failureFrame.characterInfoText = characterInfoText
    
    -- Final score value (centered, full format, below character info)
    local scoreValue = failureFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
    scoreValue:SetPoint('CENTER', failureFrame, 'CENTER', 0, 30 * fontScale)
    -- Apply font scale to font size (base size: 20)
    scoreValue:SetFont('Fonts\\FRIZQT__.TTF', 20 * fontScale)
    scoreValue:SetText('')
    scoreValue:SetTextColor(1, 1, 1) -- White color
    failureFrame.scoreValue = scoreValue
    
    -- Previous high score comparison (centered, below score)
    local previousHighScoreText = failureFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    previousHighScoreText:SetPoint('CENTER', failureFrame, 'CENTER', 0, -40 * fontScale)
    -- Apply font scale to font size (base size: 16)
    previousHighScoreText:SetFont('Fonts\\FRIZQT__.TTF', 16 * fontScale)
    previousHighScoreText:SetText('')
    previousHighScoreText:SetTextColor(1, 1, 1) -- Default white, will change based on comparison
    failureFrame.previousHighScoreText = previousHighScoreText
    
    -- Function to handle continue action (define before using)
    local function ContinuePlaying()
        -- Disable fog effect (remove tunnel_vision_5)
        -- Use namespaced function to avoid conflicts with other addons
        if HardcoreDeathrace and HardcoreDeathrace.RemoveTunnelVision then
            HardcoreDeathrace.RemoveTunnelVision()
        end
        -- Hide failure screen
        failureFrame:Hide()
        -- Show statistics panel with stopped times
        if statsFrame then
            statsFrame:Show()
        end
    end
    
    -- Store continue function on frame so it's accessible
    failureFrame.ContinuePlaying = ContinuePlaying
    
    -- Continue playing text - clickable
    local continueTextFrame = CreateFrame('Frame', nil, failureFrame)
    -- Apply font scale to vertical offset (base offset: -100, moved down to make room for high score comparison)
    continueTextFrame:SetPoint('CENTER', failureFrame, 'CENTER', 0, -100 * fontScale)
    -- Apply font scale to frame size (base size: 300x30)
    continueTextFrame:SetSize(300 * fontScale, 30 * fontScale)
    continueTextFrame:EnableMouse(true)
    
    local continueText = continueTextFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    continueText:SetPoint('CENTER', continueTextFrame, 'CENTER', 0, 0)
    -- Apply font scale to font size (base size: 16)
    continueText:SetFont('Fonts\\FRIZQT__.TTF', 16 * fontScale)
    continueText:SetTextColor(1, 1, 0) -- Yellow color
    continueText:SetText('Click here to continue playing')
    continueTextFrame.text = continueText
    
    -- Make it clickable
    continueTextFrame:SetScript('OnMouseUp', function()
        ContinuePlaying()
    end)
    
    -- Add hover effect
    continueTextFrame:SetScript('OnEnter', function()
        continueText:SetTextColor(1, 1, 1) -- White on hover
    end)
    continueTextFrame:SetScript('OnLeave', function()
        continueText:SetTextColor(1, 1, 0) -- Yellow when not hovering
    end)
    
    failureFrame.continueText = continueTextFrame
    failureFrame.continueTextFrame = continueTextFrame -- Store reference for dynamic positioning
end

-- Show failure screen
-- previousHighScore: Optional parameter - the previous high score BEFORE saving the current one
--                     If not provided, will get it from the database (for /dr fail command)
function ShowFailureScreen(previousHighScore)
    -- Always recreate to ensure fresh frame with latest code
    CreateFailureScreen()
    
    -- Get font scale for positioning (needed for dynamic button positioning)
    local fontScale = GetFontScale()
    
    -- Get player information
    -- UnitClass and UnitRace return localized name as first value, file name as second
    local playerClass, _ = UnitClass('player')
    local playerRace, _ = UnitRace('player')
    local failureLevel = HardcoreDeathrace.GetFailureLevel()
    local totalTimePlayed = HardcoreDeathrace.GetTotalTimePlayed()
    
    -- Set failure message
    failureFrame.failureText:SetText('|cFFFF0000DEATHRACE FAILED|r')
    failureFrame.failureText:SetTextColor(1, 0, 0)
    
    -- Display race, level, and class in condensed format: "Level 1 Gnome Warrior"
    local characterInfo = "Level " .. tostring(failureLevel)
    if playerRace then
        characterInfo = characterInfo .. " " .. playerRace
    end
    if playerClass then
        characterInfo = characterInfo .. " " .. playerClass
    end
    failureFrame.characterInfoText:SetText(characterInfo)
    
    -- Show full format score (days, hours, mins, secs)
    failureFrame.scoreValue:SetText('Score: ' .. HardcoreDeathrace.FormatPlayedTimeFull(totalTimePlayed))
    
    -- Get and display previous high score comparison
    -- Use provided previousHighScore if available, otherwise get from database
    -- This ensures we compare against the OLD high score, not the newly saved one
    if not previousHighScore then
        previousHighScore = HardcoreDeathrace.GetAccountHighScore()
    end
    if previousHighScore and previousHighScore > 0 then
        -- Show the previous high score comparison
        failureFrame.previousHighScoreText:Show()
        
        -- Calculate time difference (positive = better, negative = worse)
        local timeDifference = totalTimePlayed - previousHighScore
        
        if timeDifference > 0 then
            -- New high score! Show in green
            local diffFormatted = HardcoreDeathrace.FormatPlayedTimeFull(timeDifference)
            failureFrame.previousHighScoreText:SetText('Previous Best: ' .. HardcoreDeathrace.FormatPlayedTimeFull(previousHighScore) .. ' |cFF00FF00(+' .. diffFormatted .. ')|r')
            failureFrame.previousHighScoreText:SetTextColor(1, 1, 1) -- White base color
        elseif timeDifference < 0 then
            -- Worse than previous best, show in red
            local diffFormatted = HardcoreDeathrace.FormatPlayedTimeFull(math.abs(timeDifference))
            failureFrame.previousHighScoreText:SetText('Previous Best: ' .. HardcoreDeathrace.FormatPlayedTimeFull(previousHighScore) .. ' |cFFFF0000(-' .. diffFormatted .. ')|r')
            failureFrame.previousHighScoreText:SetTextColor(1, 1, 1) -- White base color
        else
            -- Exactly the same (unlikely but handle it)
            failureFrame.previousHighScoreText:SetText('Previous Best: ' .. HardcoreDeathrace.FormatPlayedTimeFull(previousHighScore) .. ' (Tied)')
            failureFrame.previousHighScoreText:SetTextColor(1, 1, 1) -- White color
        end
        
        -- Position continue button below previous high score (with spacing)
        failureFrame.continueTextFrame:SetPoint('CENTER', failureFrame, 'CENTER', 0, -100 * fontScale)
    else
        -- No previous high score - hide the line instead of showing "None"
        failureFrame.previousHighScoreText:Hide()
        
        -- Position continue button closer to score line (reduced spacing)
        failureFrame.continueTextFrame:SetPoint('CENTER', failureFrame, 'CENTER', 0, -60 * fontScale)
    end
    
    failureFrame:Show()
    
    -- Keep statistics panel visible but stopped (times won't update)
end

-- Show win screen
function ShowWinScreen()
    -- Always recreate to ensure fresh frame with latest code
    CreateFailureScreen()
    
    local totalTimePlayed = HardcoreDeathrace.GetTotalTimePlayed()
    -- Show full format (days, hours, mins, secs)
    failureFrame.scoreValue:SetText(HardcoreDeathrace.FormatPlayedTimeFull(totalTimePlayed))
    
    -- Set win message (green)
    failureFrame.failureText:SetText('|cFF00FF00DEATHRACE WON|r')
    failureFrame.failureText:SetTextColor(0, 1, 0)
    
    failureFrame:Show()
    
    -- Keep statistics panel visible but stopped (times won't update)
end

--/*******************/ WELCOME / START RACE SCREEN /*************************/--

-- Creates (or recreates) the welcome modal and stores it in welcomeFrame.
-- The frame is hidden by default; call ShowWelcomeScreen() to display it.
local function CreateWelcomeScreen()
    -- Tear down any previous instance so the frame is always fresh on first show
    if welcomeFrame then
        welcomeFrame:Hide()
        welcomeFrame = nil
    end

    local fontScale = GetFontScale()

    -- ---- Outer frame ----
    -- Use BackdropTemplate for the classic Blizzard dialog look
    welcomeFrame = CreateFrame('Frame', 'HardcoreDeathraceWelcomeFrame', UIParent, 'BackdropTemplate')
    welcomeFrame:SetSize(520, 530)
    welcomeFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 20)

    -- Classic dialog chrome: dark background + ornate border
    welcomeFrame:SetBackdrop({
        bgFile   = 'Interface\\DialogFrame\\UI-DialogBox-Background',
        edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
        tile     = true,
        tileSize = 32,
        edgeSize = 32,
        insets   = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    welcomeFrame:SetBackdropColor(0, 0, 0, 1)

    -- Render above game UI but below system dialogs
    welcomeFrame:SetFrameStrata('DIALOG')
    welcomeFrame:SetFrameLevel(50)

    -- Allow Escape key to dismiss (players can close it, but XP check still applies)
    tinsert(UISpecialFrames, 'HardcoreDeathraceWelcomeFrame')

    -- Allow dragging so it can be moved out of the way
    welcomeFrame:SetMovable(true)
    welcomeFrame:EnableMouse(true)
    welcomeFrame:RegisterForDrag('LeftButton')
    welcomeFrame:SetScript('OnDragStart', welcomeFrame.StartMoving)
    welcomeFrame:SetScript('OnDragStop',  welcomeFrame.StopMovingOrSizing)

    -- ---- Title ----
    local title = welcomeFrame:CreateFontString(nil, 'OVERLAY')
    title:SetFont('Fonts\\MORPHEUS.TTF', 30 * fontScale, 'OUTLINE')
    title:SetPoint('TOP', welcomeFrame, 'TOP', 0, -22)
    title:SetText('|cFFFF0000Hardcore Deathrace|r')
    title:SetShadowOffset(2, -2)
    title:SetShadowColor(0, 0, 0, 1)

    -- ---- Subtitle ----
    local subtitle = welcomeFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    subtitle:SetPoint('TOP', title, 'BOTTOM', 0, -6)
    subtitle:SetFont('Fonts\\FRIZQT__.TTF', 13 * fontScale, 'OUTLINE')
    subtitle:SetTextColor(1, 0.82, 0)   -- Gold
    subtitle:SetText('Race Against Time. Ding Before Darkness Falls.')

    -- ---- Made by credit line ----
    local credit = welcomeFrame:CreateFontString(nil, 'OVERLAY')
    credit:SetFont('Fonts\\FRIZQT__.TTF', 11 * fontScale)
    credit:SetTextColor(0.65, 0.65, 0.65)  -- Muted gray
    credit:SetPoint('TOP', subtitle, 'BOTTOM', 0, -4)
    credit:SetText('Made by VanityProjects  |cFF9B59B6twitch.tv/vanityprojects|r')

    -- ---- Divider line below credit ----
    local divider = welcomeFrame:CreateTexture(nil, 'ARTWORK')
    divider:SetColorTexture(0.5, 0.1, 0.1, 0.9)  -- Dark red stripe
    divider:SetSize(460, 2)
    divider:SetPoint('TOP', credit, 'BOTTOM', 0, -10)

    -- ---- Body text ----
    -- Helper that creates a left-aligned paragraph and returns the font string
    local BODY_LEFT   = -230  -- left edge x relative to frame center
    local BODY_WIDTH  = 460

    local function AddParagraph(anchorTo, yOffset, text, r, g, b, size)
        local fs = welcomeFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        fs:SetFont('Fonts\\FRIZQT__.TTF', (size or 12) * fontScale)
        fs:SetTextColor(r or 0.9, g or 0.9, b or 0.9)
        fs:SetWidth(BODY_WIDTH)
        fs:SetJustifyH('LEFT')
        fs:SetNonSpaceWrap(true)
        if type(anchorTo) == 'table' then
            fs:SetPoint('TOPLEFT', anchorTo, 'BOTTOMLEFT', 0, yOffset)
        else
            -- anchorTo is a y-offset from the frame TOP
            fs:SetPoint('TOPLEFT', welcomeFrame, 'TOPLEFT', 30, anchorTo)
        end
        fs:SetText(text)
        return fs
    end

    -- Section: how the race works
    local introAnchor = divider
    local p1 = AddParagraph(introAnchor, -14,
        'Each level has a time limit. Race the clock to level up before your ' ..
        'timer hits zero. The timer ticks down whether you are killing monsters, ' ..
        'questing, or standing idle — every second counts.',
        0.95, 0.95, 0.95)

    -- Section heading: earning bonus time
    local bonusHeading = welcomeFrame:CreateFontString(nil, 'OVERLAY')
    bonusHeading:SetFont('Fonts\\FRIZQT__.TTF', 13 * fontScale, 'OUTLINE')
    bonusHeading:SetTextColor(1, 0.82, 0)  -- Gold
    bonusHeading:SetPoint('TOPLEFT', p1, 'BOTTOMLEFT', 0, -12)
    bonusHeading:SetText('Earning Bonus Time')

    local p2 = AddParagraph(bonusHeading, -8,
        '|cFF00FF00\124  Complete Hardcore Achievements|r   |cFFFFFFFF+30 min each|r\n' ..
        '|cFF00FF00\124  Level up a profession skill|r        |cFFFFFFFF+20 sec each|r\n' ..
        '|cFF00FF00\124  Rares, chests and exploration|r       |cFFFFFFFFComing Soon|r\n' ..
        '|cFF00CC44\124  Unused time rolls over on level-up|r\n' ..
        '|cFF00CC44\124  Timer pauses in rested areas and on flight paths|r',
        1, 1, 1, 12)

    -- Section heading: danger
    local dangerHeading = welcomeFrame:CreateFontString(nil, 'OVERLAY')
    dangerHeading:SetFont('Fonts\\FRIZQT__.TTF', 13 * fontScale, 'OUTLINE')
    dangerHeading:SetTextColor(1, 0.3, 0.3)  -- Red
    dangerHeading:SetPoint('TOPLEFT', p2, 'BOTTOMLEFT', 0, -12)
    dangerHeading:SetText('Darkness Falls')

    local p3 = AddParagraph(dangerHeading, -8,
        'As your timer runs low your screen progressively darkens with tunnel vision. ' ..
        'When time runs out the screen goes black and your race is over.',
        0.9, 0.9, 0.9)

    local p4 = AddParagraph(p3, -12,
        '|cFFFF4444WARNING:|r  Your timer is paused until you click Start Race. ' ..
        'If you earn any XP before starting — through kills, quests, or any other ' ..
        'means — your run |cFFFF0000fails immediately|r. No exceptions.',
        0.95, 0.85, 0.85)

    -- ---- Second divider above button ----
    local divider2 = welcomeFrame:CreateTexture(nil, 'ARTWORK')
    divider2:SetColorTexture(0.5, 0.1, 0.1, 0.9)
    divider2:SetSize(460, 2)
    divider2:SetPoint('TOP', p4, 'BOTTOM', 0, -18)

    -- ---- "Start Race" button ----
    local startBtn = CreateFrame('Button', nil, welcomeFrame, 'UIPanelButtonTemplate')
    startBtn:SetSize(200, 38)
    startBtn:SetPoint('BOTTOM', welcomeFrame, 'BOTTOM', 0, 22)
    startBtn:SetText('Start Race')
    -- Override the default font with something bolder
    startBtn:GetFontString():SetFont('Fonts\\FRIZQT__.TTF', 15 * fontScale, 'OUTLINE')

    -- White button text
    startBtn:GetFontString():SetTextColor(1, 1, 1)

    startBtn:SetScript('OnClick', function()
        -- Delegate to Core.lua via the public namespace
        if HardcoreDeathrace and HardcoreDeathrace.StartRace then
            HardcoreDeathrace.StartRace()
        end
    end)

    -- Hover highlight: brighten text on mouseover
    startBtn:SetScript('OnEnter', function(self)
        self:GetFontString():SetTextColor(1, 1, 0)  -- Yellow on hover
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:SetText('Click to begin your Deathrace!\nThe timer will start immediately.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    startBtn:SetScript('OnLeave', function(self)
        self:GetFontString():SetTextColor(1, 1, 1)  -- Back to white
        GameTooltip:Hide()
    end)

    -- Resize the frame to snugly fit all content (bottom of divider2 + button area + padding)
    -- We compute height dynamically from the bottom of p4 to keep it tidy
    local frameBottom = welcomeFrame:GetBottom()
    welcomeFrame:SetHeight(530)  -- Fixed height that comfortably fits all content

    welcomeFrame:Hide()  -- Hidden until ShowWelcomeScreen() is called
end

-- Shows the welcome screen, creating it first if needed.
-- Called from Core.lua's PLAYER_LOGIN handler when raceStarted == false.
function ShowWelcomeScreen()
    if not welcomeFrame then
        CreateWelcomeScreen()
    end
    welcomeFrame:Show()
    -- Raise above any other frames that may have appeared since creation
    welcomeFrame:Raise()
end

-- Hides the welcome screen. Called by StartRace() in Core.lua (via _G.HideWelcomeScreen)
-- and also by the XP-cheat fail path.
function HideWelcomeScreen()
    if welcomeFrame then
        welcomeFrame:Hide()
    end
end

-- Export both functions as globals so Core.lua can call them by name
_G.ShowWelcomeScreen = ShowWelcomeScreen
_G.HideWelcomeScreen = HideWelcomeScreen

-- Show floating bonus time indicator
-- Displays a green text that floats upward from the stats frame
-- text: The text to display (e.g., "+20 sec" or "+30 min")
-- Make function globally accessible
function ShowBonusTimeFloat(text)
    if not statsFrame then
        return
    end
    
    -- Get font scale for consistent sizing
    local fontScale = GetFontScale()
    
    -- Create floating text frame
    local floatFrame = CreateFrame('Frame', nil, UIParent)
    floatFrame:SetFrameStrata('FULLSCREEN_DIALOG')
    floatFrame:SetFrameLevel(2100) -- Above stats frame (2000)
    floatFrame:SetSize(200, 50) -- Set size to ensure frame is visible
    
    -- Create font string for the floating text
    local floatText = floatFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    floatText:SetFont('Fonts\\FRIZQT__.TTF', 18 * fontScale, 'OUTLINE')
    floatText:SetTextColor(0, 1, 0, 1) -- Green color
    floatText:SetText(text)
    floatText:SetPoint('CENTER', floatFrame, 'CENTER', 0, 0)
    floatFrame.text = floatText
    
    -- Position horizontally centered in frame, vertically at failure time text
    -- Start animation from the vertical position of the failure time display
    if statsFrame.timeRemainingValue then
        -- Calculate horizontal offset to center in frame
        -- Get the center X of the statsFrame
        local statsFrameCenterX = statsFrame:GetLeft() + (statsFrame:GetWidth() / 2)
        -- Get the center X of the timeRemainingValue
        local timeValueCenterX = statsFrame.timeRemainingValue:GetLeft() + (statsFrame.timeRemainingValue:GetWidth() / 2)
        -- Calculate offset needed to center horizontally
        local horizontalOffset = statsFrameCenterX - timeValueCenterX
        
        -- Anchor to center of failure time value, then offset horizontally to center of frame
        floatFrame:SetPoint('CENTER', statsFrame.timeRemainingValue, 'CENTER', horizontalOffset, 0)
    else
        -- Fallback to center-top if timeRemainingValue doesn't exist
        floatFrame:SetPoint('CENTER', statsFrame, 'TOP', 0, 10)
    end
    
    -- Show the frame
    floatFrame:Show()
    
    -- Animation variables (stored on frame to persist across updates)
    floatFrame.startY = 0  -- Start at the failure time line Y position
    floatFrame.endY = 50    -- Float upward from there (increased from 40 for smoother animation)
    floatFrame.duration = 2.5 -- 2.5 second animation (increased from 1.0 to make it visible longer)
    floatFrame.elapsed = 0
    floatFrame.startAlpha = 1.0
    floatFrame.endAlpha = 0.0
    
    -- Animate the floating text
    floatFrame:SetScript('OnUpdate', function(self, delta)
        self.elapsed = self.elapsed + delta
        
        if self.elapsed >= self.duration then
            -- Animation complete, hide and remove frame
            self:Hide()
            self:SetScript('OnUpdate', nil)
            return
        end
        
        -- Calculate progress (0 to 1)
        local progress = self.elapsed / self.duration
        
        -- Interpolate Y position (float upward)
        local currentY = self.startY + (self.endY - self.startY) * progress
        self:ClearAllPoints()
        -- Keep horizontally centered in frame, but offset upward from failure time position
        if statsFrame.timeRemainingValue then
            -- Calculate horizontal offset to center in frame (recalculate in case frame moved)
            local statsFrameCenterX = statsFrame:GetLeft() + (statsFrame:GetWidth() / 2)
            local timeValueCenterX = statsFrame.timeRemainingValue:GetLeft() + (statsFrame.timeRemainingValue:GetWidth() / 2)
            local horizontalOffset = statsFrameCenterX - timeValueCenterX
            
            self:SetPoint('CENTER', statsFrame.timeRemainingValue, 'CENTER', horizontalOffset, currentY)
        else
            -- Fallback positioning
            self:SetPoint('CENTER', statsFrame, 'TOP', 0, currentY)
        end
        
        -- Interpolate alpha (fade out)
        local currentAlpha = self.startAlpha + (self.endAlpha - self.startAlpha) * progress
        floatText:SetTextColor(0, 1, 0, currentAlpha)
    end)
end

-- Make function globally accessible
_G.ShowBonusTimeFloat = ShowBonusTimeFloat


