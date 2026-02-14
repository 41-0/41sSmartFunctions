# 41's Functions

**The Essential Utility Library for TWoW**

**Note: This AddOn is compatible with the English Client ONLY. Spell names and aura checks are hardcoded in English.**

<BR>

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

## Feature: Auto Cancelform/Shapeshift and Form Protection

This addon provides a seamless shapeshifting experience by managing form states automatically. 
All core features can be toggled via the In-game Configuration Panel.

1. Smart Auto-Shapeshift 

When you cast a feral ability (e.g., Maul or Shred), the addon checks your current form. If you are in Humanoid or an incorrect form, it automatically shifts you into the appropriate form.

2. Intelligent Auto-Cancelform 

Eliminates "Can't use that in this form" errors. When casting non-feral spells (e.g., Healing Touch or Rejuvenation), the addon utilizes a hidden Aura Scanner to instantly cancel your current form.

3. Advanced Form Protection (Form Lock)

To prevent accidental de-shifting during intense combat, you can enable Form Lock via the checkboxes.

```Note: These features only apply to spells triggered via this addon's scripts (e.g., /script fo_cast()). Standard action bar buttons remain unaffected to preserve vanilla-like control when needed.```





---
<BR><BR><BR>

# Full Technical Reference (Advanced)
For users who want to build complex custom macros, here is the complete list of available functions in 41's Druid Functions.


## 🔍 Aura Checker (`fo_aura`)

The Aura Checker system allows your macros to detect existing buffs or debuffs on a unit. This is essential for preventing mana waste from clipping DoTs or overwriting active buffs.

### Key Features

* **Automatic Rank Filtering**: The system automatically strips rank information (e.g., it turns `"Regrowth(Rank 5)"` into `"Regrowth"`) to ensure it correctly matches the aura name on the target.
* **Smart Detection**: Uses the same logic as the casting system to prioritize mouseover targets.
* **Redundancy Prevention**: Easily build macros that only cast a spell if the target doesn't already have it.

---

### 🛠️ API Reference

| Function | Description | Example Usage |
| --- | --- | --- |
| **`fo_aura(spell, unit)`** | Checks if the specific unit has the aura. | `"Renew", "party1"` |
| **`fo_auraSelf(spell)`** | Checks for an aura on the **Player**. | `"Inner Fire"` |
| **`fo_auraSmart(spell, f)`** | Checks the **Smart Target** (Mouseover/Target). | `"Rejuvenation"` |


#### Arguments:

* **`spellName`**: The name of the buff/debuff or its **Texture Path**.
* **Name Match**: Use the standard display name (e.g., `"Moonfire"`, `"Mark of the Wild"`). **Note: This is case-sensitive.**
* **Texture Match**: You can also use the internal texture name or path (e.g., `"Spell_Nature_Rejuvenation"`). This is useful for identifying specific effects that share names or for advanced localization support.
* **🔍 How to find textures**: Use the command `/script fo_showTargetTexture()` while targeting a unit to print the names of all active textures on that target to your chat frame.


* **`unit`**: A valid WoW unit ID (default is `"target"`).
* **`forceMouseover`**: If set to `1`, forces the check on the mouseover target.

---

### 📝 Macro Examples

#### 1. Smart HoT Management (Buff)

Cast *Rejuvenation* only if the target (or mouseover) does not already have the buff active:

```lua
/script if not fo_auraSmart("Rejuvenation") then fo_cast("Rejuvenation") end

```

#### 2. Efficient DoT Tracking (Debuff)

Cast *Moonfire* only if the enemy is not currently affected by your *Moonfire* debuff:

```lua
/script if not fo_auraSmart("Moonfire") then fo_cast("Moonfire") end

```

#### 3. Self-Buff Maintenance

Check if you have *Thorns* active on yourself; if not, cast it:

```lua
/script if not fo_auraSelf("Thorns") then fo_cast("Thorns") end

```

If you prefer using textures to avoid case-sensitivity or localization issues:

```lua
-- Using the texture name for Rejuvenation
/script if not fo_auraSmart("Spell_Nature_Rejuvenation") then fo_cast("Rejuvenation") end

```

---

### 💡 Pro-Tips for Macro Optimization

* **Logical Negation**: Use the `not` keyword in your Lua script to trigger the cast only when the aura is **missing**.
* **Combined Conditions**: You can combine Aura checks with Resource checks for ultimate control:
> *Example: "Cast Regrowth only if the target is missing the buff AND their health is below 80%"*


```lua
/script if not fo_auraSmart("Regrowth") and fo_RSSmart("l", "<", "80%") then fo_cast("Regrowth") end

```


---
<BR><BR>
## 📊 Resource Checker (`fo_RS`)

The `fo_RS` system is a powerful conditional engine designed to overcome the 255-character macro limit in Vanilla WoW. It allows for complex health and resource checks using ultra-short syntax.

### Key Features

* **Shorthand Support**: Use `l` for Life (Health) and `p` for Power (Mana/Rage/Energy) to save critical macro space.
* **Dynamic Thresholds**: Supports both absolute values (e.g., `500`) and percentage strings (e.g., `"30%"`).
* **Smart Targeting**: Seamlessly integrates with the addon's mouseover priority logic.

---

### 🛠️ API Reference

| Function | Description | Example Usage |
| --- | --- | --- |
| **`fo_RS(stat, op, val, unit)`** | Checks status of a specific unit. | `"l", ">", "50%", "pet"` |
| **`fo_RSSelf(stat, op, val)`** | Shorthand for checking the **Player**. | `"p", "<", 100` |
| **`fo_RSSmart(stat, op, val, f)`** | Checks the **Smart Target** (Mouseover/Target). | `"l", "<", "20%"` |

#### Arguments:

* **`stat`**: Type of stat to check.
* `l`, `hp`, `health` → **Health**
* `p`, `mana`, `rage`, `energy` → **Power**


* **`op`**: Logical operators: `>`, `<`, `>=`, `<=`, `==`.
* **`val`**: The threshold. Can be a number (`500`) or a percentage string (`"50%"`).
* **`unit`**: Any valid WoW unit ID (default is `"target"`).

---

### 📝 Macro Examples

Cast *Swiftmend* only if the Smart Target's (Mouseover or Target) health is below 30%:

```lua
/script if fo_RSSmart("l", "<", "30%") then fo_cast("Swiftmend") end

```

Cast *Barkskin* only if your own mana is above 10% but your health is below 1000:

```lua
/script if fo_RSSelf("p", ">", "10%") and fo_RSSelf("l", "<", 1000) then fo_cast("Barkskin") end

```

Cast a *Rejuvenation rank 1* only when the smart target's health is above 95%:

```lua
/script if fo_RSSmart("l", ">", "95%") then fo_cast("Rejuvenation(Rank 1)") end

```

---

### 💡 Pro-Tips for Macro Optimization

* **Save Space**: Use `l` instead of `health` and `p` instead of `mana`. Every character counts when building complex "if-then" macros.
* **Quotes Matter**: Remember to wrap percentages in quotes (e.g., `"50%"`) so the system recognizes it as a percentage rather than a raw number.
* **Smart Integration**: `fo_RSSmart` is the most powerful version, as it automatically checks your mouseover target before your current target, matching the behavior of your spells.

---


<BR><BR>

# Installation

1. Download this repository.
2. Move the `41sDruidFunctions` folder into your `Interface/AddOns/` directory.
3. Restart World of Warcraft.
