

-- -- Handles the actual spell casting mechanics including auto-dismount and target switching
-- local function _DoCast(spellName, target)
--     -- Ensure user is dismounted before casting
--     if fo_dismount() then fo_dismount() end

--     -- Fix for specific Feral spell syntax and casing
--     local finalSpell = spellName
--     local lowerName = string.lower(spellName)
--     if lowerName == "faerie fire (feral)" or lowerName == "faerie fire (feral)()" then
--         finalSpell = "Faerie Fire (Feral)()"
--     end

--     if target == "player" then
--         CastSpellByName(finalSpell, 1) -- '1' enables self-cast
--     elseif target and UnitExists(target) and target ~= "target" then
--         local hadTarget = UnitExists("target")
--         TargetUnit(target)
--         CastSpellByName(finalSpell)
--         if hadTarget then TargetLastTarget() else ClearTarget() end
--     else
--         CastSpellByName(finalSpell)
--     end
-- end

-- -- Helper: Get current form name
-- function _GetShapeshiftForm()
--     for i = 1, GetNumShapeshiftForms() do
--         local _, name, active = GetShapeshiftFormInfo(i)
--         if active then
--             return name
--         end
--     end
--     return "Human"
-- end

-- -- Helper: Cancel current shapeshift form
-- function fo_CancelCurrentForm()
--     for i = 1, GetNumShapeshiftForms() do
--         local _, _, active = GetShapeshiftFormInfo(i)
--         if active then
--             CastShapeshiftForm(i) -- Toggles off the current form
--             return true
--         end
--     end
--     return false
-- end


-- ==========================================================
-- Spell Announcer: Logic & Registration
-- ==========================================================

-- Helper: Converts "healing touch" to "Healing Touch"
local function ToTitleCase(str)
    return (string.gsub(str, "%f[%a]%a", string.upper))
end

-- Helper: Determines the best chat channel
local function GetBestChannel()
    if GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers() > 0 then return "PARTY" end
    return "PRINT"
end

-- Centralized function to register spells (Used by both GUI and CLI)
-- local function RegisterSpell(listType, spellName)
--     if not spellName or spellName == "" then return end

--     local key = string.lower(spellName)

--     -- Ensure the nested data structure exists
--     if not fo_Settings.announcerDict then
--         fo_Settings.announcerDict = { casts = {}, fails = {} }
--     end
--     if not fo_Settings.announcerDict.casts then fo_Settings.announcerDict.casts = {} end
--     if not fo_Settings.announcerDict.fails then fo_Settings.announcerDict.fails = {} end

--     if listType == "cast" then
--         fo_Settings.announcerDict.casts[key] = true
--         DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Announcer]|r Added '" ..
--         ToTitleCase(key) .. "' to [Casts] (All Results).")
--     elseif listType == "fail" then
--         fo_Settings.announcerDict.fails[key] = true
--         DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Announcer]|r Added '" ..
--         ToTitleCase(key) .. "' to [Fails] (Failures Only).")
--     end
-- end

-- Main execution: Process combat log messages
local function ExecuteTauntAnnounce(combatLogMsg)
    -- Guard: Check if the feature is enabled
    if not fo_Settings.announceTauntResist then return end

    local lowerLog = string.lower(combatLogMsg)

    -- 1. Identify if a taunt spell is in the log
    local foundSpell = nil
    for spell, _ in pairs(fo_Settings.tauntSpells) do
        if string.find(lowerLog, spell) then
            foundSpell = spell
            break
        end
    end

    if not foundSpell then return end

    -- 2. Detect failure types (Resist, Miss, Dodge, etc.)
    local failureKeywords = { "resisted", "missed", "dodged", "parried", "immune" }
    local foundFail = nil
    for _, word in pairs(failureKeywords) do
        if string.find(lowerLog, word) then
            foundFail = string.upper(word)
            break
        end
    end

    -- 3. Output announcement if a failure occurred
    if foundFail then
        local displayName = "[" .. ToTitleCase(foundSpell) .. "]"
        local finalMsg = displayName .. " " .. foundFail .. "!"

        local channel = GetBestChannel()
        if channel == "PRINT" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Taunt Alert]:|r " .. finalMsg)
        else
            SendChatMessage(finalMsg, channel)
        end
    end
end




-- -- Slash Command Handler
-- SLASH_FOANNOUNCE1 = "/foa"
-- SlashCmdList["FOANNOUNCE"] = function(msg)
--     local _, _, action, subAction, rest = string.find(msg, "(%S+)%s*(%S+)%s*(.*)")
--     action = action and string.lower(action) or ""
--     subAction = subAction and string.lower(subAction) or ""
--     rest = rest and string.lower(rest) or ""

--     -- Default: Show GUI
--     if action == "" then
--         if fo_ConfigWindow then fo_ConfigWindow:Show() end
--         return
--     end

--     -- CASE: LIST
--     if action == "list" then
--         DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Announcer List]|r")
--         if not fo_Settings.announcerDict or not fo_Settings.announcerDict.casts then
--             DEFAULT_CHAT_FRAME:AddMessage(" No spells registered.")
--             return
--         end
--         for k in pairs(fo_Settings.announcerDict.casts) do DEFAULT_CHAT_FRAME:AddMessage(" [Cast] " .. ToTitleCase(k)) end
--         for k in pairs(fo_Settings.announcerDict.fails) do DEFAULT_CHAT_FRAME:AddMessage(" [Fail] " .. ToTitleCase(k)) end
--         return
--     end

--     -- CASE: ADD
--     if action == "add" then
--         if (subAction == "cast" or subAction == "fail") and rest ~= "" then
--             RegisterSpell(subAction, rest)
--         else
--             DEFAULT_CHAT_FRAME:AddMessage("Usage: /foa add cast/fail [spellname]")
--         end
--         return
--     end

--     -- CASE: REMOVE
--     if action == "rem" or action == "del" then
--         if rest == "all" then
--             fo_Settings.announcerDict = { casts = {}, fails = {} }
--             DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Announcer] Cleared all spells.|r")
--         elseif rest ~= "" then
--             local key = string.lower(rest)
--             fo_Settings.announcerDict.casts[key] = nil
--             fo_Settings.announcerDict.fails[key] = nil
--             DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Announcer] Removed:|r " .. ToTitleCase(key))
--         end
--         return
--     end
-- end


