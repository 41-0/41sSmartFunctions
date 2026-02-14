-- ==========================================================
-- AURA SCANNER INITIALIZATION
-- ==========================================================
-- Create a hidden tooltip for scanning buff names
if not fo_scanner then
    fo_scanner = CreateFrame("GameTooltip", "FoAuraScanner", nil, "GameTooltipTemplate")
    fo_scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
end

-- keywords used to identify shapeshift forms in tooltips
FO_PROTECTED_KEYWORDS = { "Form", "Stance", "Seal", "Shapeshift" }

-- ==========================================================
-- SETTINGS INITIALIZATION
-- ==========================================================
fo_Settings = fo_Settings or {}
fo_ClassHandlers = fo_ClassHandlers or {}
-- This function ensures all settings have a default value
-- without overwriting existing user configurations.
local function InitializeSettings()
    -- 1. General Settings
    if fo_Settings.selfCastEnabled == nil then fo_Settings.selfCastEnabled = true end

    -- Druid Settings
    if fo_Settings.autoCancelForm == nil then fo_Settings.autoCancelForm = true end
    if fo_Settings.autoShapeshift == nil then fo_Settings.autoShapeshift = true end
    if fo_Settings.lockHumanForm == nil then fo_Settings.lockHumanForm = false end
    if fo_Settings.lockBearForm == nil then fo_Settings.lockBearForm = true end
    if fo_Settings.lockCatForm == nil then fo_Settings.lockCatForm = true end
    if fo_Settings.lockMoonkinForm == nil then fo_Settings.lockMoonkinForm = true end
    if fo_Settings.lockTreeForm == nil then fo_Settings.lockTreeForm = true end
    if fo_Settings.prioritizeBear == nil then fo_Settings.prioritizeBear = true end
end


--- Core logic for aura scanning using texture paths and tooltip text.
-- @param spellName: The pure name of the spell or a texture path segment.
-- @param unit: A valid WoW UnitID (e.g., "player", "target").
local function _CheckAuraByName(spellName, unit)
    -- Safety check for unit existence
    if not unit or not UnitExists(unit) then return false end
    
    local types = {"HELPFUL", "HARMFUL"}
    
    for _, auraType in pairs(types) do
        local i = 1
        while true do
            local texture
            if auraType == "HELPFUL" then
                texture = UnitBuff(unit, i)
            else
                texture = UnitDebuff(unit, i)
            end
            
            -- If no more auras, break the while loop
            if not texture then break end

            -- 1. Check by Texture Path (Fastest)
            -- Use plain search (true) to avoid magic character issues in paths
            if string.find(texture, spellName, 1, true) then
                return true
            end

            -- 2. Check by Tooltip Text (Fallback for specific names/ranks)
            -- Re-setting owner inside the loop is the most stable way in Vanilla
            fo_scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
            fo_scanner:ClearLines()
            
            if auraType == "HELPFUL" then
                fo_scanner:SetUnitBuff(unit, i)
            else
                fo_scanner:SetUnitDebuff(unit, i)
            end
            
            local tooltipText = FoAuraScannerTextLeft1:GetText()
            if tooltipText and tooltipText == spellName then
                return true
            end

            i = i + 1
            if i > 32 then break end -- Safety cap for Vanilla buff limits
        end
    end
    
    return false
end


--- Determines the best unit ID based on mouseover priority and spell type.
-- @param spellName: Used to determine if the spell is helpful or harmful (future proofing).
-- @param forceMouseover: If true, prioritizes mouseover even for harmful spells.
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

-- Handles the actual spell casting mechanics including auto-dismount and target switching
local function _DoCast(spellName, target)
    -- Ensure user is dismounted before casting
    if fo_dismount() then fo_dismount() end
    
    -- Fix for specific Feral spell syntax and casing
    local finalSpell = spellName
    local lowerName = string.lower(spellName)
    if lowerName == "faerie fire (feral)" or lowerName == "faerie fire (feral)()" then
        finalSpell = "Faerie Fire (Feral)()"
    end

    if target == "player" then
        CastSpellByName(finalSpell, 1) -- '1' enables self-cast
    elseif target and UnitExists(target) and target ~= "target" then
        local hadTarget = UnitExists("target")
        TargetUnit(target)
        CastSpellByName(finalSpell)
        if hadTarget then TargetLastTarget() else ClearTarget() end
    else
        CastSpellByName(finalSpell)
    end
end

-- Helper: Get current form name
function _GetShapeshiftForm()
    for i = 1, GetNumShapeshiftForms() do
        local _, name, active = GetShapeshiftFormInfo(i)
        if active then
            return name
        end
    end
    return "Human"
end

-- Helper: Cancel current shapeshift form
function fo_CancelCurrentForm()
    for i = 1, GetNumShapeshiftForms() do
        local _, _, active = GetShapeshiftFormInfo(i)
        if active then
            CastShapeshiftForm(i) -- Toggles off the current form
            return true
        end
    end
    return false
end

-- ==========================================================
-- Public API (Functions to use in Macros)
-- ==========================================================

-- ==========================================================
-- Aura Checker
-- ==========================================================
-- @param spellName: e.g., "Moonfire(Rank 1)" or "Moonfire"
-- @param unit: The unit to inspect. Accepts standard WoW unit IDs such as "target", "player", "pet", "party1", or "mouseover". Defaults to "target" if omitted.

-- 1. Manual Target Version (User-defined unit)
function fo_aura(spellName, unit)
    local targetUnit = unit or "target"
    local pureName = string.gsub(spellName, "%(Rank %d+%)", "")
    return _CheckAuraByName(pureName, targetUnit)
end

-- 2. Self-Only Version (Hardcoded to "player")
function fo_auraSelf(spellName)
    local pureName = string.gsub(spellName, "%(Rank %d+%)", "")
    return _CheckAuraByName(pureName, "player")
end

-- 3. Smart Target Version (Prioritizes mouseover)
function fo_auraSmart(spellName, forceMouseover)
    local u = _GetSmartTarget(spellName, forceMouseover)
    local pureName = string.gsub(spellName, "%(Rank %d+%)", "")
    return _CheckAuraByName(pureName, u)
end


-- ==========================================================
-- Resource CHECKER
-- ==========================================================

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
    if operator == ">" then return current > targetVal
    elseif operator == "<" then return current < targetVal
    elseif operator == ">=" then return current >= targetVal
    elseif operator == "<=" then return current <= targetVal
    elseif operator == "==" then return current == targetVal
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

-- ==========================================================
-- Dismount Logic 
-- ==========================================================
-- List of specific mount textures found on this server
FO_MOUNT_TEXTURES = { 
    "inv_pet_speedy", 
    "ability_mount_",
    "spell_nature_swiftness",
    "inv_misc_foot_01",
    "ability_druid_travelform",
    "ability_druid_aquaticform"
}
-- Dismount Protection - any buff if its NAME contains these words
FO_PROTECTED_KEYWORDS = { 
    "Form",    -- Cat Form, Bear Form, Moonkin Form, etc.
    "Aura",    -- Devotion Aura, Sanctity Aura, etc.
    "Stance",  -- Battle Stance, Defensive Stance, etc.
    "Stealth", -- Stealth, Prowl
    "Shadowform"
}

function fo_dismount()
    for i = 0, 31 do
        local id = GetPlayerBuff(i, "HELPFUL")
        -- Stop loop if no more buffs
        if id == -1 then break end
        
        -- 1. Only target buffs with NO time limit
        if GetPlayerBuffTimeLeft(id) == 0 then
            local texture = GetPlayerBuffTexture(id)
            if texture then
                local texLower = string.lower(texture)
                
                -- 2. Check if the texture matches our mount list
                local isMountCandidate = false
                for _, pattern in pairs(FO_MOUNT_TEXTURES) do
                    if string.find(texLower, string.lower(pattern)) then
                        isMountCandidate = true
                        break
                    end
                end

                if isMountCandidate then
                    -- 3. Retrieve buff name from tooltip for safety verification
                    fo_scanner:ClearLines()
                    fo_scanner:SetPlayerBuff(id)
                    local buffName = FoAuraScannerTextLeft1:GetText() or ""
                    local buffNameLower = string.lower(buffName)
                    
                    -- 4. Protection Logic
                    local isProtected = false
                    
                    -- EXCEPTION: "Travel Form" and "Aquatic Form" contain the word "form",
                    -- but we want them to be cancelled like regular mounts.
                    if buffNameLower ~= "travel form" and buffNameLower ~= "aquatic form" then
                        -- Check if any protected keywords exist in the buff name
                        for _, key in pairs(FO_PROTECTED_KEYWORDS) do
                            if string.find(buffNameLower, string.lower(key)) then 
                                isProtected = true 
                                break 
                            end
                        end
                    end

                    -- 5. Execution: Cancel only if it's a mount and NOT a protected form/aura
                    if not isProtected then
                        CancelPlayerBuff(id)
                        return true -- Dismount attempt successful
                    end
                end
            end
        end
    end
    return false -- No mount/removable form found
end


-- ==========================================================
-- Smart cast spell with mouseover override
-- ==========================================================

-- Global settings (Can be toggled via command)
-- selfCastEnabled = true 

--- Toggles the self-cast behavior when no target is selected.
function fo_toggleSelf()
    fo_Settings.selfCastEnabled = not fo_Settings.selfCastEnabled
    local status = fo_Settings.selfCastEnabled and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
    DEFAULT_CHAT_FRAME:AddMessage("41s_Utility: Self-Cast is now " .. status)
end

--- Determines the final target unit based on existence and self-cast settings.
-- @param unit: The candidate unit ID (e.g., "mouseover", "target")
-- @return: Valid unit ID or nil if casting should be aborted
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


--- Standard cast function with mouseover priority.
--- The main casting function called by macros.
-- @param spellName: Name of the spell to cast
-- @param forceMouseover: If true, ignores target and forces mouseover if it exists
function fo_cast(spellName, forceMouseover)
    if not spellName or spellName == "" then return end
    local lowerName = string.lower(spellName)
    -- [1] CLASS SPECIFIC LOGIC
    -- Check for form locks, permissions, and auto-shapeshift/cancel.
    local _, class = UnitClass("player")
    if fo_ClassHandlers[class] then
        -- If the handler returns false, it means we are shifting, 
        -- canceling form, or the action is locked. Stop execution.
        if not fo_ClassHandlers[class](lowerName) then
            return 
        end
    end

    -- [2] TARGET ACQUISITION
    -- If the class handler allows the cast, we then find the best target.
    -- (Mouseover, Target, or Self based on priority)
    local u = _GetSmartTarget(spellName, forceMouseover)
    
    -- [3] FINAL EXECUTION
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

-- ==========================================================
-- Debug Tool: Show all textures on your current target
-- ==========================================================
function fo_showTargetTexture()
    local unit = "target"
    if not UnitExists(unit) then 
        DEFAULT_CHAT_FRAME:AddMessage("No target selected.")
        return 
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff--- Target Buff/Debuff Textures ---|r")
    
    local types = {"HELPFUL", "HARMFUL"}
    for _, auraType in pairs(types) do
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[" .. auraType .. "]|r")
        for i = 1, 32 do
            local texture
            if auraType == "HELPFUL" then
                texture = UnitBuff(unit, i)
            else
                texture = UnitDebuff(unit, i)
            end
            
            if not texture then break end
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffff00[%d]|r %s", i, texture))
        end
    end
end



-- ==========================================================
-- EVENT HANDLER FOR DATA LOADING
-- ==========================================================

-- We must wait for 'VARIABLES_LOADED' to ensure that 
-- SavedVariables are fully loaded from the server/disk 
-- before we check or apply default values.
local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
    InitializeSettings()
    -- Optional: Print a message to the console for debugging
    -- DEFAULT_CHAT_FRAME:AddMessage("Gemini Cast: Settings Loaded.")
end)