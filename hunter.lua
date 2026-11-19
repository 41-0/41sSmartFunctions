-- Hunter macro helpers (WoW 1.12 / Lua 5.0).
-- Example: fo_hunterPetFocus(">=50")
function fo_hunterPetFocus(condition)
    if type(condition) ~= "string" then return false end

    local _, _, op, amount = string.find(condition, "^%s*([<>=!~]+)%s*(%d+)%s*$")
    if not op then return false end

    if not fo_isHunter("player") or not UnitExists("pet")
        or UnitIsDead("pet") or UnitPowerType("pet") ~= 2 then
        return false
    end

    -- In 1.12, UnitMana reads the unit's current power, including focus.
    local focus = UnitMana("pet")
    local threshold = tonumber(amount)
    if type(focus) ~= "number" or not threshold then return false end

    if op == ">=" then return focus >= threshold end
    if op == "<=" then return focus <= threshold end
    if op == ">" then return focus > threshold end
    if op == "<" then return focus < threshold end
    if op == "=" or op == "==" then return focus == threshold end
    if op == "~=" or op == "!=" then return focus ~= threshold end
    return false
end

local aspectNames = {
    monkey = true, hawk = true, wolf = true, cheetah = true,
    pack = true, beast = true, wild = true, viper = true
}
local function normalizeAspect(name)
    if name == nil then return nil end
    if type(name) ~= "string" then return false end
    return string.lower((string.gsub(name, "^%s*(.-)%s*$", "%1")))
end

-- Inspect Aspects received by the player (including another Hunter's Pack).
function fo_isAspectActive(name)
    name = normalizeAspect(name)
    if name == false or (name and not aspectNames[name]) then return false end
    if not UnitExists("player") then return false end
    for i = 1, FO_MAX_UNIT_AURAS do
        if not UnitBuff("player", i) then break end
        local buffName = fo_scan(
            function(scanner) scanner:SetUnitBuff("player", i) end,
            function(scanner)
                local line = _G["FoAuraScannerTextLeft1"]
                return line and line:GetText()
            end
        )
        if type(buffName) == "string" then
            buffName = string.lower(buffName)
            if name then
                if buffName == "aspect of the " .. name then return true end
            else
                local shortName
                for shortName in pairs(aspectNames) do
                    if buffName == "aspect of the " .. shortName then return true end
                end
            end
        end
    end
    return false
end

-- Preserve the requested Aspect; switch from a different Aspect when needed.
function fo_castAspect(name)
    name = normalizeAspect(name)
    if not name or not aspectNames[name] then return end
    local spellName = "aspect of the " .. name
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
    if not fo_isAspectActive(name) then fo_cast(spellName, "s") end
end
