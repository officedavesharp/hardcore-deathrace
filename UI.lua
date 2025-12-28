-- Hardcore Deathrace - UI Elements (Statistics Panel and Failure Screen)

-- Statistics Panel Frame
local statsFrame = nil
local failureFrame = nil

-- Initialize global settings if needed
HardcoreDeathraceDB = HardcoreDeathraceDB or {}
HardcoreDeathraceDB.settings = HardcoreDeathraceDB.settings or {}


-- Initialize UI elements
function InitializeUI()
    CreateStatisticsPanel()
    CreateFailureScreen()
end

-- Create statistics panel
function CreateStatisticsPanel()
    -- Create main frame
    statsFrame = CreateFrame('Frame', 'HardcoreDeathraceStatsFrame', UIParent)
    statsFrame:SetSize(250, 105)
    
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
        statsFrame:SetPoint(settings.statsFramePoint, UIParent, settings.statsFrameRelativePoint, 
                           settings.statsFrameX, settings.statsFrameY)
    else
        -- Use default position
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
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        HardcoreDeathraceDB.settings.statsFramePoint = point
        HardcoreDeathraceDB.settings.statsFrameRelativePoint = relativePoint
        HardcoreDeathraceDB.settings.statsFrameX = xOfs
        HardcoreDeathraceDB.settings.statsFrameY = yOfs
    end)
    statsFrame:Show()
    
    -- Title
    local title = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOP', statsFrame, 'TOP', 0, -10)
    -- Try Morpheus for gothic look, alternatives: 'Fonts\\SKURRI.TTF' or 'Fonts\\FRIZQT__.TTF'
    title:SetFont('Fonts\\MORPHEUS.TTF', 20, 'OUTLINE') -- Morpheus gothic font
    title:SetText('|cFFFF0000Hardcore Deathrace|r')
    statsFrame.title = title
    
    -- Current Level
    local levelLabel = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    levelLabel:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 10, -35)
    levelLabel:SetText('Level:')
    statsFrame.levelLabel = levelLabel
    
    local levelValue = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    levelValue:SetPoint('LEFT', levelLabel, 'RIGHT', 10, 0)
    levelValue:SetText('1')
    statsFrame.levelValue = levelValue
    
    -- Time Remaining (This Level)
    local timeRemainingLabel = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    timeRemainingLabel:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 10, -55)
    timeRemainingLabel:SetText('Failure Timer:')
    statsFrame.timeRemainingLabel = timeRemainingLabel
    
    local timeRemainingValue = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    timeRemainingValue:SetPoint('LEFT', timeRemainingLabel, 'RIGHT', 10, 0)
    timeRemainingValue:SetText('') -- Blank until data loads
    statsFrame.timeRemainingValue = timeRemainingValue
    
    -- Total Time Played
    local totalTimeLabel = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    totalTimeLabel:SetPoint('TOPLEFT', statsFrame, 'TOPLEFT', 10, -75)
    totalTimeLabel:SetText('Score:')
    statsFrame.totalTimeLabel = totalTimeLabel
    
    local totalTimeValue = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    totalTimeValue:SetPoint('LEFT', totalTimeLabel, 'RIGHT', 10, 0)
    totalTimeValue:SetText('') -- Blank until data loads
    statsFrame.totalTimeValue = totalTimeValue
    
    -- Status indicator (Resting/Paused)
    local statusLabel = statsFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    statusLabel:SetPoint('TOP', totalTimeValue, 'BOTTOM', 0, -8)
    statusLabel:SetPoint('LEFT', statsFrame, 'LEFT', 10, 0)
    statusLabel:SetPoint('RIGHT', statsFrame, 'RIGHT', -10, 0)
    statusLabel:SetJustifyH('CENTER')
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
    local hasFailed = HardcoreDeathrace.HasFailed()
    local hasWon = HardcoreDeathrace.HasWon()
    local failureLevel = HardcoreDeathrace.GetFailureLevel()
    
    -- Update level - show failure level if failed, otherwise current level
    if hasFailed then
        statsFrame.levelValue:SetText(tostring(failureLevel))
    else
        statsFrame.levelValue:SetText(tostring(currentLevel))
    end
    
    -- Update time remaining with color coding (in /played format)
    -- If won, show "WON" in green, if failed show "FAILED" in red
    if hasWon then
        statsFrame.timeRemainingValue:SetText('|cFF00FF00WON|r')
        statsFrame.timeRemainingValue:SetTextColor(0, 1, 0)
    elseif hasFailed then
        statsFrame.timeRemainingValue:SetText('|cFFFF0000FAILED|r')
        statsFrame.timeRemainingValue:SetTextColor(1, 0, 0)
    else
        local timeRemainingFormatted = HardcoreDeathrace.FormatPlayedTime(timeRemaining)
        local timeForLevel = HardcoreDeathrace.GetTimeForLevel(currentLevel) or 1800
        local timePercent = (timeRemaining / timeForLevel) * 100
        
        -- Set color based on time remaining percentage
        if isResting then
            -- Light blue/cyan when resting (same as old "(Paused)" color)
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
    
    -- Update total time played (score) in /played format
    statsFrame.totalTimeValue:SetText(HardcoreDeathrace.FormatPlayedTime(totalTimePlayed))
    
    -- Update status (FAILED is now shown in the timer itself)
    if hasFailed then
        statsFrame.statusLabel:SetText('')
    else
        statsFrame.statusLabel:SetText('')
    end
end

-- Create failure/win screen (reusable for both)
function CreateFailureScreen()
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
    failureText:SetPoint('CENTER', failureFrame, 'CENTER', 0, 100)
    failureText:SetFont('Fonts\\MORPHEUS.TTF', 36, 'OUTLINE') -- Much larger font
    failureText:SetText('')
    failureFrame.failureText = failureText
    
    -- Final score value (centered, full format)
    local scoreValue = failureFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
    scoreValue:SetPoint('CENTER', failureFrame, 'CENTER', 0, 0)
    scoreValue:SetFont('Fonts\\FRIZQT__.TTF', 20)
    scoreValue:SetText('')
    scoreValue:SetTextColor(1, 1, 1) -- White color
    failureFrame.scoreValue = scoreValue
    
    -- Function to handle continue action (define before using)
    local function ContinuePlaying()
        -- Disable fog effect (remove tunnel_vision_5)
        RemoveTunnelVision()
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
    continueTextFrame:SetPoint('CENTER', failureFrame, 'CENTER', 0, -80)
    continueTextFrame:SetSize(300, 30)
    continueTextFrame:EnableMouse(true)
    
    local continueText = continueTextFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    continueText:SetPoint('CENTER', continueTextFrame, 'CENTER', 0, 0)
    continueText:SetFont('Fonts\\FRIZQT__.TTF', 16)
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
end

-- Show failure screen
function ShowFailureScreen()
    -- Always recreate to ensure fresh frame with latest code
    CreateFailureScreen()
    
    local totalTimePlayed = HardcoreDeathrace.GetTotalTimePlayed()
    -- Show full format (days, hours, minutes, seconds)
    failureFrame.scoreValue:SetText(HardcoreDeathrace.FormatPlayedTimeFull(totalTimePlayed))
    
    -- Set failure message
    failureFrame.failureText:SetText('|cFFFF0000DEATHRACE FAILED|r')
    failureFrame.failureText:SetTextColor(1, 0, 0)
    
    failureFrame:Show()
    
    -- Keep statistics panel visible but stopped (times won't update)
end

-- Show win screen
function ShowWinScreen()
    -- Always recreate to ensure fresh frame with latest code
    CreateFailureScreen()
    
    local totalTimePlayed = HardcoreDeathrace.GetTotalTimePlayed()
    -- Show full format (days, hours, minutes, seconds)
    failureFrame.scoreValue:SetText(HardcoreDeathrace.FormatPlayedTimeFull(totalTimePlayed))
    
    -- Set win message (green)
    failureFrame.failureText:SetText('|cFF00FF00DEATHRACE WON|r')
    failureFrame.failureText:SetTextColor(0, 1, 0)
    
    failureFrame:Show()
    
    -- Keep statistics panel visible but stopped (times won't update)
end


