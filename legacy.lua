

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






-- _GUI.lua

-- -- --- Announcer Tab ---
-- local AnnouncePanel = CreateClassPanel("ANNOUNCE")
-- CreateTabButton(2, "Announce", "ANNOUNCE", 75) -- Positioned next to Druid Tab

-- -- Tab Description
-- AddPanelDescription(AnnouncePanel, "Settings for Spell Announcer.\nCast registration: Announces both success and failure.\nFail registration: Announces ONLY full resists/misses.")

-- -- 1. Master Toggles (Top Section)
-- local Ann_DoCasts_CB = CreateFrame("CheckButton", "fo_CB_Ann_DoCasts", AnnouncePanel, "UICheckButtonTemplate")
-- Ann_DoCasts_CB:SetPoint("TOPLEFT", AnnouncePanel, "TOPLEFT", 20, -75)
-- _G[Ann_DoCasts_CB:GetName().."Text"]:SetText("Enable Cast Announcements")
-- Ann_DoCasts_CB:SetChecked(fo_Settings.announcerDoCasts)
-- Ann_DoCasts_CB:SetScript("OnClick", function() fo_Settings.announcerDoCasts = this:GetChecked() and true or false end)

-- local Ann_DoFails_CB = CreateFrame("CheckButton", "fo_CB_Ann_DoFails", AnnouncePanel, "UICheckButtonTemplate")
-- Ann_DoFails_CB:SetPoint("TOPLEFT", AnnouncePanel, "TOPLEFT", 220, -75)
-- _G[Ann_DoFails_CB:GetName().."Text"]:SetText("Enable Failure Announcements")
-- Ann_DoFails_CB:SetChecked(fo_Settings.announcerDoFails)
-- Ann_DoFails_CB:SetScript("OnClick", function() fo_Settings.announcerDoFails = this:GetChecked() and true or false end)

-- -- 2. Input Section
-- local inputLabel = AnnouncePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
-- inputLabel:SetPoint("TOPLEFT", AnnouncePanel, "TOPLEFT", 25, -110)
-- inputLabel:SetText("Register New Spell (e.g., Taunt):")

-- -- Using your background style for the EditBox
-- local inputBg = CreateFrame("Frame", "fo_Ann_InputBg", AnnouncePanel)
-- inputBg:SetWidth(180); inputBg:SetHeight(24)
-- inputBg:SetPoint("TOPLEFT", AnnouncePanel, "TOPLEFT", 25, -130)
-- inputBg:SetBackdrop({bgFile = "Interface\\Buttons\\White8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
--                     tile = true, tileSize = 16, edgeSize = 12, insets = {left=3, right=3, top=3, bottom=3}})
-- inputBg:SetBackdropColor(0, 0, 0, 0.5)

-- local spellInput = CreateFrame("EditBox", "fo_Ann_SpellInput", inputBg)
-- spellInput:SetWidth(170); spellInput:SetHeight(20); spellInput:SetPoint("CENTER", inputBg, "CENTER", 0, 0)
-- spellInput:SetFontObject("GameFontHighlightSmall")
-- spellInput:SetAutoFocus(false)
-- spellInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)

-- -- Function to Add Spells (Logic)
-- local function RegisterSpell(listType)
--     local spell = string.lower(spellInput:GetText())
--     if spell ~= "" then
--         if listType == "cast" then
--             fo_Settings.announcerDict.casts[spell] = true
--             DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Announcer]|r Added '"..spell.."' to Cast list.")
--         else
--             fo_Settings.announcerDict.fails[spell] = true
--             DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Announcer]|r Added '"..spell.."' to Fail list.")
--         end
--         spellInput:SetText("")
--         spellInput:ClearFocus()
--         -- Note: List refreshing logic would go here
--     end
-- end

-- -- Button: Add to Casts
-- local addCastBtn = CreateFrame("Button", nil, AnnouncePanel, "UIPanelButtonTemplate")
-- addCastBtn:SetWidth(100); addCastBtn:SetHeight(24)
-- addCastBtn:SetPoint("LEFT", inputBg, "RIGHT", 10, 0)
-- addCastBtn:SetText("Add Cast")
-- -- addCastBtn:SetScript("OnClick", function() RegisterSpell("cast") end)
-- addCastBtn:SetScript("OnClick", function() 
--     RegisterSpell("cast", spellInput:GetText())
--     spellInput:SetText("") 
-- end)

-- -- Button: Add to Fails
-- local addFailBtn = CreateFrame("Button", nil, AnnouncePanel, "UIPanelButtonTemplate")
-- addFailBtn:SetWidth(100); addFailBtn:SetHeight(24)
-- addFailBtn:SetPoint("LEFT", addCastBtn, "RIGHT", 5, 0)
-- addFailBtn:SetText("Add Fail")
-- -- addFailBtn:SetScript("OnClick", function() RegisterSpell("fail") end)
-- addFailBtn:SetScript("OnClick", function() 
--     RegisterSpell("fail", spellInput:GetText())
--     spellInput:SetText("") 
-- end)

-- -- 3. List Guide
-- AddSnippetGuide(AnnouncePanel, "--- Currently Registered Spells (Use /foa list to see all) ---")

-- -- Future: You can add a ScrollFrame here to list and delete spells visually.
