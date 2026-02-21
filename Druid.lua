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

FO_DRUID_FORMS = { "Bear Form", "Cat Form", "Aquatic Form", "Travel Form", "Moonkin Form", "Tree of Life Form" }

-- Function to return to Caster Form by cancelling any active shapebuff
function fo_cancelForm()
    -- [1] Find the currently active shapeshift form index
    local currentFormIndex = nil
    for i = 1, GetNumShapeshiftForms() do
        local _, _, active = GetShapeshiftFormInfo(i)
        if active then
            currentFormIndex = i
            break
        end
    end

    -- If no form is active, exit early
    if not currentFormIndex then return false end

    -- [2] Count current buffs (Limit: 32)
    local buffCount = 0
    for i = 0, 31 do
        if GetPlayerBuff(i, "HELPFUL") ~= -1 then
            buffCount = buffCount + 1
        else
            break
        end
    end

    -- [3] Strategy A: If buff count < 32, use direct buff cancellation
    if buffCount < 32 then
        for i = 0, 31 do
            local id = GetPlayerBuff(i, "HELPFUL")
            if id == -1 then break end

            -- Safely scan tooltip to identify the form buff
            local buffName = fo_Scan(function(scanner)
                scanner:SetPlayerBuff(id)
                local leftObj = _G["FoAuraScannerTextLeft1"]
                return leftObj and leftObj:GetText()
            end) or ""

            -- Compare name with form keywords
            local nameLower = strlower(buffName)
            for _, formName in pairs(FO_DRUID_FORMS) do
                if strfind(nameLower, strlower(formName)) then
                    CancelPlayerBuff(id)
                    return true
                end
            end
        end
    end

    -- [4] Strategy B: Fallback to casting the form spell
    local _, formName = GetShapeshiftFormInfo(currentFormIndex)
    if formName then
        CastSpellByName(formName)
        return true
    end

    return false
end

-- ==========================================================
-- Form Specific Spellcasts (Refactored)
-- ==========================================================

-- Bear / Dire Bear Form
function fo_bear(spellName, ...)
    if fo_isBear() then
        local args = arg or {}
        fo_cast(spellName, unpack(args))
    end
end

-- Cat Form
function fo_cat(spellName, ...)
    if fo_isCat() then
        local args = arg or {}
        fo_cast(spellName, unpack(args))
    end
end


-- Moonkin Form (Dual support)
function fo_moonkin(helpSpell, harmSpell, ...)
    if fo_isMoonkin() then
        local args = arg or {}
        fo_castDual(helpSpell, harmSpell, unpack(args))
    end
end


-- Tree of Life Form (Dual support)
function fo_tree(helpSpell, harmSpell, ...)
    if fo_isTree() then
        local args = arg or {}
        fo_castDual(helpSpell, harmSpell, unpack(args))
    end
end


-- Humanoid (Caster) Form (Dual support)
-- Moonkin Form (Dual support)
function fo_caster(helpSpell, harmSpell, ...)
    if fo_isCaster() then
        local args = arg or {}
        fo_castDual(helpSpell, harmSpell, unpack(args))
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
    ["abolish poison"]      = 3, -- f_human + f_tree
    ["cure poison"]         = 3,
    ["nature's swiftness"]  = 3,
    ["regrowth"]            = 3,
    ["rejuvenation"]        = 3,
    ["swiftmend"]           = 3,
    ["tranquility"]         = 3,

    -- Balance Special (Human and Moonkin ONLY)
    ["wrath"]               = 5, -- f_human + f_moonkin
    ["starfire"]            = 5,
    ["moonfire"]            = 5,
    ["insect swarm"]        = 5,
    ["hurricane"]           = 5,

    -- Human Only
    ["healing touch"]       = 1, -- F_HUMAN
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
function fo_druidFilter(spellName)
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
    fo_registerFilter(fo_druidFilter)
end
