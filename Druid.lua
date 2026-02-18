-- ==========================================================
-- Universal Unit Texture Checker
-- ==========================================================
-- @param unit: "player", "target", "mouseover" etc.
-- @param texturePart: String to search for.
-- @return boolean: true if found.
function fo_hasTexture(unit, texturePart)
    if not UnitExists(unit) then return false end

    -- Buffs and Debuffs are stored differently in 1.12.
    -- We check both to be safe and universal.
    local types = { "HELPFUL", "HARMFUL" }

    for _, auraType in pairs(types) do
        for i = 0, 31 do
            -- Note: GetPlayerBuff is only for "player".
            -- For other units, we use UnitBuff / UnitDebuff.
            local texture
            if unit == "player" and auraType == "HELPFUL" then
                -- Player buffs are special in 1.12 for more detailed info,
                -- but UnitBuff works for textures too.
                texture = UnitBuff(unit, i + 1)
            elseif auraType == "HELPFUL" then
                texture = UnitBuff(unit, i + 1)
            else
                texture = UnitDebuff(unit, i + 1)
            end

            if not texture then break end
            if string.find(texture, texturePart) then
                return true
            end
        end
    end
    return false
end

-- ==========================================================
-- Form Detection Aliases
-- Description: Simple shorthand functions for Druid forms
-- ==========================================================

-- Internal helper to check presence of a texture by name (case-insensitive)
local function _hasTex(texName)
    -- Using the existing fo_hasTexture logic but simplified for internal use
    for i = 1, 32 do
        local b = UnitBuff("player", i)
        if not b then break end
        if string.find(string.lower(b), string.lower(texName)) then return true end
    end
    return false
end

function fo_isBear()
    return _hasTex("Ability_Racial_BearForm") or _hasTex("Ability_Druid_BearForm")
end

function fo_isCat()
    return _hasTex("Ability_Druid_CatForm")
end

function fo_isTravel()
    return _hasTex("Ability_Druid_TravelForm")
end

function fo_isAqua()
    return _hasTex("Ability_Druid_AquaticForm")
end

function fo_isMoonkin()
    return _hasTex("Spell_Nature_ForceOfNature")
end

function fo_isTree()
    return _hasTex("Ability_Druid_TreeofLife")
end

function fo_isFeral()
    return fo_isBear() or fo_isCat()
end

function fo_isCaster()
    return not (fo_isBear() or fo_isCat() or fo_isTravel() or fo_isAqua() or fo_isMoonkin() or fo_isTree())
end

-- ==========================================================
-- Spammable Shapeshift Script
-- ==========================================================
local function GetBestBearForm()
    local i = 1
    while true do
        local name = GetSpellName(i, "spell")
        if not name then break end
        if name == "Dire Bear Form" then
            return "Dire Bear Form"
        end
        i = i + 1
    end
    return "Bear Form"
end

function fo_castBearForm()
    if fo_isBear() then
        return
    end
    local bestForm = GetBestBearForm()
    fo_cast(bestForm)
end

function fo_castCatForm()
    if fo_isCat() then
        return
    end
    fo_cast("Cat Form")
end

function fo_castAquaForm()
    if fo_isAqua() then
        return
    end
    fo_cast("Aquatic Form")
end

function fo_castTravelForm()
    if fo_isTravel() then
        return
    end
    fo_cast("Travel Form")
end

function fo_castMoonkinForm()
    if fo_isMoonkin() then
        return
    end
    fo_cast("Moonkin Form")
end

function fo_castTreeForm()
    if fo_isTree() then
        return
    end
    fo_cast("Tree of Life Form")
end

-- Function to return to Caster Form by cancelling any active shapebuff
function fo_cancelForm()
    -- Check if we are in any form using our simplified aliases
    if fo_isBear() or fo_isCat() or fo_isTravel() or fo_isAqua() or fo_isMoonkin() or fo_isTree() then
        -- Scan buffs to find and cancel the form/stance
        for i = 0, 31 do
            local id = GetPlayerBuff(i, "HELPFUL")
            if id == -1 then break end

            fo_scanner:ClearLines()
            fo_scanner:SetPlayerBuff(id)
            local name = FoAuraScannerTextLeft1:GetText() or ""
            local nameLower = string.lower(name)

            -- If the name matches any protected keyword (form, stance, etc.), cancel it
            for _, key in pairs(FO_PROTECTED_KEYWORDS) do
                if string.find(nameLower, string.lower(key)) then
                    CancelPlayerBuff(id)
                    return true
                end
            end
        end
    end
    return false
end

-- ==========================================================
-- Form Specific Spellcasts (Refactored)
-- ==========================================================

-- Bear / Dire Bear Form
function fo_bear(spellName, arg2, arg3)
    if fo_isBear() then
        fo_cast(spellName, arg2, arg3)
    end
end

-- Cat Form
function fo_cat(spellName, arg2, arg3)
    if fo_isCat() then
        fo_cast(spellName, arg2, arg3)
    end
end

-- Moonkin Form (Dual support)
function fo_moonkin(helpSpell, harmSpell, arg3, arg4)
    if fo_isMoonkin() then
        fo_castDual(helpSpell, harmSpell, arg3, arg4)
    end
end

-- Tree of Life Form (Dual support)
function fo_tree(helpSpell, harmSpell, arg3, arg4)
    if fo_isTree() then
        fo_castDual(helpSpell, harmSpell, arg3, arg4)
    end
end

-- Humanoid (Caster) Form (Dual support)
function fo_caster(helpSpell, harmSpell, arg3, arg4)
    if fo_isCaster() then
        fo_castDual(helpSpell, harmSpell, arg3, arg4)
    end
end


-- ==========================================================
-- DRUID Status
-- ==========================================================
function fo_isFrenziedRegen()
    return fo_auraSelf('Frenzied Regeneration') and fo_auraSelf('Ability_BullRush')
    -- return true
end

-- ==========================================================
-- DRUID LOGIC - Form Lock & Permission Engine
-- ==========================================================

-- [A] BIT FLAGS for Permission Management
local F_HUMAN           = 1
local F_TREE            = 2
local F_MOONKIN         = 4

-- 1. CASTER SPELL PERMISSIONS
fo_spellPermissions     = {
    -- ***WRITE IN LOWER CASE***
    -- Shared by ALL Caster Forms (Human, Tree, Moonkin)
    ["barkskin"]            = 7, -- f_human + f_tree + f_moonkin
    ["faerie fire"]         = 7,
    ["entangling roots"]    = 7,
    ["hibernate"]           = 7,
    ["innervate"]           = 7,
    ["mark of the wild"]    = 7,
    ["nature's grasp"]      = 7,
    ["remove curse"]        = 7,
    ["soothe animal"]       = 7,
    ["thorns"]              = 7,
    ["teleport: moonglade"] = 7,

    -- Restoration Special (Human and Tree ONLY)
    ["abolish poison"]     = 3, -- f_human + f_tree
    ["cure poison"]        = 3,
    ["nature's swiftness"] = 3,
    ["regrowth"]           = 3,
    ["rejuvenation"]       = 3,
    ["swiftmend"]          = 3,
    ["tranquility"]        = 3,

    -- Balance Special (Human and Moonkin ONLY)
    ["wrath"]              = 5, -- f_human + f_moonkin
    ["starfire"]           = 5,
    ["moonfire"]           = 5,
    ["insect swarm"]       = 5,
    ["hurricane"]          = 5,

    -- Human Only
    ["healing touch"]      = 1, -- F_HUMAN
}

-- 2. FERAL REQUIREMENTS (Bear, Cat, or Both)
fo_formRequirements     = {
    ["bash"] = { "bear form" },
    ["challenging roar"] = { "bear form" },
    ["demoralizing roar"] = { "bear form" },
    ["enrage"] = { "bear form" },
    ["feral charge"] = { "bear form" },
    ["frenzied regeneration"] = { "bear form" },
    ["growl"] = { "bear form" },
    ["maul"] = { "bear form" },
    ["savage bite"] = { "bear form" },
    ["swipe"] = { "bear form" },
    ["claw"] = { "cat form" },
    ["cower"] = { "cat form" },
    ["dash"] = { "cat form" },
    ["ferocious bite"] = { "cat form" },
    ["mangle"] = { "cat form" },
    ["pounce"] = { "cat form" },
    ["prowl"] = { "cat form" },
    ["rake"] = { "cat form" },
    ["ravage"] = { "cat form" },
    ["rip"] = { "cat form" },
    ["shred"] = { "cat form" },
    ["tiger's fury"] = { "cat form" },
    ["track humanoids"] = { "cat form" },
    ["barkskin (feral)"] = { "bear form", "cat form" },
    ["berserk"] = { "bear form", "cat form" },
    ["faerie fire (feral)"] = { "bear form", "cat form" },
}

-- [[ Druid Specific Filter Logic ]]
-- This function handles all Druid-specific constraints including:
-- 1. Frenzied Regeneration Rage Management (High Priority)
-- 2. Auto-Shapeshifting based on spell requirements
-- 3. Form-based permissions using bitwise flags
local lastFRMessageTime = 0
local function druidFilter(spellName)
    -- Normalize input to lowercase
    local name = string.lower(spellName or "")
    if name == "" then return true end

    -- Extract base spell name (remove rank/parentheses)
    -- If "(" exists, we strip it unless it's the specific "(feral)" variant
    local baseName = name
    local openParen = string.find(name, "%(")
    if openParen and not string.find(name, "feral") then
        baseName = string.sub(name, 1, openParen - 1)
        baseName = string.gsub(baseName, "%s+$", "") -- Trim whitespace
    end

    -- [PRE-STEP] Frenzied Regeneration Safety Check
    if fo_isFrenziedRegen() then
        -- Use baseName for table lookup
        if fo_Settings.rageSpells and fo_Settings.rageSpells[baseName] then
            if fo_RSSelf('p', "<", fo_Settings.frenziedRegenThreshold) then
                local now = GetTime()
                if (now - lastFRMessageTime) > 3 then
                    UIErrorsFrame:AddMessage("Blocking " .. baseName .. " for Frenzied Regen", 1.0, 0.5, 0.0)
                    lastFRMessageTime = now
                end
                return false
            end
        end
    end

    -- [STEP 1] Determine Form Lock Status
    local isFormLocked = false
    if fo_isBear() then
        isFormLocked = fo_Settings.lockBearForm
    elseif fo_isCat() then
        isFormLocked = fo_Settings.lockCatForm
    elseif fo_isMoonkin() then
        isFormLocked = fo_Settings.lockMoonkinForm
    elseif fo_isTree() then
        isFormLocked = fo_Settings.lockTreeForm
    end

    -- [STEP 2] Check Feral Requirements (Auto-Shapeshift)
    -- Use baseName for lookup instead of raw name
    local reqForms = fo_formRequirements[baseName]
    if reqForms then
        local isCorrectForm = false
        for _, fName in ipairs(reqForms) do
            if (fName == "bear form" and fo_isBear()) or
                (fName == "cat form" and fo_isCat()) then
                isCorrectForm = true
                break
            end
        end

        if isCorrectForm then return true end

        if fo_Settings.autoShapeshift and not isFormLocked then
            if reqForms[2] then
                if fo_Settings.prioritizeBear then
                    fo_castBearForm()
                else
                    fo_castCatForm()
                end
            else
                local target = string.lower(reqForms[1])
                if target == "bear form" then
                    fo_castBearForm()
                elseif target == "cat form" then
                    fo_castCatForm()
                elseif target == "travel form" then
                    fo_castTravelForm()
                elseif target == "moonkin form" then
                    fo_castMoonkinForm()
                elseif target == "tree of life form" then
                    fo_castTreeForm()
                end
            end
        end
        return false
    end

    -- [STEP 3] Check Caster Permissions (Bitwise Validation)
    -- Use baseName for lookup
    local allowedMask = fo_spellPermissions[baseName]

    -- Block the action if the form is locked (Prevent accidental shifting)
    if isFormLocked then
        -- Debugg
        -- UIErrorsFrame:AddMessage("Form is LOCKED", 1.0, 0.1, 0.1)
        return false
    end


    if allowedMask then
        local currentFlag = 0
        if fo_isCaster() then
            currentFlag = 1
        elseif fo_isTree() then
            currentFlag = 2
        elseif fo_isMoonkin() then
            currentFlag = 4
        elseif fo_isBear() then
            currentFlag = 8
        elseif fo_isCat() then
            currentFlag = 16
        else
            currentFlag = 32
        end

        -- Perform bitwise check to see if current form is allowed for this spell
        local isAllowed = (math.mod(math.floor(allowedMask / currentFlag), 2) == 1)
        if isAllowed then return true end

        -- [TWoW SHAPESHIFT LOGIC]
        local isShapeshift = (baseName == "bear form") or (baseName == "dire bear form") or
            (baseName == "cat form") or (baseName == "travel form") or
            (baseName == "aquatic form") or (baseName == "moonkin form") or
            (baseName == "tree of life form")

        if isShapeshift then
            return true
        end

        -- Default Behavior: Cancel current form if the spell is not permitted and not a shapeshift
        if not isFormLocked and fo_Settings.autoCancelForm then
            fo_cancelForm()
        end
        return false
    end

    return true
end

-- [[ Filter Registration ]]
local _, class = UnitClass("player")
if class == "DRUID" then
    fo_registerFilter(druidFilter)
end






-- ==========================================================
-- 41's Smart Functions: Druid Module
-- ==========================================================

-- Internal helper: Specific mechanic for Regrowth
local function _Druid_MaintainRejuvenation(unit)
    -- If Rejuvenation is missing, cast Rank 1 to empower future Regrowth
    if not fo_aura("rejuvenation") then
        fo_ExecuteCast(unit, "Rejuvenation", 1)
        return true -- Mechanic active
    end
    return false
end




-- [Internal Process Function]
-- Shared logic for handling Pre-cast and the "0.5s Late Cancel" rule
local function _fo_Druid_Process_Unified(spellName, unit, hpPercent, ld, rank, isCasting, timeLeft)
    -- ==========================================
    -- CORE: Pre-cast & Late Cancel Logic
    -- ==========================================
    if isCasting then
        -- If HP is stable (>= 95%), decide whether to cancel or hold
        if hpPercent >= 0.95 then
            -- Cancel ONLY in the final 0.5s window to maximize "waiting for damage" time
            if timeLeft > 0 and timeLeft < 0.5 then
                SpellStopCasting() 
                return true
            else
                -- Observation Phase: Hold the cast even at 100% HP
                return true
            end
        end
        -- If HP is low, always allow the cast to finish
        return true 
    end

    -- Initial Cast Execution
    if rank > 0 then
        fo_ExecuteCast(unit, spellName, rank)
        return true
    end
    return false
end


-- ==========================================================
-- [Main Entry] Called from In-game Macro
-- ==========================================================



-- -- @param spellName: "Healing Touch", etc.
-- -- @param N: Heal amount of the "Common Rank" with your gear/talents.
-- -- @param r1: Common Rank (e.g., 3 or 4)
-- -- @param r2: Mid Rank (e.g., 7)
-- -- @param r3: Emergency/Max Rank (e.g., 11)
-- function fo_Druid_ManualStyle(spellName, N, r1, r2, r3, arg2)
--     -- 1. Target and HP Acquisition
--     local unit = fo_getSmartTarget(spellName, arg2)
--     if not unit then 
--         if CastingBarFrame and CastingBarFrame.casting then SpellStopCasting() end
--         return 
--     end

--     local curHP = UnitHealth(unit)
--     local maxHP = UnitHealthMax(unit)
--     local hpPercent = curHP / maxHP
--     local ld = maxHP - curHP
    
--     -- 2. Casting Information Acquisition
--     local isCasting = CastingBarFrame and CastingBarFrame.casting
--     local finishTime = CastingBarFrame and CastingBarFrame.maxValue or 0
--     local currentTime = CastingBarFrame and CastingBarFrame.value or 0
--     local timeLeft = finishTime - currentTime

--     -- ==========================================
--     -- [CORE] Pre-cast & Late Cancel Logic
--     -- ==========================================
--     -- If HP is above 95%:
--     -- Wait until the very last moment (0.5s before finish) in case of sudden damage.
--     -- If damage doesn't occur by the deadline, cancel to save mana.
    
--     if isCasting then
--         if hpPercent >= 0.95 then
--             -- Deadline Check: Only cancel if we are within the final 0.5s window
--             if timeLeft > 0 and timeLeft < 0.5 then
--                 SpellStopCasting() -- Cancel: HP is still full at the last second
--                 return
--             else
--                 -- Maintain cast: Still have time, damage might come soon
--                 return
--             end
--         end
--         -- Target is below 95%: Continue the cast to completion
--         return 
--     end

--     -- ==========================================
--     -- 3. Initial Cast Decision (Start Pre-cast)
--     -- ==========================================
--     local rank = 0
    
--     if hpPercent < 0.40 then
--         -- A. Emergency: Below 60% HP
--         rank = r3 or fo_getMaxRank(spellName)
--     elseif hpPercent < 0.75 then
--         -- B. Warning: 40% - 75% HP
--         rank = r2 or (r1 + 3)
--     elseif hpPercent < 1.0 then
--         -- C. Pre-cast: 75% - 99% HP
--         -- Start casting the Common Rank (r1) proactively
--         rank = r1 or 3
--     end

--     -- 4. Execution
--     if rank > 0 then
--         fo_ExecuteCast(unit, spellName, rank)
--     end
-- end









-- fo_Druid_SmartHeal: Standard balanced smart heal logic
function fo_Druid_SmartHeal(spellName, myMaxHeal, arg2, stopThreshold)
    -- [1] Handle arguments
    if type(arg2) == "number" then
        stopThreshold = arg2
        arg2 = nil
    end

    local unit = fo_getSmartTarget(spellName, arg2)
    if not unit then 
        -- Stop casting if the target is lost
        if CastingBarFrame and CastingBarFrame.casting then SpellStopCasting() end
        return 
    end

    -- [2] Check current casting status
    -- Using CastingBarFrame for reliable status in Vanilla WoW
    local isCasting = CastingBarFrame.casting or (CastingBarFrame.channeling)

    local curHP = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)
    local ld = maxHP - curHP

    -- [3] Forced Interrupt Logic
    -- Cancel cast if target is full HP or the deficit is too small based on stopThreshold
    if curHP >= maxHP or (ld < (myMaxHeal * (stopThreshold or 0.1))) then
        if isCasting then
            SpellStopCasting()
            -- DEFAULT_CHAT_FRAME:AddMessage("Overheal Cancelled!") -- Debug info
        end
        -- Exit to prevent starting a new cast
        return 
    end

    -- [4] Initiate Heal
    -- If already casting and target still needs healing, do nothing (prevent reset)
    if isCasting then return end

    local maxRank = fo_getMaxRank(spellName)
    local rank = fo_CalculateRank(ld, myMaxHeal, maxRank, stopThreshold)

    if rank and rank > 0 then
        -- Specific logic for Regrowth
        if string.lower(spellName) == "regrowth" then
            if _Druid_MaintainRejuvenation(unit) then return end
        end
        
        -- Execute the spell cast
        fo_ExecuteCast(unit, spellName, rank)
    end
end




-- ==========================================
-- 1. Custom Style (Your Manual Style)
-- Focused on "N" (Common Heal) and specific HP thresholds
-- ==========================================
function fo_Druid_ManualStyle(spellName, N, r1, r2, r3, arg2)
    local unit = fo_getSmartTarget(spellName, arg2)
    if not unit then return end

    local curHP, maxHP = UnitHealth(unit), UnitHealthMax(unit)
    local hpPercent, ld = curHP / maxHP, maxHP - curHP
    local isCasting = CastingBarFrame and CastingBarFrame.casting
    local timeLeft = (CastingBarFrame and CastingBarFrame.maxValue or 0) - (CastingBarFrame and CastingBarFrame.value or 0)

    local rank = 0
    if hpPercent < 0.40 then
        rank = r3 or fo_getMaxRank(spellName) -- Emergency Phase
    elseif hpPercent < 0.75 then
        rank = r2 or (r1 + 3)               -- Warning Phase
    elseif ld > (N * 0.9) then
        rank = r1 or 3                      -- Maintenance/Pre-cast Phase
    end

    _fo_Druid_Process_Unified(spellName, unit, hpPercent, ld, rank, isCasting, timeLeft)
end

-- ==========================================
-- 2. Small Heal Style (Proactive Maintenance)
-- Higher sensitivity, using lower ranks to keep targets near 100%
-- ==========================================
function fo_Druid_SmallHeal(spellName, myMaxHeal, arg2, stopThreshold)
    local unit = fo_getSmartTarget(spellName, arg2)
    if not unit then return end

    local curHP, maxHP = UnitHealth(unit), UnitHealthMax(unit)
    local hpPercent, ld = curHP / maxHP, maxHP - curHP
    local isCasting = CastingBarFrame and CastingBarFrame.casting
    local timeLeft = (CastingBarFrame and CastingBarFrame.maxValue or 0) - (CastingBarFrame and CastingBarFrame.value or 0)

    -- Uses a 0.7 modifier to lean towards faster, smaller ranks
    local rank = fo_CalculateRank_Base(ld, myMaxHeal, fo_getMaxRank(spellName), stopThreshold or 0.05, 0.7)

    _fo_Druid_Process_Unified(spellName, unit, hpPercent, ld, rank, isCasting, timeLeft)
end

-- ==========================================
-- 3. Efficient Style (Mana Conservation)
-- Only reacts to significant damage to utilize the 5-second rule
-- ==========================================
function fo_Druid_EfficientHeal(spellName, myMaxHeal, arg2, stopThreshold)
    local unit = fo_getSmartTarget(spellName, arg2)
    if not unit then return end

    local curHP, maxHP = UnitHealth(unit), UnitHealthMax(unit)
    local hpPercent, ld = curHP / maxHP, maxHP - curHP
    local isCasting = CastingBarFrame and CastingBarFrame.casting
    local timeLeft = (CastingBarFrame and CastingBarFrame.maxValue or 0) - (CastingBarFrame and CastingBarFrame.value or 0)

    -- Higher threshold (0.3) means no action until 30% HP is missing
    local rank = fo_CalculateRank_Base(ld, myMaxHeal, fo_getMaxRank(spellName), stopThreshold or 0.3, 1.0)

    _fo_Druid_Process_Unified(spellName, unit, hpPercent, ld, rank, isCasting, timeLeft)
end
