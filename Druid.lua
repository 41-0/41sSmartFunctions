-- ==========================================================
-- Form Detection 
-- ==========================================================
function fo_isBear()
    return fo_aura("Ability_Racial_BearForm")
end

function fo_isCat()
    return fo_aura("Ability_Druid_CatForm")
end

function fo_isTravel()
    return fo_aura("Ability_Druid_TravelForm")
end

function fo_isAqua()
    return fo_aura("Ability_Druid_AquaticForm")
end

function fo_isMoonkin()
    return fo_aura("Spell_Nature_ForceOfNature")
end

function fo_isTree()
    return fo_aura("Ability_Druid_TreeofLife")
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
function fo_castBearForm()
    if fo_isBear() then
        return
    elseif fo_hasSpell('Dire Bear Form') then
        fo_cast('Dire Bear Form')
    else fo_cast('Bear Form')
    end
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


-- ==========================================================
-- Cancel Form Script
-- ==========================================================
-- Description: Cancels any active Druid shapeshift form.
-- Drectly cancells the buff
-- then falls back to CastShapeshiftForm if the buff is not found.
function fo_cancelForm()
    local found = false

    -- 1. Try to cancel the form by scanning active buffs
    -- This method works even when stunned or silenced (CC'd)
    for i = 0, 31 do
        local id = GetPlayerBuff(i, "HELPFUL")

        -- Check if a valid buff exists in this slot
        if (id and id ~= -1) then
            local tex = GetPlayerBuffTexture(id)
            
            -- Identify form buffs by checking the texture path keywords
            -- Using partial matches to cover different ranks and racial icons
            if tex and (string.find(tex, "BearForm") or 
                        string.find(tex, "CatForm") or 
                        string.find(tex, "TravelForm") or 
                        string.find(tex, "AquaticForm") or
                        string.find(tex, "MoonkinForm") or
                        string.find(tex, "TreeOfLifeForm")) then

                -- Cancel the buff by its dynamic index
                CancelPlayerBuff(id)
                found = true
                break -- Exit loop once the form is found and cancelled
            end
        end
    end

    -- 2. Fallback: If no buff was found (e.g., buff slot limit reached)
    -- Attempt to cancel via the shapeshift bar (does not work while stunned)
    if not found then
        for i = 1, GetNumShapeshiftForms() do
            local _, _, active = GetShapeshiftFormInfo(i)
            if active then
                -- Casting the active form again toggles it off
                CastShapeshiftForm(i)
                found = true
                break
            end
        end
    end

    return found
end




function listMyBuffIndices()
    for i = 0, 23 do
        -- i はスロット番号、index は APIで操作するためのID
        local index = GetPlayerBuff(i, "HELPFUL")
        
        -- index が -1 でなければ、そこにバフが存在する
        if (index > -1) then
            -- インデックスを使ってテクスチャパスを取得（名前判定の代わり）
            local texture = GetPlayerBuffTexture(index)
            
            -- デバッグ表示
            DEFAULT_CHAT_FRAME:AddMessage("Slot: "..i.." | Index: "..index.." | Texture: "..texture)
        end
    end
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

