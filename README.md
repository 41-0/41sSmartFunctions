# 41's Druid Functions

**The Essential Utility Library for Vanilla WoW (1.12.1) Druids**

**Note: This AddOn is compatible with the English Client ONLY. Spell names and aura checks are hardcoded in English.**


## Quick Start Examples

You can easily create form-specific macros. Simply describe the spells for each form within the same macro:

```lua
/script fo_bear("Maul")                      -- In bear form: Maul
/script fo_cat("Claw")                       -- In cat form: Claw
/script fo_caster("Rejuvenation", "Wrath")   -- In caster form: Rejuvenation on friend, Wrath on enemy
```

### Form-Specific Logic

Bear and Cat only require 1 argument (Harmful spell).
```lua
/script fo_bear("Spell")
/script fo_cat("Spell")
```

Others require 2 arguments (Helpful spell, then Harmful spell).
You can use an empty string "" as an argument if you want to skip either the helpful or harmful spell.

```lua
/script fo_moon("Help", "Harm")
/script fo_tree("Help", "Harm")
/script fo_caster("Help", "Harm")
```

---

## Targeting Priority

By default, the priority order for targets is:

1. **Mouseover** (Helpful spells only)
2. **Current Target**
3. **Self-cast** (Helpful spells only)

### Enabling Mouseover for Harmful Spells

If you want to cast harmful spells on a Mouseover target, add **`1`** as the final argument:

```lua
-- Now "Wrath" can be cast on your mouseover target!
/script fo_caster("Rejuvenation", "Wrath", 1)

-- Works for Feral forms too
/script fo_bear("Faerie Fire (Feral)", 1)

```

---

## Key Feature: Bear Protection
This library includes built-in safety. 

**As long as you are using these addon scripts (macros),** the library will automatically **block** helpful spells that would force you to de-shift while in Bear Form.

This prevents accidental wipes caused by "double-tapping" a heal button while tanking.


---
## Full Technical Reference (Advanced)

For users who want to build complex custom macros, here is the complete list of available functions in 41's Druid Functions.


### Shapeshift Detection (Booleans)

These return true or false. Use them for custom /script if logic.

    isBear() — True if in Bear or Dire Bear Form.

    isCat() — True if in Cat Form.

    isTravel() — True if in Travel Form.

    isAqua() — True if in Aquatic Form.

    isMoonkin() — True if in Moonkin Form.

    isTree() — True if in Tree of Life Form.

    isFeral() — True if in Bear or Cat Form.

    isCaster() — True if in Humanoid Form (no active shapeshift).



---

### Casting Engines

These are the core functions that handle the "heavy lifting" of your macros.

#### `fo_cast(spellName, forceMouseover)`

The base casting engine for single spells.

* **Mouseover Priority**: Automatically prioritizes your mouseover target. If `forceMouseover` is set to `1`, this applies to harmful spells as well.
* **Bear Protection**: While in **Bear Form**, this function will **completely ignore helpful spells**. It will not attempt to cast them, ensuring you never accidentally de-shift while tanking.
* **Auto-Dismount**: Automatically attempts to dismount you or cancel Travel/Aquatic forms to ensure the spell is cast.
* **Syntax Fix**: Automatically handles the specific Vanilla WoW syntax for `Faerie Fire (Feral)`.

#### `fo_smartCast(helpSpell, harmSpell, forceMouseover)`

The intelligent hybrid engine that decides which spell to use based on your target's reaction.

* **Target Reaction**: Casts `helpSpell` on friendly targets and `harmSpell` on hostile targets.
* **Mouseover Priority**: Prioritizes mouseover targets for healing. If `forceMouseover` is `1`, it also enables mouseover targeting for harmful spells.
* **Bear Protection**: While in **Bear Form**, this function will **completely ignore helpful spells**. It will not attempt to cast them, ensuring you never accidentally de-shift while tanking.
* **Auto-Dismount**: Automatically dismounts you or cancels Travel/Aquatic forms when a valid spell is triggered.

---

### Form-Specific Wrappers

Optimized for one-line macros. Each checks for its specific form before attempting to cast.

    fo_bear(spellName, forceMouseover)

    fo_cat(spellName, forceMouseover)

    fo_moon(helpSpell, harmSpell, forceMouseover)

    fo_tree(helpSpell, harmSpell, forceMouseover)

    fo_caster(helpSpell, harmSpell, forceMouseover)

### Shapeshifting

Spam-safe shapeshifting. Unlike standard buttons, these will NOT cancel the form if pressed while already shifted.


    fo_castBearForm()

    fo_castCatForm()

    fo_castAquaticForm()

    fo_castTravelForm()

    fo_castMoonkinForm()

    fo_castTreeForm()

    fo_cancelForm()
    

### Utilities


    fo_dismount()  - Safe dismount for mounts and travel forms. ***Inpomplete*** May not work.

    fo_isAuraActive("auraName")  - Checks if a specific buff/debuff is active on the target.

    fo_hasTexture("path")  - Checks for a buff/debuff via its texture path.

    fo_showTargetTexture()  - Diagnostic Tool: Prints the texture paths of all current buffs on your target to the chat frame.

### Technical Tips for Advanced Users

    Global Namespace: All functions are prefixed with fo_ or is to ensure compatibility with other AddOns like LunaUnitFrames or ClassicCastBars.

    Syntax Correction: The library detects faerie fire (feral) (case-insensitive) and automatically appends the required () for the 1.12.1 engine, making your macros more robust.

---

## Installation

1. Download this repository.
2. Move the `41sDruidFunctions` folder into your `Interface/AddOns/` directory.
3. Restart World of Warcraft.


---
## Aura Check Functions

These functions allow you to check if a specific buff or debuff is active. They support both **Spell Names** and **Texture Path segments** (e.g., "StarFall").

### `fo_isAuraActive(name, [unit])`

**Manual Target Version**
Checks for an aura on a specific unit.

* **Parameters**:
* `name`: Spell name or texture string.
* `unit`: (Optional) Any valid unit ID (e.g., `"target"`, `"pet"`, `"party1"`). Defaults to `"target"`.


* **Example**: `/script if not fo_isAuraActive("Moonfire", "target") then cast... end`

### `fo_isPlayerAuraActive(name)`

**Self-Only Version**
A dedicated function to check your own status. It is hardcoded to `"player"`, making it ideal for checking your own forms or procs without worrying about your current target.

* **Example**: `/script if fo_isPlayerAuraActive("Cat Form") then ... end`

### `fo_isSmartAuraActive(name, [force])`

**Smart Target Version (with mouseover override)**
Checks for an aura using the addon's intelligent targeting logic. It prioritizes your mouseover target if applicable, then falls back to your current target.

* **Parameters**:
* `force`: (Optional) Set to `true` to force mouseover check.


* **Example**: Use this to maintain buffs like "Rejuvenation" on the most relevant ally.

---