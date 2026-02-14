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
    local types = {"HELPFUL", "HARMFUL"}
    
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
    CastSpellByName(bestForm)
end
function fo_castCatForm()
    if fo_isCat() then
        return 
    end
    CastSpellByName("Cat Form")
end
function fo_castAquaForm()
    if fo_isAqua() then
        return 
    end
    CastSpellByName("Aquatic Form")
end
function fo_castTravelForm()
    if fo_isTravel() then
        return 
    end
    CastSpellByName("Travel Form")
end
function fo_castMoonkinForm()
    if fo_isMoonkin() then
        return 
    end
    CastSpellByName("Moonkin Form")
end
function fo_castTreeForm()
    if fo_isTree() then
        return 
    end
    CastSpellByName("Tree of Life Form")
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
-- Form Specific Spellcasts
-- ==========================================================
-- Execute only in Bear or Dire Bear Form
function fo_bear(spellName, forceMouseover)
    if fo_isBear() then
        fo_cast(spellName, forceMouseover)
    end
end

-- Execute only in Cat Form
function fo_cat(spellName, forceMouseover)
    if fo_isCat() then
        fo_cast(spellName, forceMouseover)
    end
end

-- Execute only in Moonkin Form
function fo_moon(helpSpell, harmSpell, forceMouseover)
    if fo_isMoonkin() then
        fo_smartCast(helpSpell, harmSpell, forceMouseover)
    end
end

-- Execute only in Tree of Life Form
function fo_tree(helpSpell, harmSpell, forceMouseover)
    if fo_isTree() then
        fo_smartCast(helpSpell, harmSpell, forceMouseover)
    end
end

-- Execute only in Caster Form
function fo_caster(helpSpell, harmSpell, forceMouseover)
    if fo_isCaster() then
        fo_smartCast(helpSpell, harmSpell, forceMouseover)
    end
end

-- ==========================================================
-- DRUID LOGIC - Form Lock & Permission Engine
-- ==========================================================

-- Ensure the global table exists (prevents "nil" error)
fo_ClassHandlers = fo_ClassHandlers or {}

-- [A] BIT FLAGS for Permission Management
local F_HUMAN   = 1
local F_TREE    = 2
local F_MOONKIN = 4

-- 1. CASTER SPELL PERMISSIONS
local _spellPermissions = {
    -- ***WRITE IN LOWER CASE***
    -- Shared by ALL Caster Forms (Human, Tree, Moonkin)
    ["barkskin"]            = 7, -- F_HUMAN + F_TREE + F_MOONKIN
    ["faerie fire"]         = 7,
    ["entangling roots"]    = 7,
    ["hibernate"]           = 7,
    ["innervate"]           = 7,
    ["mark of the Wild"]    = 7,
    ["nature's grasp"]      = 7,
    ["remove curse"]        = 7,
    ["soothe animal"]       = 7,
    ["thorns"]              = 7,
    ["teleport: moonglade"] = 7,

    -- Restoration Special (Human and Tree ONLY)
    ["abolish poison"]      = 3, -- F_HUMAN + F_TREE
    ["cure poison"]         = 3,
    ["nature's swiftness"]  = 3,
    ["regrowth"]            = 3,
    ["rejuvenation"]        = 3,
    ["swiftmend"]           = 3,
    ["tranquility"]         = 3,

    -- Balance Special (Human and Moonkin ONLY)
    ["wrath"]               = 5, -- F_HUMAN + F_MOONKIN
    ["starfire"]            = 5,
    ["moonfire"]            = 5,
    ["insect swarm"]        = 5,
    ["hurricane"]           = 5,

    -- Human Only
    ["healing touch"]       = 1, -- F_HUMAN
}

-- 2. FERAL REQUIREMENTS (Bear, Cat, or Both)
local _formRequirements = {
    ["bash"] = {"bear form"}, ["challenging roar"] = {"bear form"}, 
    ["demoralizing roar"] = {"bear form"}, ["enrage"] = {"bear form"}, 
    ["feral charge"] = {"bear form"}, ["frenzied regeneration"] = {"bear form"}, 
    ["growl"] = {"bear form"}, ["maul"] = {"bear form"}, 
    ["savage bite"] = {"bear form"}, ["swipe"] = {"bear form"},
    ["claw"] = {"cat form"}, ["cower"] = {"cat form"}, ["dash"] = {"cat form"}, 
    ["ferocious bite"] = {"cat form"}, ["mangle"] = {"cat form"}, 
    ["pounce"] = {"cat form"}, ["prowl"] = {"cat form"}, ["rake"] = {"cat form"}, 
    ["ravage"] = {"cat form"}, ["rip"] = {"cat form"}, ["shred"] = {"cat form"}, 
    ["tiger's fury"] = {"cat form"}, ["track humanoids"] = {"cat form"},
    ["barkskin (feral)"] = {"bear form", "cat form"},
    ["berserk"] = {"bear form", "cat form"},
    ["faerie fire (feral)"] = {"bear form", "cat form"},
}

-- 3. THE CLASS HANDLER
fo_ClassHandlers["DRUID"] = function(spellName)
    -- [STEP 0] Normalize Input for Table Lookup
    -- Convert "enrage" to "Enrage", "regrowth" to "Regrowth"
    -- This ensures compatibility with _formRequirements and _spellPermissions keys.
    local normalizedName = string.upper(string.sub(spellName, 1, 1)) .. string.lower(string.sub(spellName, 2))
    local currentForm = _GetShapeshiftForm()

    -- [STEP 1] Determine the Lock Status
    local isFormLocked = false
    if fo_isBear() then isFormLocked = fo_Settings.lockBearForm
    elseif fo_isCat() then isFormLocked = fo_Settings.lockCatForm
    elseif fo_isMoonkin() then isFormLocked = fo_Settings.lockMoonkinForm
    elseif fo_isTree() then isFormLocked = fo_Settings.lockTreeForm
    end

    -- [STEP 2] Check Feral Requirements
    -- Use normalizedName to find the correct entry in our data tables
    local reqForms = _formRequirements[normalizedName]
    if reqForms then
        -- Check if current form is in the allowed list
        local isCorrectForm = false
        for _, fName in ipairs(reqForms) do
            -- Compatibility with GetBestBearForm via alias checks
            if (fName == "Bear Form" and fo_isBear()) or
               (fName == "Cat Form" and fo_isCat()) then
                isCorrectForm = true
                break
            end
        end

        if isCorrectForm then return true end

        -- Auto-Shapeshift logic
        if fo_Settings.autoShapeshift and not isFormLocked then
            if reqForms[2] then -- Shared spells (e.g., Berserk/Dash-equivalents)
                if fo_Settings.prioritizeBear then
                    fo_castBearForm() -- Automatically determines best Bear/Dire Bear
                else
                    fo_castCatForm()
                end
            else
                -- Single form requirements
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
        return false -- Stop execution while shifting
    end

    -- [STEP 3] Check Caster Permissions (Bit Flags)
    local allowedMask = _spellPermissions[normalizedName]
    if allowedMask then
        local currentFlag = 0
        if fo_isCaster() then currentFlag = F_HUMAN
        elseif fo_isTree() then currentFlag = F_TREE
        elseif fo_isMoonkin() then currentFlag = F_MOONKIN
        elseif fo_isBear() then currentFlag = 8
        elseif fo_isCat() then currentFlag = 16
        else currentFlag = 32 -- Travel, Aqua, etc.
        end

        -- Bitwise permission check
        local isAllowed = (math.mod(math.floor(allowedMask / currentFlag), 2) == 1)
        if isAllowed then return true end

        -- If not allowed, attempt to cancel current form
        if not isFormLocked and fo_Settings.autoCancelForm then
            fo_cancelForm()
        end
        return false
    end

    return true -- Pass through spells not found in the requirement/permission lists
end