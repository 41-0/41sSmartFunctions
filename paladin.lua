-- Paladin aura helpers (WoW 1.12 / Lua 5.0).
local blessingNames = {
    might = true, wisdom = true, salvation = true,
    light = true, sanctuary = true, kings = true
}
local sealNames = {
    righteousness = true, crusader = true, wisdom = true,
    justice = true, light = true, command = true
}

local function normalizeName(name)
    if name == nil then return nil end
    if type(name) ~= "string" then return false end
    return string.lower((string.gsub(name, "^%s*(.-)%s*$", "%1")))
end

-- Read buff names, not textures: regular/Greater auras can share an icon.
local function hasPaladinAura(unit, names)
    if not unit or not UnitExists(unit) then return false end
    for i = 1, FO_MAX_UNIT_AURAS do
        if not UnitBuff(unit, i) then break end
        local name = fo_scan(
            function(scanner) scanner:SetUnitBuff(unit, i) end,
            function(scanner)
                local line = _G["FoAuraScannerTextLeft1"]
                return line and line:GetText()
            end
        )
        if type(name) == "string" and names[string.lower(name)] then
            return true
        end
    end
    return false
end

local function checkBlessing(version, name, arg2, arg3)
    name = normalizeName(name)
    if name == false or (name and not blessingNames[name]) then return false end
    local unit = fo_getSmartTarget(nil, arg2, arg3)
    local names = {}
    local shortName
    for shortName in pairs(blessingNames) do
        if not name or name == shortName then
            if version ~= "greater" then names["blessing of " .. shortName] = true end
            if version ~= "regular" then names["greater blessing of " .. shortName] = true end
        end
    end
    return hasPaladinAura(unit, names)
end

-- Optional name: might, wisdom, salvation, light, sanctuary, kings.
-- Target arguments follow the existing Smart Targeting System.
-- Use nil for name to check any Blessing on an explicit unit.
function fo_isRegularBlessingActive(name, arg2, arg3)
    return checkBlessing("regular", name, arg2, arg3)
end

function fo_isGreaterBlessingActive(name, arg2, arg3)
    return checkBlessing("greater", name, arg2, arg3)
end

function fo_isBlessingActive(name, arg2, arg3)
    return checkBlessing("either", name, arg2, arg3)
end

-- Seals always inspect the player, regardless of the selected target.
function fo_isSealActive(name)
    name = normalizeName(name)
    if name == false or (name and not sealNames[name]) then return false end
    local names = {}
    local shortName
    for shortName in pairs(sealNames) do
        if not name or name == shortName then
            names["seal of " .. shortName] = true
            -- The English client normally includes "the" in this Seal name.
            if shortName == "crusader" then names["seal of the crusader"] = true end
        end
    end
    return hasPaladinAura("player", names)
end

-- Compatibility with the lowercase spelling used in the request.
fo_isSealactive = fo_isSealActive

-- Keep an existing Seal; cast the requested Seal only when none is active.
function fo_castSeal(name)
    name = normalizeName(name)
    if not name or not sealNames[name] then return end
    if fo_isSealActive() then return end

    local spellName = "Seal of " .. name
    if name == "crusader" then spellName = "Seal of the Crusader" end
    fo_cast(spellName, "s")
end

-- Paladin Auras received by the player, including another Paladin's Aura.
local paladinAuraNames = {
    devotion = true, retribution = true, concentration = true,
    ["shadow resistance"] = true, ["fire resistance"] = true,
    ["frost resistance"] = true, sanctity = true
}

function fo_isPaladinAuraActive(name)
    name = normalizeName(name)
    if name == false or (name and not paladinAuraNames[name]) then return false end
    local names = {}
    local shortName
    for shortName in pairs(paladinAuraNames) do
        if not name or name == shortName then names[shortName .. " aura"] = true end
    end
    return hasPaladinAura("player", names)
end

-- Do not toggle off an Aura already selected on your own Aura bar.
function fo_castPaladinAura(name)
    name = normalizeName(name)
    if not name or not paladinAuraNames[name] then return end
    local spellName = name .. " aura"
    if GetNumShapeshiftForms and GetShapeshiftFormInfo then
        for i = 1, GetNumShapeshiftForms() do
            local texture, formName, active = GetShapeshiftFormInfo(i)
            if type(formName) == "string" and string.lower(formName) == spellName then
                if active and active ~= 0 then return end
                fo_cast(spellName, "s")
                return
            end
        end
    end
    -- Fallback for clients that do not expose the Aura on the stance bar.
    if not fo_isPaladinAuraActive(name) then fo_cast(spellName, "s") end
end
