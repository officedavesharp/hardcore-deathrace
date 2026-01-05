-- Hardcore Deathrace - Leaderboard Ranking Functions
-- Provides ranking calculations for realm-wide, race, and class leaderboards

-- Initialize leaderboard namespace
HardcoreDeathraceLeaderboard = HardcoreDeathraceLeaderboard or {}
local LB = HardcoreDeathraceLeaderboard

-- Initialize saved variables for leaderboard data
HardcoreDeathraceDB = HardcoreDeathraceDB or {}
HardcoreDeathraceDB.leaderboard = HardcoreDeathraceDB.leaderboard or {}
HardcoreDeathraceDB.leaderboardIndex = HardcoreDeathraceDB.leaderboardIndex or {}

-- Store reference to WoW API GetServerTime before we define our wrapper
local WoWGetServerTime = GetServerTime

-- Get current server time (wrapper function)
local function GetServerTime()
    return (WoWGetServerTime and WoWGetServerTime()) or time()
end

-- Calculate player's rank in leaderboard based on score
-- Returns: rank (number), totalPlayers (number)
-- Rank is based on score (higher score = better rank, rank 1 is best)
function LB:GetPlayerRank(playerScore, playerRace, playerClass, playerRealm)
    if not playerScore or playerScore < 0 then
        return nil, 0
    end
    
    local cache = HardcoreDeathraceDB.leaderboard or {}
    local index = HardcoreDeathraceDB.leaderboardIndex or {}
    
    -- Build list of all scores for realm-wide ranking
    local allScores = {}
    local raceScores = {}
    local classScores = {}
    
    for _, entry in ipairs(index) do
        local rec = cache[entry.name]
        if rec and rec.score then
            -- Realm-wide: all records from same realm
            if not playerRealm or rec.realm == playerRealm then
                table.insert(allScores, rec.score)
            end
            
            -- Race-specific: same race
            if playerRace and rec.race == playerRace then
                table.insert(raceScores, rec.score)
            end
            
            -- Class-specific: same class
            if playerClass and rec.class == playerClass then
                table.insert(classScores, rec.score)
            end
        end
    end
    
    -- Add current player's score to rankings (so they're included in the count)
    table.insert(allScores, playerScore)
    if playerRace then
        table.insert(raceScores, playerScore)
    end
    if playerClass then
        table.insert(classScores, playerScore)
    end
    
    -- Calculate realm-wide rank
    local realmRank = nil
    local realmTotal = #allScores
    if realmTotal > 0 then
        -- Sort scores descending (best first)
        table.sort(allScores, function(a, b) return a > b end)
        
        -- Find rank (how many players have a better score)
        realmRank = 1
        for i, score in ipairs(allScores) do
            if playerScore >= score then
                realmRank = i
                break
            end
            realmRank = i + 1
        end
    end
    
    -- Calculate race rank
    local raceRank = nil
    local raceTotal = #raceScores
    if raceTotal > 0 then
        table.sort(raceScores, function(a, b) return a > b end)
        raceRank = 1
        for i, score in ipairs(raceScores) do
            if playerScore >= score then
                raceRank = i
                break
            end
            raceRank = i + 1
        end
    end
    
    -- Calculate class rank
    local classRank = nil
    local classTotal = #classScores
    if classTotal > 0 then
        table.sort(classScores, function(a, b) return a > b end)
        classRank = 1
        for i, score in ipairs(classScores) do
            if playerScore >= score then
                classRank = i
                break
            end
            classRank = i + 1
        end
    end
    
    return {
        realmRank = realmRank,
        realmTotal = realmTotal,
        raceRank = raceRank,
        raceTotal = raceTotal,
        classRank = classRank,
        classTotal = classTotal,
    }
end

-- Stub functions for compatibility (if leaderboard system is being rebuilt)
function LB:BuildFailureRecord()
    return nil
end

function LB:BuildSuccessRecord()
    return nil
end

function LB:StoreRecord(record)
    return false
end

function LB:BroadcastRecord(record)
    -- Stub
end

function LB:Initialize()
    -- Stub
end

function LB:Toggle()
    -- Stub
end

-- Export functions
HardcoreDeathraceLeaderboard = LB
