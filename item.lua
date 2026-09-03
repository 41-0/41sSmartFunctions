-- ==========================================================
-- INTEGRATED ITEM SCANNER (Single-Pass for Performance)
-- ==========================================================

-- Priority Tables (English names)
local FO_PRIORITY_BANDAGE = {
    ["Crystal Infused Bandage"] = 22,
    ["Alterac Heavy Runecloth Bandage"] = 21,
    ["Arathi Basin Runecloth Bandage"] = 20,
    ["Defiler's Runecloth Bandage"] = 19,
    ["Heavy Runecloth Bandage"] = 18,
    ["Runecloth Bandage"] = 17,
    ["Arathi Basin Mageweave Bandage"] = 16,
    ["Highlander's Mageweave Bandage"] = 15,
    ["Warsong Gulch Mageweave Bandage"] = 14,
    ["Defiler's Mageweave Bandage"] = 13,
    ["Heavy Mageweave Bandage"] = 12,
    ["Mageweave Bandage"] = 11,
    ["Arathi Basin Silk Bandage"] = 10,
    ["Highlander's Silk Bandage"] = 9,
    ["Warsong Gulch Silk Bandage"] = 8,
    ["Defiler's Silk Bandage"] = 7,
    ["Heavy Silk Bandage"] = 6,
    ["Silk Bandage"] = 5,
    ["Heavy Wool Bandage"] = 4,
    ["Wool Bandage"] = 3,
    ["Heavy Linen Bandage"] = 2,
    ["Linen Bandage"] = 1
}

local FO_PRIORITY_HP = {
    ["Major Healing Potion"] = 7,
    ["Combat Healing Potion"] = 6,
    ["Superior Healing Potion"] = 5,
    ["Greater Healing Potion"] = 4,
    ["Healing Potion"] = 3,
    ["Lesser Healing Potion"] = 2,
    ["Minor Healing Potion"] = 1
}

local FO_PRIORITY_MANA = {
    ["Major Mana Potion"] = 7,
    ["Combat Mana Potion"] = 6,
    ["Superior Mana Potion"] = 5,
    ["Greater Mana Potion"] = 4,
    ["Mana Potion"] = 3,
    ["Lesser Mana Potion"] = 2,
    ["Minor Mana Potion"] = 1
}

-- Internal function: Scans all bags ONCE and finds the best of each category
local function fo_GetBestConsumables()
    local best = {
        bandage = { score = 0, bag = nil, slot = nil, name = nil },
        hp = { score = 0, bag = nil, slot = nil, name = nil, cd = false },
        mana = { score = 0, bag = nil, slot = nil, name = nil, cd = false }
    }

    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                -- Extract name from link: |c...[Item Name]|h...
                local _, _, name = string.find(link, "%[(.*)%]")
                if name then
                    -- Check Bandages
                    local bScore = FO_PRIORITY_BANDAGE[name]
                    if bScore and bScore > best.bandage.score then
                        best.bandage = { score = bScore, bag = bag, slot = slot, name = name }
                    end

                    -- Check HP Potions
                    local hScore = FO_PRIORITY_HP[name]
                    if hScore and hScore > best.hp.score then
                        local start, duration = GetContainerItemCooldown(bag, slot)
                        best.hp = { score = hScore, bag = bag, slot = slot, name = name, cd = (start > 0) }
                    end

                    -- Check Mana Potions
                    local mScore = FO_PRIORITY_MANA[name]
                    if mScore and mScore > best.mana.score then
                        local start, duration = GetContainerItemCooldown(bag, slot)
                        best.mana = { score = mScore, bag = bag, slot = slot, name = name, cd = (start > 0) }
                    end
                end
            end
        end
    end
    return best
end

-- PUBLIC API: Use Best Bandage
-- PUBLIC API: Use Best Bandage with Smart Targeting
function fo_bandage(a1, a2, a3)
    -- 1. Run the optimized single-pass scan
    local best = fo_GetBestConsumables()

    -- Check if any bandage was found
    if not best.bandage.bag then
        UIErrorsFrame:AddMessage("No bandages found!", 1.0, 0.1, 0.1)
        return false
    end

    -- 2. Resolve target using your Smart system (handles "s", "d", "m")
    local unit = fo_getSmartTarget("Bandage", a1, a2, a3)

    -- Handle "d" flag (nil) or missing unit
    if not unit or not UnitExists(unit) then
        return false
    end

    -- Safety: Check if the unit can actually be bandaged
    if not UnitCanAssist("player", unit) or UnitIsDeadOrGhost(unit) then
        return false
    end

    -- 3. Execution using Target Swap Method (1.12 Requirement)
    local currentTargetExists = UnitExists("target")
    local isTargetingUnit = UnitIsUnit("target", unit)

    if not isTargetingUnit then
        TargetUnit(unit)
        UseContainerItem(best.bandage.bag, best.bandage.slot)

        -- Restore original target state
        if currentTargetExists then
            TargetLastTarget()
        else
            ClearTarget()
        end
    else
        -- Target is already correct
        UseContainerItem(best.bandage.bag, best.bandage.slot)
    end

    return true
end

-- PUBLIC API: Use Best HP Potion
function fo_healthPot()
    local best = fo_GetBestConsumables()
    if best.hp.bag and not best.hp.cd then
        UseContainerItem(best.hp.bag, best.hp.slot)
        return true
    elseif best.hp.cd then
        UIErrorsFrame:AddMessage("Potion is on cooldown!", 1, 1, 0)
    end
    return false
end

-- PUBLIC API: Use Best Mana Potion
function fo_manaPot()
    local best = fo_GetBestConsumables()
    if best.mana.bag and not best.mana.cd then
        UseContainerItem(best.mana.bag, best.mana.slot)
        return true
    elseif best.mana.cd then
        UIErrorsFrame:AddMessage("Potion is on cooldown!", 1, 1, 0)
    end
    return false
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


-- PUBLIC API: Check if an item is ready to use
-- Works for both equipped items and items in bags
function fo_itemCD(name)
    if not UnitExists("player") then return false end -- Added safety guard
    if not name or name == "" then return false end
    local target = string.lower(name)

    -- Scan Equipment Slots
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link and string.find(string.lower(link), target) then
            local start, duration = GetInventoryItemCooldown("player", slot)
            return (start and start > 0 and duration and duration > 0) -- Added nil check
        end
    end

    -- Scan Bags
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(string.lower(link), target) then
                local start, duration = GetContainerItemCooldown(bag, slot)
                return (start and start > 0 and duration and duration > 0)
            end
        end
    end
    return false
end

-- PUBLIC API: Use item by name with smart CD checking and user feedback
function fo_item(name)
    if not UnitExists("player") then return false end -- Added safety guard
    if not name or name == "" then return false end
    local target = string.lower(name)
    local found = false
    local isEquipped, bagID, slotID = false, nil, nil

    -- 1. Search for the item safely
    -- We use a protected block to prevent access errors during UI rebuilds
    local ok = pcall(function()
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot)
            if link and string.find(string.lower(link), target) then
                isEquipped, slotID, found = true, slot, true; break
            end
        end
        if not found then
            for bag = 0, 4 do
                for slot = 1, GetContainerNumSlots(bag) do
                    local link = GetContainerItemLink(bag, slot)
                    if link and string.find(string.lower(link), target) then
                        bagID, slotID, found = bag, slot, true; break
                    end
                end
                if found then break end
            end
        end
    end)

    if not ok or not found then return false end

    -- 2. CD Check (using your updated safe version)
    if fo_itemCD(name) then
        UIErrorsFrame:AddMessage(name .. " is not ready yet.", 1.0, 1.0, 0.0)
        return false
    end

    -- 3. Execution
    if isEquipped then
        UseInventoryItem(slotID)
    else
        UseContainerItem(bagID, slotID)
    end
    return true
end


-- ==========================================================
-- Equipment Checker
-- ==========================================================

-- Internal helper to scan tooltips for specific keywords.
function fo_scanEquip(slotID, keyword)
    if not UnitName("player") then return false end
    if not GetInventoryItemLink("player", slotID) then return false end
    if not keyword or keyword == "" then return false end

    local targetKeyword = strlower(keyword)

    local found = fo_scan(
        function(scanner)
            return scanner:SetInventoryItem("player", slotID)
        end,
        function(scanner, hasItem)
            if not hasItem then
                return false
            end

            local numLines = scanner:NumLines()

            for i = 1, numLines do
                local leftObj = _G["FoAuraScannerTextLeft" .. i]
                local rightObj = _G["FoAuraScannerTextRight" .. i]

                local left = (leftObj and leftObj:GetText()) or ""
                local right = (rightObj and rightObj:GetText()) or ""
                local content = strlower(left .. " " .. right)

                if strfind(content, targetKeyword, 1, true) then
                    return true
                end
            end

            return false
        end
    )

    return found == true
end

-- fo_occupied: Returns true if the specified slot is occupied by an item.
function fo_occupied(s)
    return GetInventoryItemLink("player", s) ~= nil
end

-- fo_occupiedBy: Returns true if the slot is occupied by an item that contains the keyword.
function fo_occupiedBy(s, k)
    return fo_occupied(s) and fo_scanEquip(s, k)
end

-- fo_occupiedNotBy: Returns true if the slot is occupied by an item that does NOT contain the keyword.
function fo_occupiedNotBy(s, k)
    return fo_occupied(s) and not fo_scanEquip(s, k)
end

-- Returns true if a Shield is equipped
function fo_hasShield()
    return fo_occupiedBy(17, "Shield")
end

-- Returns true if a Two-Handed weapon is equipped
function fo_has2H()
    -- Check for "Two-Hand" (matches Two-Handed too)
    return fo_occupiedBy(16, "Two-Hand")
end

-- Returns true if Dual-Wielding weapons
function fo_hasDW()
    return fo_occupied(16) and fo_occupiedNotBy(17, "Held in Off-Hand") and fo_occupiedNotBy(17, "Shield")
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
    for i = 0, FO_MAX_UNIT_AURAS - 1 do
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
                    local buffName = fo_scan(
                        function(scanner)
                            scanner:SetPlayerBuff(id)
                        end,
                        function(scanner)
                            local leftObj = _G["FoAuraScannerTextLeft1"]
                            return (leftObj and leftObj:GetText()) or ""
                        end
                    ) or ""
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


function fo_startShoot()
    -- Check if already shooting
    if fo_isShooting() then
        return
    end

    -- Check if scan finds anything
    local found = false
    local weapons = {
        { "crossbow", "Shoot Crossbow" },
        { "wand",     "Shoot" },
        { "bow",      "Shoot Bow" },
        { "gun",      "Shoot Gun" },
        { "thrown",   "Throw" }
    }

    for _, data in ipairs(weapons) do
        if fo_scanEquip(18, data[1]) then
            -- DEFAULT_CHAT_FRAME:AddMessage("DEBUG: Weapon found: " .. data[1] .. ", casting: " .. data[2])
            CastSpellByName(data[2])
            found = true
            break
        end
    end

    -- if not found then
    --     DEFAULT_CHAT_FRAME:AddMessage("DEBUG: No valid weapon detected in slot 18.")
    -- end
end

-- Stops all current actions: Spell casting, Channeling, Auto-Attack, and Shooting.
function fo_break()
    -- 1. Stop Spell Casting
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