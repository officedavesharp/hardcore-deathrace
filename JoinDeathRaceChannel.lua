-- Hardcore Deathrace - Custom Channel Management
-- Creates and manages the "DeathRace" global channel for addon communication
-- Based on Ultra Hardcore's JoinUHCChannel.lua

-- Channel name for DeathRace addon communication
local CHANNEL_NAME = "DeathRace"

-- Function to join the DeathRace channel
function JoinDeathRaceChannel(force)
    -- Wait a moment to ensure chat system is ready
    C_Timer.After(0.5, function()
        local channelID = select(1, GetChannelName(CHANNEL_NAME))
        
        -- If not already in the channel, join it
        if channelID == 0 then
            -- First, try to join the channel by name
            -- JoinChannelByName returns success, channelID
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
                                end
                            end)
                        end
                    end
                end)
            end
        end
    end)
end

-- Get the DeathRace channel ID (returns 0 if not in channel)
function GetDeathRaceChannelID()
    return select(1, GetChannelName(CHANNEL_NAME)) or 0
end

-- Register for events to auto-join channel on login
local channelFrame = CreateFrame('Frame')
channelFrame:RegisterEvent('PLAYER_LOGIN')
channelFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
channelFrame:SetScript('OnEvent', function(self, event)
    if event == 'PLAYER_LOGIN' then
        -- Try joining immediately on login
        JoinDeathRaceChannel()
    elseif event == 'PLAYER_ENTERING_WORLD' then
        -- Also try on entering world (handles zone changes, reloads)
        -- But only if we're not already in the channel
        local channelID = select(1, GetChannelName(CHANNEL_NAME))
        if channelID == 0 then
            JoinDeathRaceChannel()
        end
    end
end)

-- Export functions for use in Leaderboard.lua
HardcoreDeathraceJoinChannel = HardcoreDeathraceJoinChannel or {}
HardcoreDeathraceJoinChannel.JoinChannel = JoinDeathRaceChannel
HardcoreDeathraceJoinChannel.GetChannelID = GetDeathRaceChannelID
HardcoreDeathraceJoinChannel.CHANNEL_NAME = CHANNEL_NAME

