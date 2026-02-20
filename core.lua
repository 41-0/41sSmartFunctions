-- ==========================================================
-- SCANNER INITIALIZATION
-- ==========================================================
-- Create a hidden tooltip for scanning buff names
if not fo_scanner then
    fo_scanner = CreateFrame("GameTooltip", "FoAuraScanner", nil, "GameTooltipTemplate")
    fo_scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
end

-- keywords used to identify forms/stances in tooltips
-- Used by the scanner to identify buffs that should prevent auto-unshifting
FO_PROTECTED_KEYWORDS = { "Form", "Stance", "Seal", "Shapeshift" }


-- ==========================================================
-- SETTINGS INITIALIZATION
-- ==========================================================
fo_Settings = fo_Settings or {}


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

-- Main entry point for hybrid macros.
function fo_castDual(helpSpell, harmSpell, ...)
    -- 1. Identify target via SmartTarget (handles "m", "d", "s" flags).
    local unit = _GetSmartTarget(helpSpell, arg)

    -- 2. "d" flag guard: Stop if no valid target found to prevent auto-self cast.
    if not unit then return end

    -- 3. Select appropriate spell based on target reaction.
    local spell = fo_dualLogic(helpSpell, harmSpell, unit)

    -- 4. Relay to fo_cast for final execution and PCC check.
    fo_cast(spell, unpack(arg))
end






-- ==========================================================
-- CORE CASTING FUNCTION (With Immediate Nil Guard)
-- ==========================================================
function fo_cast(spellName, ...)
    -- [1] Capture arguments using the built-in 'arg' table
    -- In Lua 5.0, 'arg' is automatically created for any vararg function.
    -- We've confirmed 'arg' can be used directly.
    local args = arg 
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
    local target = _GetSmartTarget(spellName, args)
    if not target then return end

    -- [6] Execution
    CastSpellByName(spellName, target)

end



-- Hybrid Dual Cast (Re-implemented using the Logic Engine)
function fo_castDual(helpSpell, harmSpell, ...)
    -- 1. Identify the target unit using the shared engine (resolves m, d, s, etc.)
    local unit = _GetSmartTarget(helpSpell, arg)

    -- 2. Guard: If "d" is set and no target is found, stop immediately to prevent auto-self cast.
    if not unit then return end

    -- 3. Determine which spell to use based on the unit's reaction.
    local spell = fo_dualLogic(helpSpell, harmSpell, unit)

    -- 4. Relay the final decision to fo_cast for execution and PCC handling.
    -- We unpack the original arguments to ensure PCC options are passed.
    fo_cast(spell, unit, unpack(arg))
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



-- @param spellName: e.g., "Moonfire(Rank 1)" or "Moonfire"
-- @param unit: The unit to inspect. Accepts standard WoW unit IDs such as "target", "player", "pet", "party1", or "mouseover". Defaults to "target" if omitted.

--- [Standard Interface] Smart Aura Check
-- Matches fo_cast behavior: uses the Brain to resolve target.
-- Usage in Macro: fo_aura("Rejuvenation", "s") -> Self
--                 fo_aura("Moonfire", "m")     -> Mouseover/Target
function fo_aura(spellName, arg2, arg3)
    local u = _GetSmartTarget(spellName, arg2, arg3)
    if not u then return false end
    return _CheckAuraByName(_GetPureName(spellName), u)
end

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
        local leftObj = getglobal("FoAuraScannerTextLeft" .. i)
        if leftObj then
            local left = leftObj:GetText()
            local rightObj = getglobal("FoAuraScannerTextRight" .. i)
            local right = (rightObj and rightObj:GetText()) or ""

            -- Case-insensitive and plain text search for reliability
            local content = string.lower((left or "") .. right)
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
    local weaponTypes = { "One-Hand", "Dagger", "Sword", "Axe", "Mace", "Fist" }
    for _, wType in ipairs(weaponTypes) do
        if fo_scanFor(17, wType) then
            return true
        end
    end

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
        local left = getglobal("FoAuraScannerTextLeft" .. i):GetText()
        local right = getglobal("FoAuraScannerTextRight" .. i):GetText()
        local content = (left or "") .. (right or "")

        if string.find(content, "Wand") then
            spell = "Shoot"; break
        elseif string.find(content, "Crossbow") then
            spell = "Shoot Crossbow"; break
        elseif string.find(content, "Bow") then
            spell = "Shoot Bow"; break
        elseif string.find(content, "Gun") then
            spell = "Shoot Gun"; break
        end
    end

    if spell then CastSpellByName(spell) end
end

-- Stops all current actions: Spell casting, Channeling, Auto-Attack, and Shooting.
function fo_break()
    -- 1. Stop Spell Casting & Channeling
    SpellStopCasting()

    -- 2. Stop Auto-Attack (if active)
    if fo_isAttacking() then
        AttackTarget()
    end

    -- 3. Stop Auto-Shot / Wand Shooting
    if fo_isShooting() then
        SpellStopCasting()
    end
end

-- ==========================================================
-- GENERIC ITEM UTILITY
-- ==========================================================

--- Checks the total count of an item by name in all bags.
function fo_GetItemCount(targetName)
    local count = 0
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                -- Extract item name from the link: "|c...[Item Name]|h..."
                local _, _, name = string.find(link, "%[(.*)%]")
                if name == targetName then
                    local _, stackCount = GetContainerItemInfo(bag, slot)
                    count = count + (stackCount or 0)
                end
            end
        end
    end
    return count
end

-- Internal helper: Scans a list and uses the first available item found in bags
local function _fo_ScanAndUseItem(list, categoryLabel)
    for _, name in ipairs(list) do
        -- Scan bags (0 to 4)
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                -- Check if the item in this slot matches the name in the list
                if link and string.find(link, name) then
                    UseContainerItem(bag, slot)
                    -- Optional logging
                    -- DEFAULT_CHAT_FRAME:AddMessage("Used: " .. name .. " (" .. (categoryLabel or "Item") .. ")")
                    return true
                end
            end
        end
    end
    return false
end









-- PUBLIC API: Check if an item is ready to use
-- Works for both equipped items and items in bags
function fo_itemCD(name)
    if not name or name == "" then return false end
    local target = string.lower(name)

    -- 1. Scan Equipment Slots (1-19)
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link and string.find(string.lower(link), target) then
            local start, duration, enable = GetInventoryItemCooldown("player", slot)
            return (start > 0 and duration > 0)
        end
    end

    -- 2. Scan Bags (0-4)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(string.lower(link), target) then
                local start, duration, enable = GetContainerItemCooldown(bag, slot)
                return (start > 0 and duration > 0)
            end
        end
    end

    return false -- Item not found
end

-- PUBLIC API: Use item by name with smart CD checking and user feedback
function fo_item(name)
    if not name or name == "" then return false end
    local target = string.lower(name)
    local foundLink = nil
    local isEquipped = false
    local bagID, slotID = nil, nil

    -- 1. Search for the item and identify its location
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link and string.find(string.lower(link), target) then
            foundLink = link
            isEquipped = true
            slotID = slot
            break
        end
    end

    if not foundLink then
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                if link and string.find(string.lower(link), target) then
                    foundLink = link
                    bagID = bag
                    slotID = slot
                    break
                end
            end
            if foundLink then break end
        end
    end

    -- 2. Feedback: Item not found in bags or equipment
    if not foundLink then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[fo]|r Item not found: " .. name)
        return false
    end

    -- 3. Feedback: Item is on cooldown
    -- We use fo_itemCD logic here to prevent server-side spam
    if fo_itemCD(name) then
        UIErrorsFrame:AddMessage(name .. " is not ready yet.", 1.0, 1.0, 0.0)
        return false
    end

    -- 4. Execution: Use the item
    -- Only reached if item exists and CD is ready
    if isEquipped then
        UseInventoryItem(slotID)
    else
        UseContainerItem(bagID, slotID)
    end

    return true
end

-- Automatically finds and uses the highest priority bandage in your bags.
function fo_bandage(targetArg) -- [FIX] Added targetArg here
    -- Priority list of bandages
    local bandages = {
        "Crystal Infused Bandage",
        "Alterac Heavy Runecloth Bandage",
        "Arathi Basin Runecloth Bandage",
        "Defiler's Runecloth Bandage",
        "Heavy Runecloth Bandage",
        "Runecloth Bandage",
        "Arathi Basin Mageweave Bandage",
        "Highlander's Mageweave Bandage",
        "Warsong Gulch Mageweave Bandage",
        "Defiler's Mageweave Bandage",
        "Heavy Mageweave Bandage",
        "Mageweave Bandage",
        "Arathi Basin Silk Bandage",
        "Highlander's Silk Bandage",
        "Warsong Gulch Silk Bandage",
        "Defiler's Silk Bandage",
        "Heavy Silk Bandage",
        "Silk Bandage",
        "Heavy Wool Bandage",
        "Wool Bandage",
        "Heavy Linen Bandage",
        "Linen Bandage"
    }

    -- 1. Scan bags for the best available bandage
    local targetBandage = nil
    for _, name in ipairs(bandages) do
        if fo_GetItemCount(name) > 0 then
            targetBandage = name
            break
        end
    end

    if not targetBandage then
        UIErrorsFrame:AddMessage("No bandages found!", 1.0, 0.1, 0.1)
        return
    end

    -- 2. Target Normalization (Fixed logic)
    local unit
    local t = string.lower(tostring(targetArg or ""))

    if t == "s" or t == "self" or t == "player" then
        unit = "player"
    elseif targetArg and targetArg ~= "" then
        unit = targetArg
    else
        -- [FIX] Updated to match the new _GetSmartTarget(mode, arg1, arg2) signature
        -- Passing nil for mode as it's a standard cast, not an RSCheck
        unit = _GetSmartTarget(nil, targetArg)
    end

    -- 3. Execution using Target Swap Method
    if UnitExists(unit) then
        -- Prevent using bandage on someone who already has "Recently Bandaged" debuff
        -- (Optional logic can be added here)

        local currentTargetExists = UnitExists("target")
        local isSelf = UnitIsUnit("player", unit)

        if not UnitIsUnit("target", unit) then
            TargetUnit(unit)
            UseItemByName(targetBandage)
            if currentTargetExists then
                TargetLastTarget()
            else
                ClearTarget()
            end
        else
            UseItemByName(targetBandage)
        end
    end
end

-- Use best Health Potion
function fo_healthPot()
    local list = {
        "Major Healing Potion",
        "Combat Healing Potion",
        "Superior Healing Potion",
        "Greater Healing Potion",
        "Healing Potion",
        "Lesser Healing Potion",
        "Minor Healing Potion"
    }
    return _fo_ScanAndUseItem(list, "Health Potion")
end

-- Use best Mana Potion
function fo_manaPot()
    local list = {
        "Major Mana Potion",
        "Combat Mana Potion",
        "Superior Mana Potion",
        "Greater Mana Potion",
        "Mana Potion",
        "Lesser Mana Potion",
        "Minor Mana Potion"
    }
    return _fo_ScanAndUseItem(list, "Mana Potion")
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

    local heal = fo_getPureName(helpSpell)

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
local f = CreateFrame("Frame")

-- [1] Utility Events
f:RegisterEvent("VARIABLES_LOADED")
-- [2] Combat & Taunt Events
f:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")


f:SetScript("OnEvent", function()
    -- 1.12では引数を使わず、グローバルな event / arg1 を直接参照するのが最も安全です
    local event = event
    local a1 = arg1

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

    -- CASE 3: Combat Log Monitoring
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        if fo_Settings and fo_Settings.announceTauntResist and fo_Settings.tauntSpells then
            ExecuteTauntAnnounce(a1)
        end
        return
    end
end)