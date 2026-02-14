# 41's Functions

**The Essential Utility Library for TWoW**

**Note: This AddOn is compatible with the English Client ONLY. Spell names and aura checks are hardcoded in English.**

<BR>

## Table of Contents

1. [Quick Start Examples](https://www.google.com/search?q=%23quick-start-examples)
2. [Targeting Priority](https://www.google.com/search?q=%23targeting-priority)
3. [Druid Specific Features](https://www.google.com/search?q=%23druid-specific)
* [Form-Specific Wrappers](https://www.google.com/search?q=%23form-specific-wrappers)
* [Shapeshifting](https://www.google.com/search?q=%23shapeshifting)
* [Shapeshift Detection](https://www.google.com/search?q=%23shapeshift-detection-booleans)


4. [Auto-Shapeshift & Protection](https://www.google.com/search?q=%23feature-auto-cancelformshapeshift-and-form-protection)
5. [Full Technical Reference (Advanced)](https://www.google.com/search?q=%23full-technical-reference-advanced)
* [Aura Checker (fo_aura)](https://www.google.com/search?q=%23-aura-checker-fo_aura)
* [Resource Checker (fo_RS)](https://www.google.com/search?q=%23-resource-checker-fo_rs)


6. [Installation](https://www.google.com/search?q=%23installation)

---

# Quick Start Examples

Smart Casting with Integrated Mouseover Support.
A unified casting system that seamlessly combines mouseover priority with standard target logic.

```lua
/script fo_cast("Renew")
/script fo_smartCast("Rejuvenation", "Moonfire")    --rejuv on friend, MF on enemy

```

## Targeting Priority

For all scripts provided by this addon, the default target priority is:

1. **Mouseover** (Friend only)
2. **Current Target**
3. **Self-cast** (Fallback, option)

### Enabling Mouseover on Enemies

#### To enable hostile mouseover, add 1 (any truthy value) as the final argument:

```lua
-- Now "Wrath" can be cast on your mouseover target!
/script fo_smartCast("Regrowth", "Wrath", 1)

-- Works for fo_cast too
/script fo_cast("Polymorph", 1)

```

<BR><BR>

## Druid Specific

### Form-Specific Wrappers

Optimized for one-line macros. Each checks for its specific form before attempting to cast.

* `fo_bear(spellName, forceMouseover)`
* `fo_cat(spellName, forceMouseover)`
* `fo_moon(helpSpell, harmSpell, forceMouseover)`
* `fo_tree(helpSpell, harmSpell, forceMouseover)`
* `fo_caster(helpSpell, harmSpell, forceMouseover)`

### Shapeshifting

Spam-safe shapeshifting. Unlike standard buttons, these will NOT cancel the form if pressed while already shifted.

* `fo_castBearForm()`
* `fo_castCatForm()`
* `fo_castAquaticForm()`
* `fo_castTravelForm()`
* `fo_castMoonkinForm()`
* `fo_castTreeForm()`
* `fo_cancelForm()`

### Shapeshift Detection (Booleans)

These return true or false. Use them for custom `/script if` logic.

* `isBear()` — True if in Bear or Dire Bear Form.
* `isCat()` — True if in Cat Form.
* `isTravel()` — True if in Travel Form.
* `isAqua()` — True if in Aquatic Form.
* `isMoonkin()` — True if in Moonkin Form.
* `isTree()` — True if in Tree of Life Form.
* `isFeral()` — True if in Bear or Cat Form.
* `isCaster()` — True if in Humanoid Form (no active shapeshift).

---

## Feature: Auto Cancelform/Shapeshift and Form Protection

This addon provides a seamless shapeshifting experience by managing form states automatically.
All core features can be toggled via the In-game Configuration Panel.

1. **Smart Auto-Shapeshift** When you cast a feral ability (e.g., Maul or Shred), the addon checks your current form. If you are in Humanoid or an incorrect form, it automatically shifts you into the appropriate form.
2. **Intelligent Auto-Cancelform** Eliminates "Can't use that in this form" errors. When casting non-feral spells (e.g., Healing Touch or Rejuvenation), the addon utilizes a hidden Aura Scanner to instantly cancel your current form.
3. **Advanced Form Protection (Form Lock)** To prevent accidental de-shifting during intense combat, you can enable Form Lock via the checkboxes.

> **Note:** These features only apply to spells triggered via this addon's scripts (e.g., `/script fo_cast()`). Standard action bar buttons remain unaffected to preserve vanilla-like control when needed.

---

<BR><BR><BR>

# Full Technical Reference (Advanced)

For users who want to build complex custom macros, here is the complete list of available functions.

## 🔍 Aura Checker (`fo_aura`)

The Aura Checker system allows your macros to detect existing buffs or debuffs on a unit. This is essential for preventing mana waste from clipping DoTs or overwriting active buffs.

### Key Features

* **Automatic Rank Filtering**: Automatically strips rank information (e.g., `"Regrowth(Rank 5)"` → `"Regrowth"`).
* **Smart Detection**: Prioritizes mouseover targets.
* **Redundancy Prevention**: Easily build macros that only cast a spell if the target doesn't already have it.

### 🛠️ API Reference

| Function | Description | Example Usage |
| --- | --- | --- |
| **`fo_aura(spell, unit)`** | Checks if the specific unit has the aura. | `"Renew", "party1"` |
| **`fo_auraSelf(spell)`** | Checks for an aura on the **Player**. | `"Inner Fire"` |
| **`fo_auraSmart(spell, f)`** | Checks the **Smart Target** (Mouseover/Target). | `"Rejuvenation"` |

#### Arguments:

* **`spellName`**: The name of the buff/debuff or its **Texture Path**.
* **Name Match**: Use the standard display name (e.g., `"Moonfire"`). **Case-sensitive.**
* **Texture Match**: Use the internal texture name (e.g., `"Spell_Nature_Rejuvenation"`).
* **🔍 How to find textures**: Use `/script fo_showTargetTexture()` to print active texture names to chat.


* **`unit`**: A valid WoW unit ID (default is `"target"`).
* **`forceMouseover`**: If set to `1`, forces the check on the mouseover target.

### 📝 Macro Examples

```lua
-- Cast only if missing buff
/script if not fo_auraSmart("Rejuvenation") then fo_cast("Rejuvenation") end

-- Using textures to avoid localization issues
/script if not fo_auraSmart("Spell_Nature_Rejuvenation") then fo_cast("Rejuvenation") end

```

---

<BR><BR>

## 📊 Resource Checker (`fo_RS`)

The `fo_RS` system allows for complex health and resource checks using ultra-short syntax to fit within the 255-character limit.

### Key Features

* **Shorthand Support**: Use `l` for Life (Health) and `p` for Power (Mana/Rage/Energy).
* **Dynamic Thresholds**: Supports absolute values (`500`) and percentage strings (`"30%"`).

### 🛠️ API Reference

| Function | Description | Example Usage |
| --- | --- | --- |
| **`fo_RS(stat, op, val, unit)`** | Checks status of a specific unit. | `"l", ">", "50%", "pet"` |
| **`fo_RSSelf(stat, op, val)`** | Shorthand for checking the **Player**. | `"p", "<", 100` |
| **`fo_RSSmart(stat, op, val, f)`** | Checks the **Smart Target**. | `"l", "<", "20%"` |

#### Arguments:

* **`stat`**: `l` (Health) or `p` (Power/Mana/Rage/Energy).
* **`op`**: Logical operators: `>`, `<`, `>=`, `<=`, `==`.
* **`val`**: Threshold number (`500`) or percentage (`"50%"`).

### 📝 Macro Examples

```lua
-- Swiftmend if target < 30% HP
/script if fo_RSSmart("l", "<", "30%") then fo_cast("Swiftmend") end

-- Barkskin if Mana > 10% and HP < 1000
/script if fo_RSSelf("p", ">", "10%") and fo_RSSelf("l", "<", 1000) then fo_cast("Barkskin") end

```

---

<BR><BR>

# Installation

1. Download this repository.
2. Move the `41sFunctions` folder into your `Interface/AddOns/` directory.
3. Restart World of Warcraft.

---