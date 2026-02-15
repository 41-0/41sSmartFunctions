-- ==========================================================
-- SCANNER INITIALIZATION
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
-- This function ensures all settings have a default value
-- without overwriting existing user configurations.

local function InitializeSettings()
    -- 1. General Settings
    if fo_Settings.selfCastEnabled == nil then fo_Settings.selfCastEnabled = true end

    -- Druid Settings (Existing)
    if fo_Settings.autoCancelForm == nil then fo_Settings.autoCancelForm = true end
    if fo_Settings.autoShapeshift == nil then fo_Settings.autoShapeshift = true end
    if fo_Settings.lockHumanForm == nil then fo_Settings.lockHumanForm = false end
    if fo_Settings.lockBearForm == nil then fo_Settings.lockBearForm = true end
    if fo_Settings.lockCatForm == nil then fo_Settings.lockCatForm = true end
    if fo_Settings.lockMoonkinForm == nil then fo_Settings.lockMoonkinForm = true end
    if fo_Settings.lockTreeForm == nil then fo_Settings.lockTreeForm = true end
    if fo_Settings.prioritizeBear == nil then fo_Settings.prioritizeBear = true end

    -- [[ NEW: Frenzied Regeneration Management ]] --
    if fo_Settings.preventRageWasteDuringFR == nil then 
        fo_Settings.preventRageWasteDuringFR = true 
    end
    if fo_Settings.frenziedRegenThreshold == nil then 
        fo_Settings.frenziedRegenThreshold = 80 
    end

    -- [[ NEW: Rage Spells Table ]] --
    -- This table must exist for the filter to look up spell names
    if fo_Settings.rageSpells == nil then
        fo_Settings.rageSpells = {
            ["maul"] = true,
            ["swipe"] = true,
        }
    end
end

--- Core logic for aura scanning using texture paths and tooltip text.
-- @param spellName: The pure name of the spell or a texture path segment.
-- @param unit: A valid WoW UnitID (e.g., "player", "target").
local function _CheckAuraByName(spellName, unit)
    if not unit or not UnitExists(unit) then return false end
    
    -- Search name is pre-lowered for consistency
    local searchName = strlower(spellName)
    local types = {"HELPFUL", "HARMFUL"}
    
    for _, auraType in pairs(types) do
        local i = 1
        while true do
            local texture = (auraType == "HELPFUL") and UnitBuff(unit, i) or UnitDebuff(unit, i)
            if not texture then break end

            -- 1. Check by Texture Path (Normalize to lowercase)
            if string.find(strlower(texture), searchName, 1, true) then
                return true
            end

            -- 2. Check by Tooltip Text (Normalize to lowercase)
            fo_scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
            fo_scanner:ClearLines()
            if auraType == "HELPFUL" then fo_scanner:SetUnitBuff(unit, i) else fo_scanner:SetUnitDebuff(unit, i) end
            
            local tooltipText = FoAuraScannerTextLeft1:GetText()
            if tooltipText and strlower(tooltipText) == searchName then
                return true
            end

            i = i + 1
            if i > 32 then break end
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
-- Smart cast spell with mouseover override
-- ==========================================================

-- Interceptor
fo_castFilters = {}
function fo_registerFilter(func)
    table.insert(fo_castFilters, func)
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
   
    -- 1. Run all registered filters
    -- If any filter returns false, the execution stops immediately
    for _, filterFunc in ipairs(fo_castFilters) do
        if filterFunc(lowerName) == false then
            return -- Blocked by a filter
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
-- Coolddown Checker
-- ==========================================================
-- Returns true ONLY if the spell is on a real cooldown (longer than the GCD).
-- Useful for skipping spells that are not ready yet.
function fo_isCD(spellName)
    local searchName = string.lower(spellName)
    local i = 1
    
    -- Scan the spellbook for the specified spell
    while true do
        local name = GetSpellName(i, "spell")
        if not name then break end -- Exit if we've reached the end of the spellbook
        
        -- Case-insensitive match
        if string.lower(name) == searchName then
            local _, duration = GetSpellCooldown(i, "spell")
            
            -- If duration is greater than 1.5 seconds, it's a real cooldown.
            -- If it's 0 or <= 1.5, it's either ready or just the Global Cooldown.
            return (duration > 1.5)
        end
        i = i + 1
    end
    
    -- Return false if the spell doesn't exist (cannot be on cooldown)
    return false
end


-- ==========================================================
-- Equipment Checker
-- ==========================================================

-- Internal helper to scan tooltips for specific keywords.
local function fo_scanFor(slotID, keyword)
-- 0. Absolute Safety: Check if the player is currently in a state 
    -- where scanning might be dangerous (like during a talent reset).
    -- In Vanilla, checking if we have a valid unit name can be a quick sanity check.
    if not UnitName("player") then return false end

    -- 1. Existing link check
    if not GetInventoryItemLink("player", slotID) then return false end

    -- Safety Check: Ensure the scanner object is initialized.
    if not fo_scanner or not fo_scanner.SetInventoryItem then
        return false
    end

    fo_scanner:ClearLines()

    -- Use pcall (protected call) to prevent crash if memory is unstable.
    local ok, hasItem = pcall(function() 
        return fo_scanner:SetInventoryItem("player", slotID) 
    end)

    if not ok or not hasItem then return false end

    for i = 1, 5 do
        local leftObj = getglobal("FoAuraScannerTextLeft"..i)
        if leftObj then
            local left = leftObj:GetText()
            local rightObj = getglobal("FoAuraScannerTextRight"..i)
            local right = (rightObj and rightObj:GetText()) or ""
            
            -- Case-insensitive and plain text search for reliability
            local content = string.lower((left or "")..right)
            local k = string.lower(keyword)

            if string.find(content, k, 1, true) then 
                return true 
            end
        end
    end
    return false
end




-- Returns true if a Shield is equipped
function fo_hasShield()
    return fo_scanFor(17, "Shield")
end

-- Returns true if a Two-Handed weapon is equipped
function fo_has2H()
    -- Check for "Two-Hand" (matches Two-Handed too)
    return fo_scanFor(16, "Two-Hand")
end

-- Returns true if Dual-Wielding weapons
function fo_hasDW()
    -- 1. Check Main-hand (Slot 16)
    local mainItem = GetInventoryItemLink("player", 16)
    if not mainItem then return false end -- Main hand is empty
    
    -- 2. Check Off-hand (Slot 17)
    local offItem = GetInventoryItemLink("player", 17)
    if not offItem or fo_hasShield() then return false end -- Off-hand is empty or a shield

    -- 3. Verify Off-hand is actually a weapon (Excluding "Held in Off-hand" items)
    local weaponTypes = {"One-Hand", "Dagger", "Sword", "Axe", "Mace", "Fist"}
    for _, wType in ipairs(weaponTypes) do
        if fo_scanFor(17, wType) then
            return true
        end
    end
    
    return false
end


-- ==========================================================
-- Spell Checker
-- ==========================================================

-- Returns true if the spell is found in the player's spellbook.
-- Useful for talent-based logic or class-specific checks.
function fo_hasSpell(spellName)
    local sName = string.lower(spellName)
    local i = 1
    while true do
        local name = GetSpellName(i, "spell")
        if not name then break end
        if string.lower(name) == sName then 
            return true 
        end
        i = i + 1
    end
    return false
end


-- ==========================================================
-- Combat Utilities
-- ==========================================================

-- Returns true if the player is Stealthed or Shadowmelded.
-- Uses both name and texture checks for maximum reliability in Vanilla 1.12.
function fo_isStealth()
    -- Check common stealth/shadowmeld names and textures
    return fo_auraSelf("Stealth")
        or fo_auraSelf("Shadowmeld")
        or fo_auraSelf("Prowl")
        or fo_auraSelf("Ability_Stealth")
        or fo_auraSelf("Ability_Ambush")
end

-- Spamsafe stealth entry with Form-awareness for Druids.
function fo_startStealth()
    if fo_isStealth() then return end

    -- 1. Druid Check: If in Cat Form, ONLY try Prowl.
    if fo_isCat and fo_isCat() then
        if fo_hasSpell("Prowl") then
            CastSpellByName("Prowl")
            return
        end
        -- Note: If we are a Cat but don't have Prowl yet, 
        -- we still shouldn't use Shadowmeld here (usually).
    
    -- 2. Non-Cat states (Humanoid, etc.)
    else
        -- Prioritize Rogue Stealth first
        if fo_hasSpell("Stealth") then
            CastSpellByName("Stealth")
            return
        end
        
        -- Finally, use Shadowmeld if available
        if fo_hasSpell("Shadowmeld") then
            CastSpellByName("Shadowmeld")
            return
        end
    end
end


-- Checks if the player is currently auto-attacking.
function fo_isAttacking()
    for i = 1, 120 do
        if IsAttackAction(i) and IsCurrentAction(i) then
            return true
        end
    end
    return false
end

-- Starts auto-attack without toggling off.
-- Does not break Stealth/Shadowmeld unless 'force' is provided.
function fo_startAttack(force)
    -- Logic: Attack only if not stealthed, OR if force is requested.
    if not fo_isStealth() or force then
        if not fo_isAttacking() then
            AttackTarget()
        end
    end
end

-- Helper: Checks if any "Auto Repeat" action (like Shoot or Auto Shot) is currently active.
function fo_isShooting()
    for i = 1, 120 do
        if IsAutoRepeatAction(i) and IsCurrentAction(i) then
            return true
        end
    end
    return false
end


function fo_startShoot()
    if fo_isShooting() then return end

    fo_scanner:ClearLines()
    if not fo_scanner:SetInventoryItem("player", 18) then return end

    local spell = nil
    for i = 1, 5 do
        local left = getglobal("FoAuraScannerTextLeft"..i):GetText()
        local right = getglobal("FoAuraScannerTextRight"..i):GetText()
        local content = (left or "")..(right or "")
        
        if string.find(content, "Wand") then spell = "Shoot"; break
        elseif string.find(content, "Crossbow") then spell = "Shoot Crossbow"; break
        elseif string.find(content, "Bow") then spell = "Shoot Bow"; break
        elseif string.find(content, "Gun") then spell = "Shoot Gun"; break
        end
    end

    if spell then CastSpellByName(spell) end
end


-- Stops all current actions: Spell casting, Channeling, Auto-Attack, and Shooting.
function fo_stopAll()
    -- 1. Stop Spell Casting & Channeling
    SpellStopCasting()
    
    -- 2. Stop Auto-Attack (if active)
    if fo_isAttacking() then
        AttackTarget()
    end
    
    -- 3. Stop Auto-Shot / Wand Shooting
    -- In 1.12, 'Shoot' and 'Auto Shot' are toggles. 
    -- We check the action bar to see if they are active before toggling them off.
    if fo_isShooting() then
        -- This logic assumes 'Shoot' or 'Auto Shot' is on your action bar.
        -- If it's a wand, SpellStopCasting often handles it, but this is safer:
        SpellStopCasting() 
    end
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
-- EVENT HANDLER FOR DATA LOADING
-- ==========================================================

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
    -- 1. Ensure the saved variable table exists
    fo_Settings = fo_Settings or {}

    -- 2. Automatically merge all defaults from fo_DefaultSettings
    -- This replaces the need for manual InitializeSettings()
    if fo_DefaultSettings then
        for key, value in pairs(fo_DefaultSettings) do
            -- If the setting is a table (like rageSpells), handle it as a sub-merge
            if type(value) == "table" then
                fo_Settings[key] = fo_Settings[key] or {}
                for subKey, subValue in pairs(value) do
                    if fo_Settings[key][subKey] == nil then
                        fo_Settings[key][subKey] = subValue
                    end
                end
            -- If it's a simple value (boolean, number, string)
            elseif fo_Settings[key] == nil then
                fo_Settings[key] = value
            end
        end
    end

    -- Optional: Debug message
    -- DEFAULT_CHAT_FRAME:AddMessage("FO Library: Settings fully merged from Defaults.")
end)