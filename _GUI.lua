-- ==========================================
-- 0. Configuration & Constants
-- ==========================================
local WINDOW_WIDTH = 650
local WINDOW_HEIGHT = 620
local MAX_ITEMS_PER_COLUMN = 10 -- Max items before starting a new column

-- ==========================================
-- 1. Initialization
-- ==========================================
if fo_Settings == nil then fo_Settings = {} end

-- ==========================================
-- 2. Minimap Button
-- ==========================================
local MyBtn = CreateFrame("Button", "MyMinimapButton", Minimap)
MyBtn:SetWidth(32); MyBtn:SetHeight(32); MyBtn:SetFrameStrata("HIGH")
MyBtn:SetPoint("CENTER", UIParent, "CENTER")

local icon = MyBtn:CreateTexture(nil, "BORDER")
icon:SetTexture("Interface\\Icons\\Spell_Holy_Purify")
icon:SetWidth(20); icon:SetHeight(20); icon:SetPoint("CENTER", MyBtn, "CENTER")

local border = MyBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(52); border:SetHeight(52); border:SetPoint("TOPLEFT", MyBtn, "TOPLEFT")

-- Function to handle minimap button orbit
local function UpdateButtonPosition(angle)
    local centerX, centerY = Minimap:GetCenter()
    local x = math.cos(angle or 135) * 80
    local y = math.sin(angle or 135) * 80
    MyBtn:ClearAllPoints()
    MyBtn:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", centerX + x, centerY + y)
    fo_Settings.angle = angle
end

-- Dragging logic for Minimap Button
MyBtn:RegisterForDrag("LeftButton")
MyBtn:SetMovable(true)
MyBtn:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
        local xpos, ypos = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local centerX, centerY = Minimap:GetCenter()
        UpdateButtonPosition(math.atan2((ypos / scale) - centerY, (xpos / scale) - centerX))
    end)
end)
MyBtn:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)

-- ==========================================
-- 3. Main Config Window
-- ==========================================
local ConfigFrame = CreateFrame("Frame", "fo_ConfigWindow", UIParent)
ConfigFrame:SetWidth(WINDOW_WIDTH)
ConfigFrame:SetHeight(WINDOW_HEIGHT)
ConfigFrame:SetPoint("CENTER", UIParent, "CENTER")
ConfigFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
ConfigFrame:SetMovable(true); ConfigFrame:EnableMouse(true)
ConfigFrame:RegisterForDrag("LeftButton")
ConfigFrame:SetScript("OnDragStart", function() this:StartMoving() end)
ConfigFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
ConfigFrame:Hide()

-- Header Title
local title = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 20, -15)
title:SetText("41's Functions Settings & Snippets")

-- Close Button
local CloseBtn = CreateFrame("Button", nil, ConfigFrame, "UIPanelCloseButton")
CloseBtn:SetPoint("TOPRIGHT", ConfigFrame, "TOPRIGHT", -5, -5)

-- Toggle Window via Minimap Button
MyBtn:SetScript("OnClick", function()
    if ConfigFrame:IsVisible() then ConfigFrame:Hide() else ConfigFrame:Show() end
    PlaySound(ConfigFrame:IsVisible() and "igMainMenuOpen" or "igMainMenuClose")
end)

-- ==========================================
-- 4. UI Component Factories & Auto-Layout
-- ==========================================
local ClassPanels = {}
local panelCounters = {}

-- Factory: Create a general description for the tab
local function AddPanelDescription(panel, text)
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -45) -- Positioned below the main title
    desc:SetWidth(WINDOW_WIDTH - 40)
    desc:SetJustifyH("LEFT")
    desc:SetText(text)
end


-- Factory: Create a guide label right above the snippets list
local function AddSnippetGuide(panel, text)
    local guide = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guide:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -180) -- Placed just above the first snippet
    guide:SetTextColor(0.6, 0.6, 0.6)                     -- Dimmed color for visual hierarchy
    guide:SetText(text)
end
-- Factory: Create an EditBox with a Label
local function AddApiToPanel(panel, xOffset, yOffset, functionText, labelText)
    if labelText then
        local st = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        st:SetPoint("TOPLEFT", panel, "TOPLEFT", xOffset, yOffset + 12)
        st:SetText(labelText)
    end
    local bg = CreateFrame("Frame", nil, panel)
    bg:SetWidth(180); bg:SetHeight(24)
    bg:SetPoint("TOPLEFT", panel, "TOPLEFT", xOffset, yOffset)
    bg:SetBackdrop({
        bgFile = "Interface\\Buttons\\White8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.5)

    local eb = CreateFrame("EditBox", nil, bg)
    eb:SetWidth(170); eb:SetHeight(20); eb:SetPoint("CENTER", bg, "CENTER", 0, 0)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetText(functionText)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEditFocusGained", function() this:HighlightText() end)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
end

-- Auto-Layout: Add EditBox to the next available position
local function AddApiAuto(panel, className, functionText, labelText)
    local count = panelCounters[className] or 0
    local col = math.floor(count / MAX_ITEMS_PER_COLUMN)
    local row = math.mod(count, MAX_ITEMS_PER_COLUMN)

    local x = 25 + (col * 210)
    -- Starting from -140 to leave space for the guide label
    local y = -210 - (row * 40)

    AddApiToPanel(panel, x, y, functionText, labelText)
    panelCounters[className] = count + 1
end

-- Factory: Create a Container Panel for each Tab
local function CreateClassPanel(className)
    local f = CreateFrame("Frame", nil, ConfigFrame)
    f:SetAllPoints(ConfigFrame)
    f:Hide()
    ClassPanels[className] = f
    panelCounters[className] = 0
    return f
end

-- Factory: Create a Custom Tab Button (Fixed Width)
local function CreateTabButton(id, text, className, xOffset)
    local btn = CreateFrame("Button", "fo_CustomTab" .. id, ConfigFrame)
    btn:SetWidth(60);  --Tab Button Width
    btn:SetHeight(22); --Tab Button Height
    btn:SetID(id)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\White8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    btn:SetBackdropColor(0, 0, 0, 0.8)
    btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fs:SetText(text)
    btn.text = fs

    btn:SetPoint("TOPLEFT", ConfigFrame, "BOTTOMLEFT", xOffset, 7) --Tab Button Offset
    btn:SetScript("OnClick", function()
        -- Reset all tabs and panels
        for name, p in pairs(ClassPanels) do p:Hide() end
        for i = 1, 5 do
            local b = _G["fo_CustomTab" .. i]
            if b then
                b:SetBackdropColor(0, 0, 0, 0.8)
                b:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                b.text:SetTextColor(1, 0.82, 0)
            end
        end
        -- Activate selected tab
        ClassPanels[className]:Show()
        this:SetBackdropColor(0.3, 0.3, 0.3, 1)
        this:SetBackdropBorderColor(1, 1, 1, 1)
        this.text:SetTextColor(1, 1, 1)
        PlaySound("igCharacterInfoTab")
    end)
    return btn
end

-- ==========================================
-- 5. Content Setup
-- ==========================================


-- ==========================================
-- Global Tab
-- ==========================================
local GlobalPanel = CreateClassPanel("GLOBAL")
CreateTabButton(1, "Global", "GLOBAL", 15)

-- Tab Description
AddPanelDescription(GlobalPanel,
    "General settings and utility snippets for all classes.\nThese settings only apply to scripts this addon provides (Taunt alerts excluded).")


-- Checkbox: Self Cast
local G_SelfCast_CB = CreateFrame("CheckButton", "fo_CB_Global_SelfCast", GlobalPanel, "UICheckButtonTemplate")
G_SelfCast_CB:SetPoint("TOPLEFT", GlobalPanel, "TOPLEFT", 20, -70)
_G[G_SelfCast_CB:GetName() .. "Text"]:SetText("Enable Self Cast")
G_SelfCast_CB:SetChecked(fo_Settings.selfCastEnabled)
G_SelfCast_CB:SetScript("OnClick", function() fo_Settings.selfCastEnabled = this:GetChecked() and true or false end)
G_SelfCast_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Scripts from this addon self-casts helpful spells if mouseover and target does not exist.")
    GameTooltip:Show()
end)
G_SelfCast_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)


-- Checkbox: Self Cast
local G_TauntResistAnnounce_CB = CreateFrame("CheckButton", "fo_CB_TauntResistAnnounce", GlobalPanel,
    "UICheckButtonTemplate")
G_TauntResistAnnounce_CB:SetPoint("TOPLEFT", GlobalPanel, "TOPLEFT", 20, -95)
_G[G_TauntResistAnnounce_CB:GetName() .. "Text"]:SetText("Announce Taunt Resists (supports all tanking classes)")
G_TauntResistAnnounce_CB:SetChecked(fo_Settings.announceTauntResist)
G_TauntResistAnnounce_CB:SetScript("OnClick",
    function() fo_Settings.announceTauntResist = this:GetChecked() and true or false end)
G_TauntResistAnnounce_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Announce if Taunt spells are resisted.")
    GameTooltip:Show()
end)
G_TauntResistAnnounce_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Automated List (Starts from Y = -110)
AddSnippetGuide(GlobalPanel, "--- Copy from here and paste into your macro (change arguments) ---")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_cast('Renew')", "Standard cast (Mouseover Priority)")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_smartCast('Rejuvenation', 'Moonfire')", "Smart cast (Helpful/Harmful)")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_smartCast('Remove Lesser Curse', 'Counterspell', 1)",
    "1 enables mouseover on enemies")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_auraSelf('Rejuvenation')", "Aura Checker (Self Only)")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_auraSmart('starfall', 1)", "Aura Checker (Smart Target)")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_aura('Faerie Fire', 'targettarget')", "Aura Checker (Manual Target)")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_showTargetTexture()", "Show all textures on current target")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_dismount()", "Dismount (***May not work***)")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_startAttack()", "Spammable auto attack")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_startShoot()", "Shoots ALL ranged weapon")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_smartBandage()", "Highest bandage on smart target")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_startStealth()", "Spammable Stealth")
AddApiAuto(GlobalPanel, "GLOBAL", "/script fo_break()", "Stpos all (BUT CHANNELING) action")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_RSSelf('p', '>', '80%')", "Resource Checker (Self) l=life, p=power")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_RSSmart('l', '<', 1000)", "Resource Checker (Smart Target)")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_RS('l', '<=', '20%', 'party1')", "Resource Checker (Manual Target)")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_isCD('Swiftmend')", "Cooldown Checker (Self Only)")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_hasShield()", "Returns true if Shield equipped")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_has2H()", "Returns true if 2H equipped")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_hasDW()", "Returns true if Dual-Wielding")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_hasSpell('swiftmend')", "True if the spell is in your spellbook")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_isStealth()", "Returns true if Stealthed(any kind)")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_isAttacking()", "Returns true if attacking")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_isShooting()", "Returns true if shooting")
AddApiAuto(GlobalPanel, "GLOBAL", "fo_isCasting()", "Returns true if Casting")


AddApiAuto(GlobalPanel, "GLOBAL", "https://github.com/41-0/41sFunctions", "GitHub URL")



-- ==========================================================
-- Druid Tab
-- ==========================================================
local DruidPanel = CreateClassPanel("DRUID")
CreateTabButton(3, "Druid", "DRUID", 75)

-- Tab Description
AddPanelDescription(DruidPanel,
    "Advanced Druid logic and macro-friendly shapeshift settings.\nThese settings only apply to scripts this addon provides (e.g., fo_cast).")


-- Checkbox: Auto Cancelform
local Dru_AutoCancelForm_CB = CreateFrame("CheckButton", "fo_CB_Druid_AutoCancelform", DruidPanel,
    "UICheckButtonTemplate")
Dru_AutoCancelForm_CB:SetPoint("TOPLEFT", DruidPanel, "TOPLEFT", 20, -70)
_G[Dru_AutoCancelForm_CB:GetName() .. "Text"]:SetText("Enable Auto Cancelform")
Dru_AutoCancelForm_CB:SetChecked(fo_Settings.autoCancelForm)
Dru_AutoCancelForm_CB:SetScript("OnClick",
    function() fo_Settings.autoCancelForm = this:GetChecked() and true or false end)
Dru_AutoCancelForm_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Automatically cancels form when casting spells restricted to other forms.")
    GameTooltip:Show()
end)
Dru_AutoCancelForm_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Checkbox: Auto Shapeshift
local Dru_AutoShapeshift_CB = CreateFrame("CheckButton", "fo_CB_Druid_AutoShapeshift", DruidPanel,
    "UICheckButtonTemplate")
Dru_AutoShapeshift_CB:SetPoint("TOPLEFT", DruidPanel, "TOPLEFT", 20, -95)
_G[Dru_AutoShapeshift_CB:GetName() .. "Text"]:SetText("Enable Auto Shapeshift")
Dru_AutoShapeshift_CB:SetChecked(fo_Settings.autoShapeshift)
Dru_AutoShapeshift_CB:SetScript("OnClick",
    function() fo_Settings.autoShapeshift = this:GetChecked() and true or false end)
Dru_AutoShapeshift_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Automatically shifts into the correct form for the spell being cast.")
    GameTooltip:Show()
end)
Dru_AutoShapeshift_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Checkbox: Prioritize Bear
local Dru_PrioritizeBear_CB = CreateFrame("CheckButton", "fo_CB_Druid_PrioritizeBear", DruidPanel,
    "UICheckButtonTemplate")
Dru_PrioritizeBear_CB:SetPoint("TOPLEFT", DruidPanel, "TOPLEFT", 45, -115)
_G[Dru_PrioritizeBear_CB:GetName() .. "Text"]:SetText("Prioritize Bear")
Dru_PrioritizeBear_CB:SetChecked(fo_Settings.prioritizeBear)
Dru_PrioritizeBear_CB:SetScript("OnClick",
    function() fo_Settings.prioritizeBear = this:GetChecked() and true or false end)
Dru_PrioritizeBear_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Prefer Bear Form for spells shared with Cat Form.")
    GameTooltip:Show()
end)
Dru_PrioritizeBear_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Checkbox: Save Rage during Frenzied Regeneration
local Dru_SaveRageWhenFR_CB = CreateFrame("CheckButton", "fo_CB_Druid_SaveRageWhenFR", DruidPanel,
    "UICheckButtonTemplate")
Dru_SaveRageWhenFR_CB:SetPoint("TOPLEFT", DruidPanel, "TOPLEFT", 20, -145)
_G[Dru_SaveRageWhenFR_CB:GetName() .. "Text"]:SetText("Save rage while FrenziedRegen")
Dru_SaveRageWhenFR_CB:SetChecked(fo_Settings.preventRageWasteDuringFR)
Dru_SaveRageWhenFR_CB:SetScript("OnClick",
    function() fo_Settings.preventRageWasteDuringFR = this:GetChecked() and true or false end)
Dru_SaveRageWhenFR_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Prevent using Maul and Swipe during Frenzied Regeneration.")
    GameTooltip:Show()
end)
Dru_SaveRageWhenFR_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Checkbox: Bear Lock
local Dru_BearLock_CB = CreateFrame("CheckButton", "fo_CB_Druid_BearLock", DruidPanel, "UICheckButtonTemplate")
Dru_BearLock_CB:SetPoint("TOPLEFT", DruidPanel, "TOPLEFT", 220, -70)
_G[Dru_BearLock_CB:GetName() .. "Text"]:SetText("Lock Bear Form")
Dru_BearLock_CB:SetChecked(fo_Settings.lockBearForm)
Dru_BearLock_CB:SetScript("OnClick", function() fo_Settings.lockBearForm = this:GetChecked() and true or false end)
Dru_BearLock_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Prevent leaving Bear Form when using other spells, ignoring Auto-Cancel settings.")
    GameTooltip:Show()
end)
Dru_BearLock_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)


-- Checkbox: Cat Lock
local Dru_CatLock_CB = CreateFrame("CheckButton", "fo_CB_Druid_CatLock", DruidPanel, "UICheckButtonTemplate")
Dru_CatLock_CB:SetPoint("TOPLEFT", DruidPanel, "TOPLEFT", 220, -95)
_G[Dru_CatLock_CB:GetName() .. "Text"]:SetText("Lock Cat Form")
Dru_CatLock_CB:SetChecked(fo_Settings.lockCatForm)
Dru_CatLock_CB:SetScript("OnClick", function() fo_Settings.lockCatForm = this:GetChecked() and true or false end)
Dru_CatLock_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Prevent leaving Cat Form when using other spells, ignoring Auto-Cancel settings.")
    GameTooltip:Show()
end)
Dru_CatLock_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Checkbox: Moonkin Lock
local Dru_MoonkinLock_CB = CreateFrame("CheckButton", "fo_CB_Druid_MoonkinLock", DruidPanel, "UICheckButtonTemplate")
Dru_MoonkinLock_CB:SetPoint("TOPLEFT", DruidPanel, "TOPLEFT", 220, -120)
_G[Dru_MoonkinLock_CB:GetName() .. "Text"]:SetText("Lock Moonkin Form")
Dru_MoonkinLock_CB:SetChecked(fo_Settings.lockMoonkinForm)
Dru_MoonkinLock_CB:SetScript("OnClick", function() fo_Settings.lockMoonkinForm = this:GetChecked() and true or false end)
Dru_MoonkinLock_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Prevent leaving Moonkin Form when using other spells, ignoring Auto-Cancel settings.")
    GameTooltip:Show()
end)
Dru_MoonkinLock_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Checkbox: Tree Lock
local Dru_TreeLock_CB = CreateFrame("CheckButton", "fo_CB_Druid_TreeLock", DruidPanel, "UICheckButtonTemplate")
Dru_TreeLock_CB:SetPoint("TOPLEFT", DruidPanel, "TOPLEFT", 220, -145)
_G[Dru_TreeLock_CB:GetName() .. "Text"]:SetText("Lock Tree Form")
Dru_TreeLock_CB:SetChecked(fo_Settings.lockTreeForm)
Dru_TreeLock_CB:SetScript("OnClick", function() fo_Settings.lockTreeForm = this:GetChecked() and true or false end)
Dru_TreeLock_CB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Prevent leaving Tree Form when using other spells, ignoring Auto-Cancel settings.")
    GameTooltip:Show()
end)
Dru_TreeLock_CB:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Automated List
AddSnippetGuide(DruidPanel, "--- Easily create a smart macro by pasting one line per form ---")
AddApiAuto(DruidPanel, "DRUID", "/script fo_bear('maul')", "Cast spell if Bear form")
AddApiAuto(DruidPanel, "DRUID", "/script fo_cat('claw')", "Cast spell if Cat form")
AddApiAuto(DruidPanel, "DRUID", "/script fo_moonkin('thorns', 'Wrath')", "Cast spell if Moonkin form")
AddApiAuto(DruidPanel, "DRUID", "/script fo_tree('rejuvenation', 'hibernate', 1)", "Cast spell if Tree form")
AddApiAuto(DruidPanel, "DRUID", "/script fo_caster('healing touch', 'starfire')", "Cast spell if Caster form (no form)")
AddApiAuto(DruidPanel, "DRUID", "/script fo_castBearForm()", "Spammable Bear Form")
AddApiAuto(DruidPanel, "DRUID", "/script fo_castCatForm()", "Spammable Cat Form")
AddApiAuto(DruidPanel, "DRUID", "/script fo_castAquaForm()", "Spammable Aquatic Form")
AddApiAuto(DruidPanel, "DRUID", "/script fo_castTravelForm()", "Spammable Travel Form")
AddApiAuto(DruidPanel, "DRUID", "/script fo_castMoonkinForm()", "Spammable Moonkin Form")
AddApiAuto(DruidPanel, "DRUID", "/script fo_castTreeForm()", "Spammable Tree Form")
AddApiAuto(DruidPanel, "DRUID",
    "fo_isBear() fo_isCat() fo_isTravel() fo_isAqua() fo_isMoonkin() fo_isTree() fo_isCaster()",
    "Returns true if in respective form")
AddApiAuto(DruidPanel, "DRUID", "fo_isFrenziedRegen()", "True during Frenzied Regeneration")



-- ==========================================
-- 6. Events & Launch
-- ==========================================
-- Initial Tab Setup
local firstTab = _G["fo_CustomTab1"]
if firstTab then
    local oldThis = this
    this = firstTab
    firstTab:GetScript("OnClick")()
    this = oldThis
end



-- Sync data and UI after login
-- Sync function to be called anytime
function fo_SyncUI()
    if fo_CB_Global_SelfCast then fo_CB_Global_SelfCast:SetChecked(fo_Settings.selfCastEnabled) end
    if G_TauntResistAnnounce_CB then G_TauntResistAnnounce_CB:SetChecked(fo_Settings.announceTauntResist) end
    if Dru_AutoCancelForm_CB then Dru_AutoCancelForm_CB:SetChecked(fo_Settings.autoCancelForm) end
    if Dru_AutoShapeshift_CB then Dru_AutoShapeshift_CB:SetChecked(fo_Settings.autoShapeshift) end
    if Dru_PrioritizeBear_CB then Dru_PrioritizeBear_CB:SetChecked(fo_Settings.prioritizeBear) end
    if Dru_SaveRageWhenFR_CB then Dru_SaveRageWhenFR_CB:SetChecked(fo_Settings.preventRageWasteDuringFR) end
    if Dru_BearLock_CB then Dru_BearLock_CB:SetChecked(fo_Settings.lockBearForm) end
    if Dru_CatLock_CB then Dru_CatLock_CB:SetChecked(fo_Settings.lockCatForm) end
    if Dru_MoonkinLock_CB then Dru_MoonkinLock_CB:SetChecked(fo_Settings.lockMoonkinForm) end
    if Dru_TreeLock_CB then Dru_TreeLock_CB:SetChecked(fo_Settings.lockTreeForm) end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
    -- Sync UI state as a safety measure on login
    fo_SyncUI()

    -- Update Minimap button after Minimap is ready
    loader:SetScript("OnUpdate", function()
        if Minimap:GetCenter() and Minimap:GetCenter() ~= 0 then
            UpdateButtonPosition(fo_Settings.angle)
            MyBtn:Show()
            this:SetScript("OnUpdate", nil) -- Unregister OnUpdate to prevent redundant calls
        end
    end)
end)
