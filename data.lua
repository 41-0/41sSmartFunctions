fo_Settings = fo_Settings or {}

fo_DefaultSettings = {
    -- Toggle Announce
    enableSuccessAnnounce = true,
    enableResistAnnounce = true,
    preventRageWasteDuringFR = true,

    -- Report Spells
    AnnounceSuccess = {
        -- Druid
        ["innervate"]   = "💎 INNERVATE!",
        ["frenzied regeneration"]   = "a",
        ["berserk"]   = "a",
        ["barkskin (feral)"]   = "s",
        ["tranquility"]   = "d",
        ["nature's swiftness"]   = "d",
        ["rebirth"]   = "d",
        -- Hunter
        -- Mage
        ["ice block"]   = "d",
        -- Pladin
        ["divine shield"]   = "d",
        ["lay on hands"]   = "d",
        ["hands of protection"]   = "d",
        -- Priest

        -- Rogue

        -- Shaman

        -- Warlock

        -- Warrior
        ["Shield Wall"] = "🛡️ SHIELD WALL ACTIVE!",

    },

    -- Report Resist
    AnnounceResist = {
        ["Taunt"] = "!! TAUNT RESIST !!",
        ["Growl"] = "!! GROWL RESIST !!",
    },

    -- Spells to stop during Frenzied Regeneration
    rageSpells = {
        ["maul"] = true,
        ["swipe"] = true,
    },
    -- Threshold to allow spending rage
    frenziedRegenThreshold = 80,
}