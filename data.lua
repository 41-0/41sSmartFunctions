fo_Settings = fo_Settings or {}

fo_DefaultSettings = {
    selfCastEnabled = true,
    announceTauntResist = true,
    tauntSpells = {
        ["taunt"] = true,             -- Warrior
        ["mocking blow"] = true,      -- Warrior (Damage type)
        ["growl"] = true,             -- Druid
        ["hand of reckoning"] = true, -- Paladin
        ["earthshaker slam"] = true,  -- Shaman (TWoW Taunt)
    },

    autoCancelForm = true,
    autoShapeshift = true,
    prioritizeBear = true,
    lockBearForm = true,
    lockCatForm = false,
    lockMoonkinForm = false,
    lockTreeForm = false,
    frenziedRegenThreshold = 80, -- Threshold to allow spending rage
    preventRageWasteDuringFR = true,
    rageSpells = {               -- Spells to stop during Frenzied Regeneration
        ["maul"] = true,
        ["swipe"] = true,
    },
}
