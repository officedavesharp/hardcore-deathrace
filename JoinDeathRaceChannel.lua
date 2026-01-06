-- Hardcore Deathrace - Custom Channel Management
-- Creates and manages the "DeathRace" global channel for addon communication
-- Based on Ultra Hardcore's JoinUHCChannel.lua
-- 
-- Channel Persistence: In WoW Classic, custom channels persist as long as at least
-- one person is in them. Ownership automatically transfers when the creator leaves.
-- This addon ensures channel persistence by:
-- 1. Auto-joining all players on login
-- 2. Periodically checking and rejoining if disconnected
-- 3. Ensuring the channel exists even if the original creator deletes their character

-- Channel name for DeathRace addon communication
local CHANNEL_NAME = "DeathRace"

-- Track if we've successfully joined the channel
local channelJoined = false
local lastJoinAttempt = 0
local JOIN_RETRY_DELAY = 30 -- Retry joining every 30 seconds if not in channel
local PERIODIC_CHECK_INTERVAL = 10 -- Check channel status every 10 seconds (more frequent to catch issues)

-- Function to join the DeathRace channel
function JoinDeathRaceChannel(force)
    -- Prevent rapid retry attempts
    local currentTime = GetTime()
    if not force and (currentTime - lastJoinAttempt) < 5 then
        return
    end
    lastJoinAttempt = currentTime
    
    -- Wait a moment to ensure chat system is ready
    C_Timer.After(0.5, function()
        local channelID = select(1, GetChannelName(CHANNEL_NAME))
        
        -- Always ensure we're properly joined, even if channelID exists
        -- If channel exists but checkbox is unchecked, we need to rejoin
        if channelID == 0 then
            channelJoined = false
            
            -- First, try to join the channel by name
            -- JoinChannelByName returns success, channelID
            -- If channel doesn't exist, this creates it. If it exists, we just join it.
            local success, joinedChannelID = JoinChannelByName(CHANNEL_NAME)
            
            -- After joining, add it to the default chat frame to ensure we're actually joined
            -- This is necessary because JoinChannelByName might create the channel but not join you
            -- Adding to a chat frame forces the actual join
            C_Timer.After(0.5, function()
                local verifyChannelID = select(1, GetChannelName(CHANNEL_NAME))
                if verifyChannelID == 0 then
                    -- Still not in channel, add to chat frame to force join
                    -- Note: The channel will appear in chat but addon messages are invisible anyway
                    ChatFrame_AddChannel(DEFAULT_CHAT_FRAME, CHANNEL_NAME)
                    -- Verify again after adding to chat frame
                    C_Timer.After(0.5, function()
                        local finalVerify = select(1, GetChannelName(CHANNEL_NAME))
                        if finalVerify > 0 then
                            channelJoined = true
                        end
                    end)
                else
                    channelJoined = true
                end
            end)
            
            if not success then
                -- Retry after a delay if initial join failed
                C_Timer.After(2, function()
                    local retryChannelID = select(1, GetChannelName(CHANNEL_NAME))
                    if retryChannelID == 0 then
                        local retrySuccess = JoinChannelByName(CHANNEL_NAME)
                        if retrySuccess then
                            C_Timer.After(0.5, function()
                                local finalCheck = select(1, GetChannelName(CHANNEL_NAME))
                                if finalCheck == 0 then
                                    ChatFrame_AddChannel(DEFAULT_CHAT_FRAME, CHANNEL_NAME)
                                    -- Verify again after adding to chat frame
                                    C_Timer.After(0.5, function()
                                        local finalVerify = select(1, GetChannelName(CHANNEL_NAME))
                                        if finalVerify > 0 then
                                            channelJoined = true
                                        end
                                    end)
                                else
                                    channelJoined = true
                                end
                            end)
                        end
                    else
                        channelJoined = true
                    end
                end)
            end
        else
            -- Channel ID exists, but we need to ensure it's properly joined (checkbox checked)
            -- Force rejoin to ensure channel is active - this handles cases where channel exists
            -- but checkbox is unchecked (channel not properly joined for addon messages)
            JoinChannelByName(CHANNEL_NAME)
            C_Timer.After(0.5, function()
                -- Ensure it's added to chat frame to activate it properly
                ChatFrame_AddChannel(DEFAULT_CHAT_FRAME, CHANNEL_NAME)
                -- Verify we're actually in the channel
                C_Timer.After(0.5, function()
                    local verifyID = select(1, GetChannelName(CHANNEL_NAME))
                    if verifyID > 0 then
                        channelJoined = true
                    else
                        channelJoined = false
                    end
                end)
            end)
        end
    end)
end

-- Periodic check to ensure we're still in the channel
-- This ensures channel persistence even if the creator deletes their character
local function PeriodicChannelCheck()
    local channelID = select(1, GetChannelName(CHANNEL_NAME))
    
    if channelID == 0 then
        -- Not in channel, attempt to rejoin
        -- This ensures the channel persists as long as at least one player with the addon is online
        channelJoined = false
        JoinDeathRaceChannel(true)  -- Force rejoin
    else
        -- Channel ID exists, but verify we're properly joined by ensuring it's in chat frame
        -- This handles cases where channel exists but checkbox is unchecked
        if not channelJoined then
            -- Channel exists but we're not marked as joined - force rejoin
            JoinChannelByName(CHANNEL_NAME)
            C_Timer.After(0.5, function()
                ChatFrame_AddChannel(DEFAULT_CHAT_FRAME, CHANNEL_NAME)
                channelJoined = true
            end)
        else
            channelJoined = true
        end
    end
end

-- Get the DeathRace channel ID (returns 0 if not in channel)
function GetDeathRaceChannelID()
    return select(1, GetChannelName(CHANNEL_NAME)) or 0
end

-- Check if we're currently in the channel
function IsInDeathRaceChannel()
    local channelID = select(1, GetChannelName(CHANNEL_NAME))
    return channelID ~= 0
end

-- Periodic check timer frame
local periodicCheckFrame = CreateFrame('Frame')
local lastPeriodicCheck = 0

-- Set up periodic checks using OnUpdate (Classic Era compatible)
periodicCheckFrame:SetScript('OnUpdate', function(self, elapsed)
    lastPeriodicCheck = lastPeriodicCheck + elapsed
    if lastPeriodicCheck >= PERIODIC_CHECK_INTERVAL then
        lastPeriodicCheck = 0
        PeriodicChannelCheck()
    end
end)

-- Register for events to auto-join channel on login
local channelFrame = CreateFrame('Frame')
channelFrame:RegisterEvent('PLAYER_LOGIN')
channelFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
channelFrame:SetScript('OnEvent', function(self, event)
    if event == 'PLAYER_LOGIN' then
        -- Try joining immediately on login
        JoinDeathRaceChannel()
        
        -- Start periodic checks to ensure channel persistence
        -- This ensures the channel stays alive even if the creator leaves
        -- The OnUpdate script will handle periodic checks
    elseif event == 'PLAYER_ENTERING_WORLD' then
        -- Also try on entering world (handles zone changes, reloads)
        -- But only if we're not already in the channel
        local channelID = select(1, GetChannelName(CHANNEL_NAME))
        if channelID == 0 then
            JoinDeathRaceChannel()
        else
            channelJoined = true
        end
    end
end)

-- Export functions for use in Leaderboard.lua
HardcoreDeathraceJoinChannel = HardcoreDeathraceJoinChannel or {}
HardcoreDeathraceJoinChannel.JoinChannel = JoinDeathRaceChannel
HardcoreDeathraceJoinChannel.GetChannelID = GetDeathRaceChannelID
HardcoreDeathraceJoinChannel.IsInChannel = IsInDeathRaceChannel
HardcoreDeathraceJoinChannel.CHANNEL_NAME = CHANNEL_NAME

