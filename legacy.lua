

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









local function _FinalizeTarget(unit)
    -- 1. If a valid unit (mouseover or target) was found, use it.
    if unit and UnitExists(unit) then
        return unit
    end

    -- 2. If no unit exists, check for Auto Self-Cast.
    if fo_Settings.selfCastEnabled then
        -- Optional: Add a check here if you want to prevent self-casting
        -- offensive spells, but usually, WoW's internal logic handles the error.
        return "player"
    end

    -- 3. Otherwise, return nil.
    -- This prevents the "Glowing Hand" cursor which requires a manual click.
    return nil
end

local function _GetSmartTarget(spellName, forceMouseover)
    -- 1. If no mouseover exists, always default to "target"
    if not UnitExists("mouseover") then
        return "target"
    end

    -- 2. HELPFUL Case:
    -- If mouseover is a friend, prioritize it for buff/aura checks.
    if UnitCanAssist("player", "mouseover") then
        return "mouseover"
    end

    -- 3. HARMFUL Case:
    -- If mouseover is an enemy, only prioritize it if 'forceMouseover' is true.
    -- Otherwise, stick to "target" to avoid accidental de-targeting in combat.
    if UnitCanAttack("player", "mouseover") then
        if forceMouseover then
            return "mouseover"
        else
            return "target"
        end
    end

    -- Fallback to target for all other cases
    return "target"
end

--- Standard cast function with mouseover priority.
--- The main casting function called by macros.
-- @param spellName: Name of the spell to cast
-- @param forceMouseover: If true, ignores target and forces mouseover if it exists
function fo_cast(spellName, forceMouseover)
    if not spellName or spellName == "" then return end
    local lowerName = string.lower(spellName)

    -- [1] Run all registered filters
    -- If any filter returns false, the execution stops immediately
    for _, filterFunc in ipairs(fo_castFilters) do
        if filterFunc(lowerName) == false then
            return -- Blocked by a filter
        end
    end
    
    -- [2] If it ends with [Non-digit] + ")", append "()" to ensure Max Rank cast.
    if string.find(spellName, "[^0-9]%)$") and not string.find(spellName, "%(%)$") then
        spellName = spellName .. "()"
    end

    -- [3] TARGET ACQUISITION
    -- If the class handler allows the cast, we then find the best target.
    -- (Mouseover, Target, or Self based on priority)
    local u = _GetSmartTarget(spellName, forceMouseover)

    -- [4] FINAL EXECUTION
    -- Execute the spell on the determined target.
    local target = _FinalizeTarget(u)
    if target then
        CastSpellByName(spellName, target)
    end
end

-- Dual-purpose smart cast (Helpful/Harmful auto-selection) with mouseover priority and self-cast logic.
-- helpSpell: Spell for friendly targets. Skip if "" or nil.
-- harmSpell: Spell for enemy targets. Skip if "" or nil.
-- allowHarmMouseover: Optional, defaults to false.
function fo_smartCast(helpSpell, harmSpell, allowHarmMouseover)
    -- Handle default value for allowHarmMouseover
    if allowHarmMouseover == nil then allowHarmMouseover = false end

    -- Helper local function to check if a spell string is valid
    local function _isValid(s) return s and s ~= "" end

    -- 1. Check Mouseover: Prioritize Help
    if UnitExists("mouseover") then
        if _isValid(helpSpell) and UnitCanAssist("player", "mouseover") then
            fo_cast(helpSpell, true)
            return
        elseif _isValid(harmSpell) and allowHarmMouseover and UnitCanAttack("player", "mouseover") then
            fo_cast(harmSpell, true)
            return
        end
    end

    -- 2. Check Target
    if UnitExists("target") then
        if _isValid(helpSpell) and UnitCanAssist("player", "target") then
            fo_cast(helpSpell, false)
            return
        elseif _isValid(harmSpell) and UnitCanAttack("player", "target") then
            fo_cast(harmSpell, false)
            return
        end
    end

    -- 3. Fallback: Self-cast Help
    -- Only if helpSpell is provided and no hostile mouseover/target caught us
    if _isValid(helpSpell) then
        fo_cast(helpSpell, false)
    end
end





--- [Base/Manual] fo_RS(stat, op, val, unit)
-- @param unit: Optional (Defaults to "target")
function fo_RS(statType, operator, threshold, unit)
    unit = unit or "target"
    if not UnitExists(unit) then return false end

    local current, max
    statType = string.lower(statType)

    -- 1. Get stats with shorthand support
    -- "l" = Life(HP), "p" = Power(Mana, Rage, Energy)
    if statType == "l" or statType == "hp" or statType == "health" then
        current = UnitHealth(unit)
        max = UnitHealthMax(unit)
    elseif statType == "p" or statType == "mana" or statType == "rage" or statType == "energy" then
        current = UnitMana(unit)
        max = UnitManaMax(unit)
    else
        return false
    end

    -- 2. Threshold Analysis ("50%" vs 500)
    local targetVal
    if type(threshold) == "string" and string.find(threshold, "%%$") then
        local p = tonumber(string.sub(threshold, 1, -2))
        targetVal = (max * p) / 100
    else
        targetVal = tonumber(threshold)
    end

    if not targetVal or not current then return false end

    -- 3. Logic Comparison
    if operator == ">" then
        return current > targetVal
    elseif operator == "<" then
        return current < targetVal
    elseif operator == ">=" then
        return current >= targetVal
    elseif operator == "<=" then
        return current <= targetVal
    elseif operator == "==" then
        return current == targetVal
    end
    return false
end

--- [Self] fo_RSSelf(stat, op, val)
function fo_RSSelf(stat, op, val)
    return fo_RS(stat, op, val, "player")
end

--- [Smart] fo_RSSmart(stat, op, val, force)
function fo_RSSmart(stat, op, val, force)
    local unit = _GetSmartTarget("RSCheck", force)
    return fo_RS(stat, op, val, unit)
end










--- [INTERNAL UTILITY]
-- Evaluates if a given value represents a specific functional flag.
-- Handles Booleans, Numbers (1), and various shorthand Keywords.
-- @param val: The argument value to evaluate.
-- @param flagType: The category to check against ("self" or "mouse").
-- @return: Boolean true if the value matches the flag criteria.
local function _isFlag(val, flagType)
    -- Direct match for boolean true or number 1
    if val == true or val == 1 then return true end
    if type(val) ~= "string" then return false end

    local s = string.lower(val)
    if flagType == "self" then
        -- Keywords for forcing the cast on the player
        return (s == "s" or s == "self" or s == "player" or s == "p")
    elseif flagType == "mouse" then
        -- Keywords for enabling mouseover targeting for harmful spells
        return (s == "m" or s == "mouse" or s == "mouseover" or s == "mo")
    end
    return false
end

local function _GetSmartTarget(spellName, arg2, arg3)
    local forceSelf = false
    local forceMouse = false

    -- ARGUMENT NORMALIZATION:
    -- Iterate through optional arguments to identify intent regardless of their position.
    local inputs = { arg2, arg3 }
    for i = 1, 2 do
        local v = inputs[i]
        if _isFlag(v, "self") then
            forceSelf = true
        elseif _isFlag(v, "mouse") then
            forceMouse = true
        elseif v == true or v == 1 then
            -- Default behavior for generic truthy values (e.g., 1) is to enable mouseover.
            if not forceMouse then forceMouse = true end
        end
    end

    -- DECISION TREE:

    -- 1. Explicit Force Self: Overrides everything else.
    if forceSelf then return "player" end

    -- 2. Mouseover Logic:
    if UnitExists("mouseover") then
        -- Helpful spells always prioritize friendly mouseover.
        if UnitCanAssist("player", "mouseover") then
            return "mouseover"
        end
        -- Harmful spells only use mouseover if the flag is explicitly enabled.
        if UnitCanAttack("player", "mouseover") and forceMouse then
            return "mouseover"
        end
    end

    -- 3. Target Logic: Standard behavior if mouseover is not applicable.
    if UnitExists("target") then return "target" end

    -- 4. Global Fallback: Check if "Auto Self-Cast" is enabled in user settings.
    if fo_Settings and fo_Settings.selfCastEnabled then
        return "player"
    end

    -- Avoid "Glowing Hand" cursor by returning nil if no valid target is found.
    return nil
end





-- ==========================================================
-- RESOURCE CHECKER (Standardized)
-- ==========================================================

-- PUBLIC FUNCTION: Returns the absolute amount of missing HP
-- Usage: fo_lifeDeficit("target")
function fo_lifeDeficit(unitArg)
    -- Leverage our STS for unit determination
    local unit = _GetSmartTarget(nil, unitArg) or "player"
    if UnitExists(unit) then
        return UnitHealthMax(unit) - UnitHealth(unit)
    end
    return 0
end


-- [Base Engine] Internal logic
local function _ResourceLogic(input, arg2, arg3, unit)
    local stat, op, threshold
    
    -- 1. Smart Parsing (e.g., "l<20%" or "mana>500")
    if type(input) == "string" then
        -- Find the operator and split the string
        local _, _, s, o, v = string.find(input, "([^%s<>!=]+)%s*([<>!=]+)%s*(.*)")
        if s and o and v then
            stat, op, threshold = s, o, v
            unit = val2 or unit -- Shift unit to 2nd arg if parsing succeeded
        else
            stat, op, threshold = input, val2, val3
        end
    else
        stat, op, threshold = input, val2, val3
    end

    if not stat or not op or not threshold or not UnitExists(unit) then return false end

    -- 2. Normalize Stat Type (Aliases)
    stat = string.lower(stat)
    local isLife = (stat == "l" or stat == "life" or stat == "hp" or stat == "health")
    local isPower = (stat == "p" or stat == "pow" or stat == "power" or stat == "mana" or stat == "rage" or stat == "energy" or stat == "ene")

    local current, max
    if isLife then
        current, max = UnitHealth(unit), UnitHealthMax(unit)
    elseif isPower then
        current, max = UnitMana(unit), UnitManaMax(unit)
    else
        return false
    end

    -- 3. Threshold Analysis (Percentage support)
    local targetVal
    if type(threshold) == "string" and string.find(threshold, "%%$") then
        targetVal = (max * tonumber(string.sub(threshold, 1, -2))) / 100
    else
        targetVal = tonumber(threshold)
    end

    -- 4. Logic Comparison
    if op == ">" then return current > targetVal
    elseif op == "<" then return current < targetVal
    elseif op == ">=" then return current >= targetVal
    elseif op == "<=" then return current <= targetVal
    elseif op == "==" or op == "=" then return current == targetVal
    elseif op == "!=" or op == "~=" then return current ~= targetVal
    end
    return false
end

-- [Main] Smart Targeting: fo_RS(input, flag1, flag2)
function fo_RS(input, arg2, arg3)
    local unit = _GetSmartTarget("RSCheck", arg2, arg3)
    return _ResourceLogic(input, arg2, arg3, unit)
end

-- [Sub] Manual Targeting: fo_RSUnit(input, unit)
function fo_RSUnit(input, unit)
    return _ResourceLogic(input, nil, nil, unit or "target")
end