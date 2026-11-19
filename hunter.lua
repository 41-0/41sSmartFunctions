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
