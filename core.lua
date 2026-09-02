-- ==========================================================
-- SETTINGS INITIALIZATION
-- ==========================================================
fo_Settings = fo_Settings or {}


-- ==========================================================
-- SCANNER
-- ==========================================================

function fo_GetScanner()
    if not _G["FoAuraScanner"] then
        local frame = CreateFrame("GameTooltip", "FoAuraScanner", nil, "GameTooltipTemplate")
    end
    return _G["FoAuraScanner"]
end

-- ==========================================================
-- SAFE SCANNER WRAPPER
-- ==========================================================
-- func: A function that describes the task to be performed using the scanner
function fo_scan(func)
    local scanner = fo_GetScanner()
    -- Ensure the scanner is visible for interaction, then clear previous tooltip data
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")

    -- Execute the provided function safely and capture the return result
    local status, result = pcall(func, scanner)
    -- Force the tooltip to render its contents so we can scan the text.
    scanner:Show()

    -- Return nil if the execution failed, otherwise return the actual result
    if not status then
        -- Debugging: Uncomment the line below to log errors in-game
        -- DEFAULT_CHAT_FRAME:AddMessage("Scan Error: " .. tostring(result))
        return nil
    end
    -- scanner:Hide()
    return result, scanner
end

-- ==========================================================
-- Public API (Functions to use in Macros)
-- ==========================================================

-- Debug Tool: Show all textures on your current target
function fo_showTargetTexture()
    local unit = "target"
    if not UnitExists(unit) then
        DEFAULT_CHAT_FRAME:AddMessage("No target selected.")
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff--- Target Buff/Debuff Textures ---|r")
    local types = { "HELPFUL", "HARMFUL" }
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
-- Class Detection
-- ==========================================================

function fo_class(class, unit)
	if class then
		local unit = unit or "target"
		local _, c = UnitClass(unit)
		if c then
			if string.lower(c) == string.lower(class) then
				return true
			end
		end
	end
	return false
end
function fo_isDruid(unit)
	return fo_class("DRUID", unit)
end
function fo_isHunter(unit)
	return fo_class("HUNTER", unit)
end
function fo_isPaladin(unit)
	return fo_class("PALADIN", unit)
end
function fo_isPriest(unit)
	return fo_class("PRIEST", unit)
end
function fo_isMage(unit)
	return fo_class("MAGE", unit)
end
function fo_isRogue(unit)
	return fo_class("ROGUE", unit)
end
function fo_isShaman(unit)
	return fo_class("SHAMAN", unit)
end
function fo_isWarlock(unit)
	return fo_class("WARLOCK", unit)
end
function fo_isWarrior(unit)
	return fo_class("WARRIOR", unit)
end

-- ==========================================================
-- Universal Logic Engine
-- ==========================================================

--- [CORE LOGIC: TARGET ACQUISITION]
-- The "Brain" of the system. Centralizes all targeting decisions into one place.
-- It normalizes position-independent arguments (arg2, arg3) into logic flags.
-- Priority: ForceSelf > Mouseover (Helpful > Harmful w/ Flag) > Target > Auto-Self Setting.
-- ==========================================================
-- SMART TARGETING ENGINE (Refined)
-- ==========================================================
local function _GetSmartTarget(spellName, ...)
    local flags = {
        isSelf = false,
        isSmartHostile = false,
        isDisableSelf = false,
        unitID = nil
    }

    -- Standardize input from variable args or table relay
    local argsToProcess = arg
    if type(arg[1]) == "table" then
        argsToProcess = arg[1]
    end

    local n = argsToProcess.n or table.getn(argsToProcess)
    for i = 1, n do
        local v = argsToProcess[i]
        if type(v) == "string" then
            local l = string.lower(v)
            -- 1. Scan for known flags
            if l == "s" or l == "self" then
                flags.isSelf = true
            elseif l == "m" or l == "mo" then
                flags.isSmartHostile = true
            elseif l == "d" or l == "no-self" then
                flags.isDisableSelf = true
                -- 2. Ignore PCC and empty strings, treat rest as UnitID
            elseif v ~= "" and not string.find(l, "^pcc") then
                flags.unitID = v
            end
        end
    end

    -- Priority-based unit resolution
    if flags.isSelf then return "player" end
    if flags.unitID then return flags.unitID end

    if UnitExists("mouseover") then
        if UnitCanAssist("player", "mouseover") then return "mouseover" end
        if flags.isSmartHostile and UnitCanAttack("player", "mouseover") then
            return "mouseover"
        end
    end

    if UnitExists("target") then return "target" end

    -- The "d" flag guard: prevents fallback to self
    if flags.isDisableSelf then return nil end

    -- Final fallback to player if enabled in settings
    if fo_Settings and fo_Settings.selfCastEnabled then
        return "player"
    end

    return nil
end

function fo_getSmartTarget(spellName, arg2, arg3)
    return _GetSmartTarget(spellName, arg2, arg3)
end

-- DUAL LOGIC ENGINE
-- This logic is decoupled to support both spells (fo_castDual) and items (something like fo_itemDual).
-- It is designed as a standalone function to allow for future expansion of
-- decision criteria (e.g., checking for specific buffs, debuffs, or spell reflection)
-- without needing to modify the core casting or item usage functions.
function fo_dualLogic(helpVal, harmVal, unit)
    -- If the resolved unit exists and is an enemy, pick the Harmful side.
    if unit and UnitExists(unit) and UnitCanAttack("player", unit) then
        return harmVal
    end
    -- Default to the Helpful side.
    return helpVal
end

--- SPELL NAME NORMALIZER
-- Removes " (Rank X)" suffix from spell names for logic comparisons.
-- Necessary because CastingBarFrame.spellName often excludes rank info.
-- ==========================================================
-- UTILS: SPELL NAME NORMALIZATION
-- ==========================================================
local function _GetPureName(spellName)
    if not spellName then return "" end

    -- 1. First, convert to lowercase to handle any case sensitivity
    local name = string.lower(spellName)

    -- 2. Remove rank info.
    -- Vanilla patterns: " (rank 1)", "(rank 1)", " rank 1"
    -- We use a more aggressive pattern to strip anything after 'rank'
    name = string.gsub(name, "%s?%(?rank%s?%d+%)?", "")

    -- 3. Trim extra spaces from ends
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")

    return name
end
function fo_getPureName(spellName)
    return _GetPureName(spellName)
end

--- Interceptor
fo_castFilters = {}
function fo_registerFilter(func)
    table.insert(fo_castFilters, func)
end

-- ==========================================================
-- HYBRID DUAL CAST
-- ==========================================================
-- Decoupled logic to decide between Help and Harm spells.
-- Designed for future expansion (e.g., fo_itemDual).
function fo_dualLogic(helpVal, harmVal, unit)
    if unit and UnitExists(unit) and UnitCanAttack("player", unit) then
        return harmVal
    end
    return helpVal
end

-- ==========================================================
-- CORE CASTING FUNCTION (With Immediate Nil Guard)
-- ==========================================================
function fo_cast(spellName, ...)
    -- [1] Capture arguments using the built-in 'arg' table
    -- In Lua 5.0, 'arg' is automatically created for any vararg function.
    -- We've confirmed 'arg' can be used directly.
    local args = arg or {}
    if not spellName or spellName == "" then return end

    -- [2] Filter Check (e.g., Shapeshift/Stance checks)
    local lowerName = string.lower(spellName)
    if fo_castFilters then
        for i = 1, table.getn(fo_castFilters) do
            local filterFunc = fo_castFilters[i]
            if filterFunc(lowerName) == false then return end
        end
    end

    -- [3] Rank Handling
    if string.find(spellName, "[^0-9]%)$") and not string.find(spellName, "%(%)$") then
        spellName = spellName .. "()"
    end

    -- [4] Target Resolution
    -- Use the captured 'args' for smart targeting logic.
    local target = _GetSmartTarget(spellName, unpack(args))
    if not target then return end

    -- [6] Execution
    CastSpellByName(spellName, target)
end

-- Hybrid Dual Cast (Re-implemented using the Logic Engine)
function fo_castDual(helpSpell, harmSpell, ...)
    -- 1. Identify the target unit using the shared engine (resolves m, d, s, etc.)
    local args = arg or {}

    local unit = _GetSmartTarget(helpSpell, unpack(args))

    -- 2. Guard: If "d" is set and no target is found, stop immediately to prevent auto-self cast.
    if not unit then return end

    -- 3. Determine which spell to use based on the unit's reaction.
    local spell = fo_dualLogic(helpSpell, harmSpell, unit)

    -- 4. Relay the final decision to fo_cast for execution and PCC handling.
    -- We unpack the original arguments to ensure PCC options are passed.
    fo_cast(spell, unit, unpack(args))
end

-- ==========================================================
-- Aura Checker
-- ==========================================================

--- Core logic for aura scanning using texture paths and tooltip text.
-- @param spellName: The pure name of the spell or a texture path segment.
-- @param unit: A valid WoW UnitID (e.g., "player", "target").
local function _CheckAuraByName(spellName, unit)
    if not unit or not UnitExists(unit) then return false end

    -- Search name is pre-lowered for consistency
    local searchName = strlower(spellName)
    local types = { "HELPFUL", "HARMFUL" }

    for _, auraType in pairs(types) do
        local i = 1
        while true do
            local texture = (auraType == "HELPFUL") and UnitBuff(unit, i) or UnitDebuff(unit, i)
            if not texture then break end

            -- 1. Check by Texture Path (Normalize to lowercase)
            if string.find(strlower(texture), searchName, 1, true) then
                return true
            end

            -- Check by Tooltip Text
            -- Uses fo_scan to safely interact with the tooltip
            local isMatch = fo_scan(function(scanner)
                scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
                if auraType == "HELPFUL" then
                    scanner:SetUnitBuff(unit, i)
                else
                    scanner:SetUnitDebuff(unit, i)
                end

                -- Retrieve the tooltip text using the global name
                local textLeft1 = _G["FoAuraScannerTextLeft1"]
                local tooltipText = textLeft1 and textLeft1:GetText()

                -- Return true if text matches the search name
                return tooltipText and strlower(tooltipText) == searchName
            end)

            if isMatch then
                fo_GetScanner():Hide()
                return true
            end

            fo_GetScanner():Hide()

            i = i + 1
            if i > 32 then break end
        end
    end
    return false
end


-- Smart Aura Check
-- @param spellName: e.g., "Moonfire(Rank 1)" or "Moonfire"
-- @param unit: The unit to inspect. Accepts standard WoW unit IDs such as "target", "player", "pet", "party1", or "mouseover". Defaults to "target" if omitted.
-- Matches fo_cast behavior: uses the Brain to resolve target.
-- Usage in Macro: fo_aura("Rejuvenation", "s") -> Self
--                 fo_aura("Moonfire", "m")     -> Mouseover/Target

function fo_aura(spellName, arg2, arg3, arg4)
    local u = _GetSmartTarget(spellName, arg2, arg3, arg4)
    if not u then return false end
    return _CheckAuraByName(_GetPureName(spellName), u)
end
-- function fo_aura(spellName, ...)
--     local args = arg or {}
--     local u = _GetSmartTarget(spellName, unpack(args))
--     if not u then return false end
--     return _CheckAuraByName(_GetPureName(spellName), u)
-- end

--- [Direct Interface] Manual Unit ID Check
-- For specific needs: "targettarget", "raid1", "focus", etc.
-- This is kept separate to prevent interference with Smart Logic.
function fo_auraUnit(spellName, unit)
    local targetUnit = unit or "target"
    return _CheckAuraByName(_GetPureName(spellName), targetUnit)
end

--- [Shortcut Interface] Dedicated Player Check
-- The most common check, optimized for speed and clarity.
function fo_auraSelf(spellName)
    return _CheckAuraByName(_GetPureName(spellName), "player")
end

-- ==========================================================
-- RESOURCE CHECKER (Standardized & Fixed)
-- ==========================================================

-- PUBLIC FUNCTION: Returns absolute missing HP
function fo_lifeDeficit(unitArg)
    local unit = _GetSmartTarget(nil, unitArg) or "player"
    if UnitExists(unit) then
        return UnitHealthMax(unit) - UnitHealth(unit)
    end
    return 0
end

-- PUBLIC FUNCTION: Returns absolute missing Power
function fo_powerDeficit(unitArg)
    local unit = _GetSmartTarget(nil, unitArg) or "player"
    if UnitExists(unit) then
        return UnitManaMax(unit) - UnitMana(unit)
    end
    return 0
end

local function _ResourceLogic(input, arg2, arg3, unit)
    -- 1. Initial validation
    if not input or not unit or not UnitExists(unit) then return false end

    local stat, op, threshold

    -- 2. Parsing (Splitting "pd > 100")
    if type(input) == "string" then
        local _, _, s, o, v = string.find(input, "([^%s<>!=]+)%s*([<>!=]+)%s*(.*)")
        if s and o and v then
            stat, op, threshold = s, o, v
        else
            stat, op, threshold = input, arg2, arg3
        end
    else
        stat, op, threshold = input, arg2, arg3
    end

    -- [CRITICAL] Safety check: If parsing failed or args are missing, stop here!
    if not stat or not op or not threshold then return false end

    -- 3. Now it is safe to normalize
    stat = string.lower(stat)
    local current, max = 0, 0

    if stat == "ld" or stat == "hd" then
        current = fo_lifeDeficit(unit)
        max = UnitHealthMax(unit)
    elseif stat == "pd" or stat == "md" then
        current = fo_powerDeficit(unit)
        max = UnitManaMax(unit)
    elseif stat == "l" or stat == "hp" then
        current, max = UnitHealth(unit), UnitHealthMax(unit)
    elseif stat == "p" or stat == "mana" then
        current, max = UnitMana(unit), UnitManaMax(unit)
    else
        return false
    end

    -- 4. Threshold Conversion (Handle % and tonumber)
    local targetVal = 0
    if type(threshold) == "string" and string.find(threshold, "%%") then
        local num = tonumber((string.gsub(threshold, "%%", ""))) or 0
        targetVal = (max * num) / 100
    else
        targetVal = tonumber(threshold) or 0
    end

    -- 5. Final Comparison Logic
    if op == ">" then return current > targetVal end
    if op == "<" then return current < targetVal end
    if op == ">=" then return current >= targetVal end
    if op == "<=" then return current <= targetVal end
    if op == "==" or op == "=" then return current == targetVal end
    if op == "!=" or op == "~=" then return current ~= targetVal end

    return false
end

-- [Main] Smart Targeting Entry Point
function fo_RS(input, arg2, arg3)
    -- This correctly identifies the unit before logic starts
    local unit = _GetSmartTarget("RSCheck", arg2, arg3)
    return _ResourceLogic(input, arg2, arg3, unit)
end

-- [Sub] Manual Targeting Entry Point
function fo_RSUnit(input, unit)
    return _ResourceLogic(input, nil, nil, unit or "target")
end

-- ==========================================================
-- Coolddown Checker
-- ==========================================================
-- Returns true ONLY if the spell is on a real cooldown (longer than the GCD).
-- Useful for skipping spells that are not ready yet.
function fo_CD(spellName)
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
-- Spellbook Checker
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

-- Max Rank Finder
-- Scans the player's spellbook to find the highest available rank of a spell
function fo_getMaxRank(spellName)
    local targetName = string.lower(spellName)
    local maxRank = 0
    local i = 1
    while true do
        local name, rank = GetSpellName(i, "spell")
        if not name then break end
        if string.lower(name) == targetName then
            -- Extract numeric value from rank string (e.g., "Rank 5" -> 5)
            local _, _, rankNumber = string.find(rank, "(%d+)")
            if rankNumber then maxRank = tonumber(rankNumber) end
        end
        i = i + 1
    end
    return maxRank > 0 and maxRank or 1
end


-- ==========================================================
-- Combat Utilities
-- ==========================================================

local fo_isMeleeActive = false  -- Flag based on PLAYER_ENTER_COMBAT
local fo_attackSlot = nil       -- Cached slot for Attack
local fo_shootSlot = nil        -- Cached slot for Shoot (Wand)

-- Update the cache for action bar slots to avoid 120-loop every frame
function fo_UpdateActionCache()
    fo_attackSlot = nil
    fo_shootSlot = nil

    -- Get the texture of the currently equipped wand (Slot 18 is Ranged)
    local rangedTexture = GetInventoryItemTexture("player", 18)

    for i = 1, 120 do
        -- 1. Melee Attack (Standard API)
        if IsAttackAction(i) then
            fo_attackSlot = i
        end

        -- 2. Shoot (Wand)
        -- Compare the action's texture with the equipped wand's texture
        local actionTexture = GetActionTexture(i)
        if actionTexture and rangedTexture and actionTexture == rangedTexture then
            fo_shootSlot = i
        end

        -- Optimization: Stop if both found
        if fo_attackSlot and fo_shootSlot then break end
    end
end






-- Returns true if the player is currently in combat
function fo_isCombat()
    -- UnitAffectingCombat is the standard 1.12 API for this check
    if UnitAffectingCombat("player") then
        return true
    end
    return false
end

-- Returns true if the player is currently casting a spell,
-- based on the latest server-side events.
function fo_isCasting()
    -- Returns the boolean state from our event monitor
    if fo_castState and fo_castState.isCasting then
        return true
    end
    return false
end

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
    if fo_isStealth() or fo_isCombat() then
        return
    end
    local _, class = UnitClass("player")
    if class == "ROGUE" then
        CastSpellByName("Stealth")
    elseif class == "DRUID" and UnitPowerType("player") == 3 then
        CastSpellByName("Prowl")
    else
        CastSpellByName("Shadowmeld")
    end
end

-- Main function to check if Melee Attack is active (Two-tier detection)
function fo_isAttacking()
    if not fo_attackSlot or not IsAttackAction(fo_attackSlot) then
        fo_UpdateActionCache()
    end
    if fo_attackSlot then
        if IsCurrentAction(fo_attackSlot) then
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


-- function fo_isShooting()
--     if not fo_shootSlot or GetActionTexture(fo_shootSlot) == nil then
--         fo_UpdateActionCache()
--     end

--     if fo_shootSlot then
--         -- Check if it's already "marching ants" (active)
--         if IsAutoRepeatAction(fo_shootSlot) == 1 then
--             return true -- Already shooting, do nothing
--         else
--             return false
--         end
--     end
-- end


-- function fo_startShoot()
--     if fo_isShooting() then
--         -- Debug
--         -- DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Shooting]")
--         return
--     else
--         CastSpellByName("Shoot")
--     end
-- end


-- ==========================================================
-- Modular Healing Engines
-- ==========================================================

function fo_autoRankDual(helpSpell, harmSpell, lowHelpRank, midHelpRank, highHelpRank, lowThreshold, midThreshold)
    -- Default values
    lowHelpRank  = lowHelpRank or 3
    midHelpRank  = midHelpRank or 5
    highHelpRank = highHelpRank or "max"
    lowThreshold = lowThreshold or "25%"
    midThreshold = midThreshold or "50%"

    local heal   = fo_getPureName(helpSpell)

    -- Rank decision
    local rank
    if fo_RS("ld<" .. lowThreshold) then
        rank = lowHelpRank
    elseif fo_RS("ld<" .. midThreshold) then
        rank = midHelpRank
    else
        rank = highHelpRank
    end

    -- Construction
    local spellString
    if rank == "max" then
        spellString = heal
    else
        spellString = heal .. "(Rank " .. rank .. ")"
    end

    -- Debug Output
    -- Added logic for checking output in chat
    -- print("[Debug] Casting: " .. spellString .. " (Thresholds: " .. lowThreshold .. ", " .. midThreshold .. ")")
    -- Execute
    fo_castDual(spellString, harmSpell)
end


-- ==========================================================
-- MAIN EVENT HANDLER (Integrated & Fixed)
-- ==========================================================


local FO_EVENT_HANDLER = CreateFrame("Frame")

-- [1] Utility Events
FO_EVENT_HANDLER:RegisterEvent("VARIABLES_LOADED")
FO_EVENT_HANDLER:RegisterEvent("PLAYER_ENTERING_WORLD")
FO_EVENT_HANDLER:RegisterEvent("UNIT_INVENTORY_CHANGED")
FO_EVENT_HANDLER:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

FO_EVENT_HANDLER:SetScript("OnEvent", function()
    -- DEBUGG
    -- DEFAULT_CHAT_FRAME:AddMessage("DEBUG: Event received: " .. tostring(event))

    local event = event
    -- CASE 1: Settings Initialization
    if event == "VARIABLES_LOADED" then
        fo_Settings = fo_Settings or {}
        if fo_DefaultSettings then
            for key, value in pairs(fo_DefaultSettings) do
                if type(value) == "table" then
                    fo_Settings[key] = fo_Settings[key] or {}
                    for subKey, subValue in pairs(value) do
                        if fo_Settings[key][subKey] == nil then
                            fo_Settings[key][subKey] = subValue
                        end
                    end
                elseif fo_Settings[key] == nil then
                    fo_Settings[key] = value
                end
            end
        end
        return
    end

    -- CASE 3: Action Bar Cache Management
    if event == "ACTIONBAR_SLOT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
            return
        end
        fo_attackSlot = nil
        fo_shootSlot = nil
        fo_UpdateActionCache()
        return
    end

end)
