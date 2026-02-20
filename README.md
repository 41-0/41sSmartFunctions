# 41's Smart Functions

**The Essential Utility Library for TWoW**

**Note: This AddOn is compatible with the English Client ONLY. Spell names and aura checks are hardcoded in English.**

<BR>

## Table of Contents

1. [Quick Start Examples](#quick-start-examples)
2. [Targeting Priority](#sts)
3. [Combat Utilities](#combat)
4. [Items & Consumables](#items)
5. [Druid Specific Features](#druid-specific-features)
6. [Full Technical Reference (Advanced)](#full-technical-reference-advanced)

- [Aura Checker (fo_aura)](#-aura-checker-fo_aura)
- [Resource Checker (fo_RS)](#resource-checker)
- [Cooldown Checker](#cd-checker)
- [Status / Equipment Checker](#boolean-checkers)

7. [Installation](#installation)


<BR><BR>

# Quick Start Examples

## Core Functions

The engine automatically handles Mouseover, Target, and Self-cast logic.

```lua
-- Smart Casting
/script fo_cast("Renew")

-- Dual Casting (Auto-switches based on friendly / hostile)
-- Casts "Rejuvenation" on friends, "Moonfire" on enemies.
/script fo_castDual("Rejuvenation", "Moonfire")
```

#### [!IMPORTANT] Always place the Helpful spell first (left) and the Harmful spell second (right).


## <a id="sts"></a>🎯 Smart Target System (STS)

Many function in this addon shares the **STS** logic. This universal targeting engine manages how spells and items are directed, from friendly heals to hostile DoTs.

### 🌊 Priority Logic (The "Smart" Flow)

By default, the system follows a 3-step priority to ensure you never lose a beat in combat:

1. **Mouseover (Friendly)**: Priority #1 for heals/buffs.
2. **Target**: Falls back to your current target.
3. **Self-Cast (Optional)**: Casts on yourself if no other valid target is found.

> [!IMPORTANT]
> **Selective Self-Cast**: You can disable the automatic self-cast fallback **[globally or per macro]** to prevent accidental mana waste.

---

### 🚩 Targeting Flags & Overrides

| Flag / Input | Mode | Description |
| --- | --- | --- |
| *(None)* | **Smart Support** | `MO(Friend) > Target > Self` |
| **`"m"`** | **Smart w/ Hostile MO** | `MO(Friend/Enemy) > Target > Self`. |
| **`"d"`** | **Disable Self** | `MO > Target`. |
| **`"s"`** | **Fixed Self** | Forces action on **Player** only. |
| **`"party1" etc`** | **Fixed Unit** | Directly targets a specific **WoW UnitID**. Note "mouseover" is a wow unitID(fixed). |

---

### 📝 Macro Examples

```lua
-- 1. Standard Smart Heal (MO > Target > Self)
/script fo_cast("Renew")

-- 2. Smart Heal WITHOUT Self-Cast Fallback
-- (If no MO or Target, it does nothing. Prevents accidental self-buffing.)
/script fo_cast("Renew", "d")

-- 3. Dual Cast with Hostile Mouseover Enabled
-- Casts Remove Curse of Friend, Counterspell on Enemy(including mouseover).
/script fo_castDual("Remove Lesser Curse", "Counterspell", "m")

-- 4. Fixed Target
-- Insert "s"(self-cast) or WoW UnitID.
/script fo_cast("Smite", "targettarget")

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

<BR>

### 2. Smart Ranged Combat (`fo_startShoot`)

A unified shooting function designed for servers with specific weapon skills (like "Shoot Bow", "Shoot Gun", etc.).

- **Universal Support**: Automatically detects whether you should use `Shoot` (Wand), `Shoot Bow`, `Shoot Crossbow`, or `Shoot Gun`.
- **Anti-Toggle**: Specifically for Wands, this function ensures that spamming the macro will **not** stop your shooting animation.

### 📝 Macro Example

```lua
-- Use your ranged weapon without worrying about spell names or toggling off wands
/script fo_startShoot()
```

<BR>

### 3. Smart Stealth Entry (`fo_startStealth`)

A fail-safe stealth function that ensures you enter shadows without the risk of accidentally revealing yourself.

- **Anti-Toggle Protection**: Unlike the default stealth buttons, spamming this function will **never** cancel your stealth. It only activates the ability if you are currently visible.
- **Multi-Class Support**: Automatically detects and uses the appropriate ability for your character, supporting **Stealth** (Rogue), **Prowl** (Druid), and **Shadowmeld** (Night Elf).


<BR>

### 4. `fo_break()`

Stops your casting (not channeling), auto attack, shoot.

### 📝 Macro Example

```lua
/script fo_break()
/script fo_cast('counterspell', 1)
```

















<BR>

### 5. Taunt Resist Announcements

Automatically notifies your group when your taunt-related abilities are resisted or fail to land. 

* **How it works**: Monitors your combat log and announces failures (Resist, Miss, Dodge, Parry, Immune) to the appropriate channel (Party, Raid, or Instance).
* **Supported Spells**:
* **Warrior**: Taunt, Mocking Blow
* **Druid**: Growl
* **Paladin**: Hand of Reckoning
* **Shaman**: Earthshaker Slam

* **Toggle**: Can be enabled or disabled via the **General** tab in the settings menu.

<BR>

### 6. Smart Healing Engine (Experimental, not optimal)

The `fo_autoRankDual` function acts as an intelligent abstraction layer for your healing rotation. Instead of manually checking health levels and calculating ranks in your main macros, this function dynamically evaluates the current combat state and constructs the appropriate spell command.

#### ### How it works

```lua
/script fo_autoRankDual(helpSpell, harmSpell)
-- Defaults: Ranks 3/5/Max, Thresholds 25%/50%
```

Full syntax:

`fo_autoRankDual(helpSpell, harmSpell, lowHelpRank, midHelpRank, highHelpRank, lowThreshold, midThreshold)`

#### ### Usage Example

```lua
--If target does not have Rejuvenation, cast it depending on its health.
/script if not fo_aura('rejuvenation') then fo_autoRankDual("rejuvenation", "insect swarm", 3, 5, "max", "30%", "60%")
```


```lua
-- Custom thresholds: 
-- Ranks 3/5/Max used at 30% and 60% Life Deficit.
-- NOTE: Accepts strings (e.g., "30%") or raw numbers (e.g., 1000).
/script fo_autoRankDual("Healing Touch", "Wrath", 3, 5, "max", "30%", "60%")
```


<BR><BR>

## <a id="items"></a>🎒 Items & Consumables

This module provides a unified interface for using items, whether they are consumables in your bags or powerful artifacts equipped on your character. It includes smart cooldown detection and prioritized logic to ensure you never waste a click.

### 🛠️ Core Item Functions

| Function | Description |
| --- | --- |
| `fo_item("name")` | **The Universal Item Tool.** Scans equipment slots first, then bags. It includes a built-in safety check to prevent "Not Ready" spam if the item is on cooldown. |
| `fo_itemCD("name")` | A utility function that returns `true` if the specified item (equipped or in bags) is on Cooldown. |

`fo_item` mimics the standard "Right-Click" behavior of your inventory

---

### 🧪 Smart Consumables

These functions automate the selection of the best available consumable in your inventory.

#### `fo_healthPot()` / `fo_manaPot()`

Automatically scans your bags and uses the **highest-tier** potion available.

* **Logic**: Priority flows from Major → Superior → Greater → Standard → Lesser → Minor.
* **Efficiency**: Saves macro space by using one command for all tiers of potions.

#### `fo_bandage()`

Prioritizes using the best bandage in your inventory.

* **Smart Target**: Follows Smart Targeting System.
* **Priority**: Heavy Runecloth → Runecloth → Heavy Mageweave, etc.

---

### 🚀 Advanced Usage & Macros

Because these functions handle the "Is it ready?" and "Where is it?" logic internally, your in-game macros become significantly shorter and more readable.

**1. The Panic Button**
Use your most powerful defensive item if available; otherwise, fallback to a standard health potion.

```lua
/script if not fo_item("Limited Invulnerability Potion") then fo_healthPot() end
```

**2. Trinket & Spell Combo**
Activate a specific trinket (like *Zandalarian Hero Charm*) only if it's ready, then proceed to cast your main spell.

```lua
/script fo_item("Zandalarian")
/cast Shadow Bolt
```

**3. Strategic Bandaging**
Use a bandage only if you are out of combat or have a specific window, without worrying about wasting the item on a debuffed target.

```lua
/script if fo_RS("hp < 50%", "s") then fo_bandage() end
```

---

### 📢 User Feedback System

To keep you informed without cluttering your screen, the item system uses two types of notifications:

* **Missing Items**: Displayed in the **Chat Frame** (e.g., `[fo] Item not found: Heavy Runecloth Bandage`).
* **Cooldowns**: Displayed as a **Yellow Warning** in the center of the screen (e.g., `Celestial Orb is not ready yet`), suppressing the default red text spam and system error sounds.








---

<BR><BR>

## Druid Specific Features

### Form-Specific Wrappers

Optimized for one-line macros. Each checks for its specific form before attempting to cast.

- `fo_bear(spellName, forceMouseover)`
- `fo_cat(spellName, forceMouseover)`
- `fo_moonkin(helpSpell, harmSpell, forceMouseover)`
- `fo_tree(helpSpell, harmSpell, forceMouseover)`
- `fo_caster(helpSpell, harmSpell, forceMouseover)`

Examples

```lua
-- Handles every form,help and harm,also mouseover implemented with this simple macro
/script fo_bear('maul')
/script fo_cat('claw')
/script fo_tree('regrowth(rank 3)', 'faerie fire', "m")
/script fo_caster('healing touch(rank 4)', 'wrath')

```

If you can write if ~ then scripts, [Aura Checker](#-aura-checker-fo_aura), [Resource Checker](#-resource-checker-fo_rs) and much more are available!!

### Shapeshifting

Spam-safe shapeshifting. Unlike standard buttons, these will NOT cancel the form if pressed while already shifted.

- `fo_castBearForm()`
- `fo_castCatForm()`
- `fo_castAquaForm()`
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
3. **Advanced Form Protection (Form Lock)** To prevent accidental de-shifting during intense combat, you can enable Form Lock via the checkboxes. fo_cancelForm() still works.

**Note:** These features only apply to spells triggered via this addon's scripts (e.g., `/script fo_cast()`). Standard action bar buttons remain unaffected to preserve vanilla-like control when needed.



---

<BR><BR><BR>

# Full Technical Reference (Advanced)

For users who want to build complex custom macros, here is the complete list of available functions.





## 🔍 Aura Checker (`fo_aura`)

The Aura Checker ensures your macros are "aware" of active buffs and debuffs. It prevents mana waste by stopping you from clipping DoTs or overwriting active HoTs.

### Key Features

* **Smart Targeting System**: Follows STS.
* **Auto-Rank Filtering**: Automatically strips rank data (e.g., `"Regrowth(Rank 5)"` is treated as `"Regrowth"`).
* **Texture Support**: Match by name (local) or texture path (global) to avoid localization issues.

### 🛠️ API Reference

| Function | Description | Example |
| --- | --- | --- |
| **`fo_aura("name", ...)`** | Follows STS logic. "s", "m", "WoWUnitID" works. | `fo_aura("Renew")` |

> [!TIP]
> **Smart Flags:** `fo_aura` supports the same flags as `fo_cast`.
> Use `fo_aura("Moonfire", "m")` to specifically check a hostile mouseover target.

#### Arguments:

* **`spellName`**: The name of the buff/debuff or its **Texture Path**.
* **Name Match**: Use the display name (e.g., `"Moonfire"`).
* **Texture Match**: Use the internal icon name (e.g., `"Spell_Nature_Starfall"`).
* **🔍 Texture ID**: Use `/script fo_showTargetTexture()` to print active texture names to chat.

---

### 📝 Macro Examples

```lua
-- 1. Standard Smart Buffing
-- Casts only if the target is missing the buff.
/script if not fo_aura("Rejuvenation") then fo_cast("Rejuvenation") end

-- 2. Hostile Mouseover Check
-- Prevents re-casting Moonfire if the mouseover target already has the DoT.
/script if not fo_aura("Moonfire", "m") then fo_cast("Moonfire", "m") end

-- 3. Self Buff Detection
-- Ensures you don't waste mana re-buffing yourself.
/script if not fo_aura("Inner Fire", "s") then fo_cast("Inner Fire", "s") end

```

---

<BR><BR>





## <a id="resource-checker"></a>📊 Resource Scanner (`fo_RS`)

The `fo_RS` function allows you to create intelligent macros that change behavior based on Health or Power (Mana/Rage/Energy) levels. It supports both **percentage-based** checks and **absolute deficit** checks.

### 🔑 Key Syntax

`fo_RS("condition", "target_flag")`

* **Condition**: A string containing the stat, operator, and value (e.g., `"hp < 50%"`, `"pd > 1000"`).
* **Target Flag (Optional)**: Uses the Smart Target System (STS).

---

### 💡 Stat Aliases & Deficit Mode

| Alias | Description | Type |
| --- | --- | --- |
| **`l`**, **`hp`** | Current Life / Health | Current Value |
| **`p`**, **`mana`** | Current Power / Mana | Current Value |
| **`ld`**, **`hd`** | **Life Deficit** (Max - Current) | Missing Amount |
| **`pd`**, **`md`** | **Power Deficit** (Max - Current) | Missing Amount |

---

### 🚀 Usage Examples

#### 1. Preventing Overheal (Life Deficit)

Automatically choose a spell rank based on exactly how much HP the target is missing.

```lua
-- Cast Rank 4 if target is missing 1000+ HP, otherwise Rank 2
/script if fo_RS("ld > 1000") then fo_cast("Heal(Rank 4)") else fo_cast("Heal(Rank 2)") end
```

#### 2. Panic Button (Percentage)

Standard percentage check for survival skills.

```lua
-- Cast Shield if your health drops below 30%
/script if fo_RS("hp < 30%", "s") then fo_cast("Power Word: Shield", "s") end
```

---

### 🛠️ Advanced Public API

For developers who want raw numbers for their own custom logic:

* `fo_lifeDeficit("unit")`: Returns the absolute number of missing HP.
* `fo_powerDeficit("unit")`: Returns the absolute number of missing Power/Mana.








---


<BR><BR>

## <a id="cd-checker"></a>⏳ Cooldown Checker (`fo_CD`)

The `fo_CD` function returns `true` if a spell is currently on cooldown. It is designed to ignore the Global Cooldown (GCD), so it only returns `true` for actual ability cooldowns (like the 15s on _Swiftmend_).

### 🛠️ API Reference

| Function            | Description                                                | Example Usage |
| ------------------- | ---------------------------------------------------------- | ------------- |
| **`fo_CD(name)`** | Returns `true` if the spell is on cooldown (ignoring GCD). | `"Swiftmend"` |

### 📝 Macro Example

#### Fallback Logic

If _Swiftmend_ is on cooldown, cast _Regrowth_ instead. Otherwise, cast _Swiftmend_:

```lua
/script if fo_CD("Swiftmend") then fo_cast("Regrowth") else fo_cast("Swiftmend") end

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
-- Cast Ice Barrier / Frostbolt,Fireball if Fire spec. [respec without changing hotbar]
/script if fo_hasSpell("Ice Barrier") and not fo_CD('Ice Barrier') and not fo_aura('Ice Barrier') then fo_cast("Ice Barrier") elseif fo_hasSpell('Ice Barrier') then fo_cast("Frostbolt") elseif fo_hasSpell('Combustion') then fo_cast('Fireball') end

```

### ⚔️ Combat & Action State (SELF ONLY)

Useful for fine-tuning macro behavior based on your character's current activity.

| Function               | Returns `true` if...                                    |
| ---------------------- | ------------------------------------------------------- |
| **`fo_isCombat()`**    | You are currently in combat.                            |
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
