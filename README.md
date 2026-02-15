# 41's Functions

**The Essential Utility Library for TWoW**

**Note: This AddOn is compatible with the English Client ONLY. Spell names and aura checks are hardcoded in English.**

<BR>

## Table of Contents

1. [Quick Start Examples](#quick-start-examples)
2. [Targeting Priority](#targeting-priority)
3. [Combat Utilities](#combat)
4. [Druid Specific Features](#druid-specific)

- [Form-Specific Wrappers](#form-specific-wrappers)
- [Shapeshifting](#shapeshifting)
- [Shapeshift Detection](#shapeshifting)
- [Auto-Shapeshift & Protection](#feature-auto-cancelformshapeshift-and-form-protection)

5. [Full Technical Reference (Advanced)](#full-technical-reference-advanced)

- [Aura Checker (fo_aura)](#-aura-checker-fo_aura)
- [Resource Checker (fo_RS)](#-resource-checker-fo_rs)
- [Cooldown Checker](#-cooldown-checker-fo_iscd)
- [Status / Equipment Checker](#boolean-checkers)

6. [Installation](#installation)

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

## <a id="combat"></a>⚔️Combat Utilities

### 1. `fo_startAttack(force)`

A non-toggling StartAttack function. It prevents the common Vanilla issue where spamming an attack macro turns the attack off.

- **`force`**: (Optional) If set to `1`, starts attacking even if you are Stealthed/Shadowmelded (breaking the effect).
- **Stealth Protection**: By default, it will **not** start attacking if you are in Stealth or Shadowmeld.

**Example:**

```lua
/script fo_cast("Sinister Strike")
/script fo_startAttack()

```

### 2. Smart Ranged Combat (`fo_startShoot`)

A unified shooting function designed for servers with specific weapon skills (like "Shoot Bow", "Shoot Gun", etc.).

### 🛠️ Features

- **Universal Support**: Automatically detects whether you should use `Shoot` (Wand), `Shoot Bow`, `Shoot Crossbow`, or `Shoot Gun`.
- **Anti-Toggle**: Specifically for Wands, this function ensures that spamming the macro will **not** stop your shooting animation.
- **Auto-Detection**: It scans your spellbook and uses the appropriate skill for your equipped weapon.

### 📝 Macro Example

```lua
-- Use your ranged weapon without worrying about spell names or toggling off wands
/script fo_startShoot()

```

### 3. Smart Stealth Entry (`fo_startStealth`)

A fail-safe stealth function that ensures you enter shadows without the risk of accidentally revealing yourself.

### 🛠️ Features

- **Anti-Toggle Protection**: Unlike the default stealth buttons, spamming this function will **never** cancel your stealth. It only activates the ability if you are currently visible.
- **Multi-Class Support**: Automatically detects and uses the appropriate ability for your character, supporting **Stealth** (Rogue), **Prowl** (Druid), and **Shadowmeld** (Night Elf).
- **Intelligent Priority**: It scans your spellbook and prioritizes class-based stealth over racial abilities to ensure the strongest effect is used first.

## 4. `fo_stopAll()`

The "Panic Button" function. It instantly halts every combat action your character is performing.

### 🛠️ Features

- **Spell Stop**: Instantly cancels any active spell cast or channeled spell (like _Tranquility_ or _Hurricane_).
- **Attack Stop**: Ceases auto-attack melee swings.
- **Range Stop**: Stops Wand shooting or Hunter Auto-Shot.

### 📝 Macro Example

#### The Emergency Stop

Useful for situations where you need to stop everything to CC a target or avoid reflecting damage:

```lua
/script fo_stopAll()

```

#### CC Protection

Stop everything before attempting to cast _Hibernate_ or _Entangling Roots_ to ensure no stray attacks break the CC:

```lua
/script fo_stopAll()
/script fo_cast("Hibernate")

```

---

<BR><BR>

## Druid Specific Features

### Form-Specific Wrappers

Optimized for one-line macros. Each checks for its specific form before attempting to cast.

- `fo_bear(spellName, forceMouseover)`
- `fo_cat(spellName, forceMouseover)`
- `fo_moon(helpSpell, harmSpell, forceMouseover)`
- `fo_tree(helpSpell, harmSpell, forceMouseover)`
- `fo_caster(helpSpell, harmSpell, forceMouseover)`

Examples

```lua
-- Handles every form,help and harm,also mouseover implemented with this simple macro
/script fo_bear('maul')
/script fo_cat('claw')
/script fo_tree('regrowth(rank 3)', 'faerie fire', 1)
/script fo_caster('healing touch(rank 4)', 'wrath')

```

If you can write if ~ then scripts, [Aura Checker](#-aura-checker-fo_aura), [Resource Checker](#-resource-checker-fo_rs) and much more are available!!

### Shapeshifting

Spam-safe shapeshifting. Unlike standard buttons, these will NOT cancel the form if pressed while already shifted.

- `fo_castBearForm()`
- `fo_castCatForm()`
- `fo_castAquaticForm()`
- `fo_castTravelForm()`
- `fo_castMoonkinForm()`
- `fo_castTreeForm()`
- `fo_cancelForm()`

### Shapeshift Detection

These return true or false. Use them for custom `/script if` logic.

- `fo_isBear()`     — True if in Bear or Dire Bear Form.
- `fo_isCat()`      — True if in Cat Form.
- `fo_isTravel()`   — True if in Travel Form.
- `fo_isAqua()`     — True if in Aquatic Form.
- `fo_isMoonkin()`  — True if in Moonkin Form.
- `fo_isTree()`     — True if in Tree of Life Form.
- `fo_isFeral()`    — True if in Bear or Cat Form.
- `fo_isCaster()`   — True if in Humanoid Form (no active shapeshift).

### Feature: Auto Cancelform/Shapeshift and Form Protection

This addon provides a seamless shapeshifting experience by managing form states automatically.
All core features can be toggled via the In-game Configuration Panel.

1. **Smart Auto-Shapeshift** When you cast a feral ability (e.g., Maul or Shred), the addon checks your current form. If you are in Humanoid or an incorrect form, it automatically shifts you into the appropriate form.
2. **Intelligent Auto-Cancelform** Eliminates "Can't use that in this form" errors. When casting non-feral spells (e.g., Healing Touch or Rejuvenation), the addon utilizes a hidden Aura Scanner to instantly cancel your current form.
3. **Advanced Form Protection (Form Lock)** To prevent accidental de-shifting during intense combat, you can enable Form Lock via the checkboxes.

**Note:** These features only apply to spells triggered via this addon's scripts (e.g., `/script fo_cast()`). Standard action bar buttons remain unaffected to preserve vanilla-like control when needed.

---

<BR><BR><BR>

# Full Technical Reference (Advanced)

For users who want to build complex custom macros, here is the complete list of available functions.

## 🔍 Aura Checker (`fo_aura`)

The Aura Checker system allows your macros to detect existing buffs or debuffs on a unit. This is essential for preventing mana waste from clipping DoTs or overwriting active buffs.

### Key Features

- **Automatic Rank Filtering**: Automatically strips rank information (e.g., `"Regrowth(Rank 5)"` → `"Regrowth"`).
- **Smart Detection**: Prioritizes mouseover targets.
- **Redundancy Prevention**: Easily build macros that only cast a spell if the target doesn't already have it.

### 🛠️ API Reference

| Function                     | Description                                     | Example Usage       |
| ---------------------------- | ----------------------------------------------- | ------------------- |
| **`fo_aura(spell, unit)`**   | Checks if the specific unit has the aura.       | `"Renew", "party1"` |
| **`fo_auraSelf(spell)`**     | Checks for an aura on the **Player**.           | `"Inner Fire"`      |
| **`fo_auraSmart(spell, f)`** | Checks the **Smart Target** (Mouseover/Target). | `"Rejuvenation"`    |

#### Arguments:

- **`spellName`**: The name of the buff/debuff or its **Texture Path**.
- **Name Match**: Use the standard display name (e.g., `"Moonfire"`).
- **Texture Match**: Use the internal texture name (e.g., `"Spell_Nature_Rejuvenation"`).
- **🔍 How to find textures**: Use `/script fo_showTargetTexture()` to print active texture names to chat.

- **`unit`**: A valid WoW unit ID (default is `"target"`).
- **`forceMouseover`**: If set to `1`, forces the check on the mouseover target.

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

- **Shorthand Support**: Use `l` for Life (Health) and `p` for Power (Mana/Rage/Energy).
- **Dynamic Thresholds**: Supports absolute values (`500`) and percentage strings (`"30%"`).

### 🛠️ API Reference

| Function                           | Description                            | Example Usage            |
| ---------------------------------- | -------------------------------------- | ------------------------ |
| **`fo_RS(stat, op, val, unit)`**   | Checks status of a specific unit.      | `"l", ">", "50%", "pet"` |
| **`fo_RSSelf(stat, op, val)`**     | Shorthand for checking the **Player**. | `"p", "<", 100`          |
| **`fo_RSSmart(stat, op, val, f)`** | Checks the **Smart Target**.           | `"l", "<", "20%"`        |

#### Arguments:

- **`stat`**: `l` (Health) or `p` (Power/Mana/Rage/Energy).
- **`op`**: Logical operators: `>`, `<`, `>=`, `<=`, `==`.
- **`val`**: Threshold number (`500`) or percentage (`"50%"`).

### 📝 Macro Examples

```lua
-- Swiftmend if target < 30% HP
/script if fo_RSSmart("l", "<", "30%") then fo_cast("Swiftmend") end

-- Barkskin if Mana > 10% and HP < 1000
/script if fo_RSSelf("p", ">", "10%") and fo_RSSelf("l", "<", 1000) then fo_cast("Barkskin") end

```

<BR><BR>

## ⏳ Cooldown Checker (`fo_isCD`)

The `fo_isCD` function returns `true` if a spell is currently on cooldown. It is designed to ignore the Global Cooldown (GCD), so it only returns `true` for actual ability cooldowns (like the 15s on _Swiftmend_).

### 🛠️ API Reference

| Function            | Description                                                | Example Usage |
| ------------------- | ---------------------------------------------------------- | ------------- |
| **`fo_isCD(name)`** | Returns `true` if the spell is on cooldown (ignoring GCD). | `"Swiftmend"` |

### 📝 Macro Example

#### Fallback Logic

If _Swiftmend_ is on cooldown, cast _Regrowth_ instead. Otherwise, cast _Swiftmend_:

```lua
/script if fo_isCD("Swiftmend") then fo_cast("Regrowth") else fo_cast("Swiftmend") end

```

---

<BR><BR>

## <a id="boolean-checkers"></a>🔍 Status / Equipment Checker

These functions return either `true` or `false`. They are essential for creating conditional macros that adapt to your current gear, talents, and combat state.

### 🛡️ Equipment State (`has` series)

Identify your currently equipped gear. These functions use tooltip scanning to ensure accuracy even during weapon swaps.

| Function             | Returns `true` if...                                   |
| -------------------- | ------------------------------------------------------ |
| **`fo_hasShield()`** | A **Shield** is equipped in your off-hand.             |
| **`fo_has2H()`**     | A **Two-Handed** weapon is equipped in your main-hand. |
| **`fo_hasDW()`**     | You are **Dual-Wielding** (Weapons in both MH and OH). |

### 📘 Knowledge State

| Function                  | Returns `true` if...                                |
| ------------------------- | --------------------------------------------------- |
| **`fo_hasSpell("Name")`** | The specified spell or talent is in your spellbook. |

- **`spellName`**: The exact name of the spell (Case-insensitive).

#### 💡 Use Case: Spec-Specific Macros

If you frequently switch between specs (e.g., Feral and Restoration), you can use one macro that detects your active talents:

```lua
-- Cast Swiftmend if you have the talent, otherwise cast Regrowth
/script if fo_hasSpell("Swiftmend") then fo_cast("Swiftmend") else fo_cast("Regrowth") end

```

### ⚔️ Combat & Action State

Useful for fine-tuning macro behavior based on your character's current activity.

| Function               | Returns `true` if...                                    |
| ---------------------- | ------------------------------------------------------- |
| **`fo_isStealth()`**   | You are currently Stealthed, Prowling, or Shadowmelded. |
| **`fo_isShooting()`**  | You are currently using a Wand or Ranged Auto-shot.     |
| **`fo_isAttacking()`** | You are currently in Melee Auto-attack mode.            |

---

### 📝 Practical Logic Examples

#### **Adaptive Rotation**

```lua
-- Casts Shield Slam if you have a shield, otherwise casts Mortal Strike
/script if fo_hasShield() then fo_cast("Shield Slam") elseif fo_has2H() then fo_cast("Mortal Strike") end

```

#### **Dynamic Talent Logic**

```lua
-- Only attempts to use the talent if it's currently learned
/script if fo_hasSpell("Holy Shock") then fo_cast("Holy Shock") else fo_cast("Flash of Light") end

```

---

<BR><BR>

# Installation

1. Download this repository.
2. Move the `41sFunctions` folder into your `Interface/AddOns/` directory.
3. Restart World of Warcraft.

---
