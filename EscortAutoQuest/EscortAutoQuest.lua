local ADDON_NAME = "EscortAutoQuest"
local EscortAutoQuest = CreateFrame("Frame")

-- ==========================================================================
-- CONFIGURATION
-- ==========================================================================

-- Quests that will be automatically accepted and turned in.
-- Use either a numeric quest ID or the exact quest title.
-- NOTE: classic gossip windows do not expose quest IDs, so titles are what
-- actually match there. IDs are used where the client provides them.
local PREREQ_QUESTS = {
    -- Razorfen Downs
    [3523] = true,                       -- Scourge of the Downs
    ["Scourge of the Downs"] = true,

    -- Blackrock Depths, Alliance / Onyxia attunement chain
    [4282] = true,                       -- A Shred of Hope
    ["A Shred of Hope"] = true,

    -- OOX-17/TN, Tanaris
    [351] = true,                        -- Find OOX-17/TN!
    ["Find OOX-17/TN!"] = true,

    -- OOX-09/HL, Hinterlands
    [485] = true,                        -- Find OOX-09/HL!
    ["Find OOX-09/HL!"] = true,

    -- OOX-22/FE, Feralas
    [2766] = true,                       -- Find OOX-22/FE!
    ["Find OOX-22/FE!"] = true,

    -- Dustwallow Marsh, Horde Black Shield chain
    -- Turn in this quest; Ogron then offers the escort follow-up.
    ["Lieutenant Paval Reethe"] = true,

    -- Feralas, Wandering Shay escort
    ["The Giant Guardian"] = true,

    -- OPTIONAL: level 60 quest chain, Western Plaguelands
    -- Uncomment these two lines only if you want the addon to handle it.
    -- [5862] = true,                    -- Scarlet Subterfuge
    -- ["Scarlet Subterfuge"] = true,
}

-- Escort quests that must never be accepted automatically.
local ESCORT_QUESTS = {
    -- Razorfen Downs
    [3525] = true,                       -- Extinguishing the Idol
    ["Extinguishing the Idol"] = true,

    -- Blackrock Depths
    [4322] = true,                       -- Jail Break!
    ["Jail Break!"] = true,

    -- OOX escorts
    [648] = true,                        -- Rescue OOX-17/TN!
    ["Rescue OOX-17/TN!"] = true,

    [836] = true,                        -- Rescue OOX-09/HL!
    ["Rescue OOX-09/HL!"] = true,

    [2767] = true,                       -- Rescue OOX-22/FE!
    ["Rescue OOX-22/FE!"] = true,

    -- Dustwallow Marsh
    [1273] = true,                       -- Questioning Reethe
    ["Questioning Reethe"] = true,

    -- Feralas
    [2845] = true,                       -- Wandering Shay
    ["Wandering Shay"] = true,

    -- OPTIONAL: level 60 escort
    -- [5944] = true,                    -- In Dreams
    -- ["In Dreams"] = true,
}

local ENABLE_DEBUG = false
local ENABLED = true

-- ==========================================================================
-- INTERNAL STATE
-- ==========================================================================

local lastTurnedIn = nil

-- ==========================================================================
-- HELPERS
-- ==========================================================================

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00ff00Escort Auto Quest:|r " .. tostring(message)
        )
    end
end

local function Debug(message)
    if ENABLE_DEBUG then
        Print("|cffaaaaaa[debug]|r " .. tostring(message))
    end
end

local function IsPrerequisite(questID, questTitle)
    if questID and PREREQ_QUESTS[questID] then
        return true
    end

    if questTitle and PREREQ_QUESTS[questTitle] then
        return true
    end

    return false
end

local function IsEscortQuest(questID, questTitle)
    if questID and ESCORT_QUESTS[questID] then
        return true
    end

    if questTitle and ESCORT_QUESTS[questTitle] then
        return true
    end

    return false
end

-- GetQuestID() is missing on some clients and returns 0 when unknown.
local function CurrentQuestID()
    if GetQuestID then
        local id = GetQuestID()
        if id and id ~= 0 then
            return id
        end
    end

    return nil
end

-- Returns a normalised list of quests in the open gossip window.
-- kind is "available" (quests you can pick up) or "active" (quests already in
-- your log, which is where a turn-in lives).
-- Each entry: { title, questID (may be nil), isComplete, index }
local function GetGossipQuests(kind)
    local list = {}

    -- Newer clients: C_GossipInfo returns tables with real quest IDs.
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetActiveQuests then
        local source
        if kind == "available" then
            source = C_GossipInfo.GetAvailableQuests()
        else
            source = C_GossipInfo.GetActiveQuests()
        end

        for i, q in ipairs(source or {}) do
            list[#list + 1] = {
                title = q.title,
                questID = q.questID,
                isComplete = q.isComplete,
                index = i,
            }
        end

        return list
    end

    -- Legacy clients: flat list of return values, stride varies by client,
    -- so work it out from the number of quests rather than hard-coding it.
    local getter, counter
    if kind == "available" then
        getter, counter = GetGossipAvailableQuests, GetNumGossipAvailableQuests
    else
        getter, counter = GetGossipActiveQuests, GetNumGossipActiveQuests
    end

    if not getter or not counter then
        return list
    end

    local count = counter() or 0
    if count == 0 then
        return list
    end

    local total = select("#", getter())
    local raw = { getter() }
    local stride = math.floor(total / count)

    for i = 1, count do
        local base = (i - 1) * stride
        list[#list + 1] = {
            title = raw[base + 1],
            -- active quests: title, level, isTrivial, isComplete, ...
            isComplete = (kind == "active") and raw[base + 4] or nil,
            index = i,
        }
    end

    return list
end

local function SelectGossipQuest(kind, quest)
    if C_GossipInfo and C_GossipInfo.SelectAvailableQuest and quest.questID then
        if kind == "available" then
            C_GossipInfo.SelectAvailableQuest(quest.questID)
        else
            C_GossipInfo.SelectActiveQuest(quest.questID)
        end
    elseif kind == "available" then
        SelectGossipAvailableQuest(quest.index)
    else
        SelectGossipActiveQuest(quest.index)
    end
end

-- Finds a whitelisted prerequisite in the gossip window. Turn-ins (active,
-- completed quests) are checked first, then pick-ups (available quests).
local function HandleGossip()
    for _, kind in ipairs({ "active", "available" }) do
        for _, quest in ipairs(GetGossipQuests(kind)) do
            if IsPrerequisite(quest.questID, quest.title)
                and not IsEscortQuest(quest.questID, quest.title)
                and (kind == "available" or quest.isComplete)
            then
                Debug("Selecting " .. kind .. " prerequisite: " .. tostring(quest.title or quest.questID))
                SelectGossipQuest(kind, quest)
                return
            end
        end
    end
end

-- ==========================================================================
-- EVENT HANDLING
-- ==========================================================================

EscortAutoQuest:RegisterEvent("GOSSIP_SHOW")
EscortAutoQuest:RegisterEvent("QUEST_DETAIL")
EscortAutoQuest:RegisterEvent("QUEST_PROGRESS")
EscortAutoQuest:RegisterEvent("QUEST_COMPLETE")
EscortAutoQuest:RegisterEvent("QUEST_FINISHED")

EscortAutoQuest:SetScript("OnEvent", function(self, event)
    -- Hold Shift to do things manually.
    if not ENABLED or IsShiftKeyDown() then
        return
    end

    if event == "GOSSIP_SHOW" then
        HandleGossip()

    elseif event == "QUEST_DETAIL" then
        local questID = CurrentQuestID()
        local title = GetTitleText()

        -- Never accept an escort quest. Closing the window leaves it
        -- available, so the "start escort" popup can appear when another
        -- party member starts it.
        if IsEscortQuest(questID, title) then
            Print("Skipped escort quest: " .. tostring(title or questID))
            DeclineQuest()
            return
        end

        if IsPrerequisite(questID, title) then
            Debug("Accepting prerequisite: " .. tostring(title or questID))
            AcceptQuest()
        end

    elseif event == "QUEST_PROGRESS" then
        local questID = CurrentQuestID()
        local title = GetTitleText()

        if IsPrerequisite(questID, title) and not IsEscortQuest(questID, title) then
            if IsQuestCompletable() then
                Debug("Completing prerequisite: " .. tostring(title or questID))
                CompleteQuest()
            else
                Debug("Prerequisite not yet completable: " .. tostring(title or questID))
            end
        end

    elseif event == "QUEST_COMPLETE" then
        local questID = CurrentQuestID()
        local title = GetTitleText()

        if IsPrerequisite(questID, title) and not IsEscortQuest(questID, title) then
            -- GetQuestReward errors if there is a choice and none is made,
            -- so leave those for the player to pick.
            if (GetNumQuestChoices() or 0) > 1 then
                Print("Pick a reward to finish: " .. tostring(title or questID))
                return
            end

            lastTurnedIn = title or questID
            Debug("Claiming reward for prerequisite: " .. tostring(lastTurnedIn))
            GetQuestReward(1)
        end

    elseif event == "QUEST_FINISHED" then
        if lastTurnedIn then
            Print("Prerequisite turned in: " .. tostring(lastTurnedIn))
            lastTurnedIn = nil
        end
    end
end)

-- ==========================================================================
-- SLASH COMMANDS
-- ==========================================================================

SLASH_ESCORTAUTOQUEST1 = "/escortauto"
SLASH_ESCORTAUTOQUEST2 = "/eaq"

SlashCmdList["ESCORTAUTOQUEST"] = function(message)
    message = string.lower(message or "")

    if message == "debug" then
        ENABLE_DEBUG = not ENABLE_DEBUG
        Print("Debug mode is now " .. (ENABLE_DEBUG and "ON" or "OFF"))
        return
    end

    if message == "toggle" then
        ENABLED = not ENABLED
        Print("Addon is now " .. (ENABLED and "ON" or "OFF"))
        return
    end

    Print("Loaded (" .. (ENABLED and "ON" or "OFF") .. "). Escort prerequisites are handled automatically.")
    Print("Escort quests themselves are never accepted. Hold Shift to bypass the addon.")
    Print("Commands: /eaq debug, /eaq toggle")
end
