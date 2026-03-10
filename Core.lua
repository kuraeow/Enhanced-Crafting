local AddonName, ns = ...
ns = ns or {}

local APP_NAME = "EnhancedCrafting"
local ORDERS_ICON_PATH = "Interface\\AddOns\\" .. tostring(AddonName or "Enhanced Crafting") .. "\\Media\\ecraftIcon.tga"
local format = string.format
local min = math.min
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local REMINDER_ANCHORS = {
  CENTER = true,
  TOPLEFT = true,
  TOP = true,
  TOPRIGHT = true,
  LEFT = true,
  RIGHT = true,
  BOTTOMLEFT = true,
  BOTTOM = true,
  BOTTOMRIGHT = true
}

local addon = LibStub("AceAddon-3.0"):NewAddon(APP_NAME, "AceHook-3.0", "AceEvent-3.0", "AceConsole-3.0")
ns.Addon = addon
_G.ECUI = addon

local defaults = {
  global = {
    lastTraceDump = "",
    lastTraceAt = 0,
  },
  profile = {
    enabled = true,
    trace = false,
    reminderEnabled = true,
    reminderDuration = 6,
    reminderText = L["REMINDER_TEXT_DEFAULT"],
    reminderSound = "SOUNDKIT:ALARM_CLOCK_WARNING_3",
    reminderSoundChannel = "SFX",
    reminderSystemPattern = L["REMINDER_PATTERN_DEFAULT"],
    reminderAnchor = "CENTER",
    reminderX = -434,
    reminderY = -321,
    reminderWidth = 380,
    reminderHeight = 60,
    reminderFontSize = 18,
    debug = false
  }
}

local function getAddonVersion()
  local version
  if AddonName and C_AddOns and C_AddOns.GetAddOnMetadata then
    version = C_AddOns.GetAddOnMetadata(AddonName, "Version")
  elseif AddonName and GetAddOnMetadata then
    version = GetAddOnMetadata(AddonName, "Version")
  end
  if not version or version == "" then
    version = "unknown"
  end
  return tostring(version)
end

local function safeLoadAddOn(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) then
    return true
  end
  if C_AddOns and C_AddOns.LoadAddOn then
    local ok = C_AddOns.LoadAddOn(name)
    return ok and true or false
  end
  if LoadAddOn then
    local ok = LoadAddOn(name)
    return ok and true or false
  end
  return false
end

local function tContainsText(haystack, needle)
  if type(haystack) ~= "string" or type(needle) ~= "string" or needle == "" then
    return false
  end
  local ok, found = pcall(string.find, haystack, needle, 1, true)
  if not ok then
    return false
  end
  return found ~= nil
end

function addon:Trace(...)
  if not (self.db and self.db.profile and self.db.profile.trace) then
    return
  end
  self.traceBuffer = self.traceBuffer or {}
  local t = GetTime and GetTime() or 0
  local msg = string.join(" ", tostringall(...))
  self.traceBuffer[#self.traceBuffer + 1] = ("[%.3f] %s"):format(t, msg)
  if #self.traceBuffer > 200 then
    table.remove(self.traceBuffer, 1)
  end
end

function addon:CaptureUIState(tag)
  local pf = ProfessionsFrame
  local cof = ProfessionsCustomerOrdersFrame
  local selectedTab = "n/a"
  if pf and pf.GetTab then
    local ok, tab = pcall(pf.GetTab, pf)
    if ok then
      selectedTab = tostring(tab)
    end
  elseif pf and PanelTemplates_GetSelectedTab then
    selectedTab = tostring(PanelTemplates_GetSelectedTab(pf))
  end
  local craftingVisible = pf and pf.CraftingPage and pf.CraftingPage:IsVisible() or false
  local ordersVisible = pf and pf.OrdersPage and pf.OrdersPage:IsVisible() or false
  local tab1Visible, tab2Visible, tab3Visible = false, false, false
  if pf and pf.GetTabButton then
    local t1 = pf:GetTabButton(1)
    local t2 = pf:GetTabButton(2)
    local t3 = pf:GetTabButton(3)
    tab1Visible = t1 and t1:IsShown() or false
    tab2Visible = t2 and t2:IsShown() or false
    tab3Visible = t3 and t3:IsShown() or false
  else
    tab1Visible = _G.ProfessionsFrameTab1 and _G.ProfessionsFrameTab1:IsShown() or false
    tab2Visible = _G.ProfessionsFrameTab2 and _G.ProfessionsFrameTab2:IsShown() or false
    tab3Visible = _G.ProfessionsFrameTab3 and _G.ProfessionsFrameTab3:IsShown() or false
  end
  local interactionType = "n/a"
  if C_PlayerInteractionManager and C_PlayerInteractionManager.GetCurrentInteractionType then
    local ok, value = pcall(C_PlayerInteractionManager.GetCurrentInteractionType)
    if ok then
      interactionType = tostring(value)
    end
  end
  self:Trace(
    tag,
    "pf:", pf and tostring(pf:IsShown()) or "nil",
    "cof:", cof and tostring(cof:IsShown()) or "nil",
    "tab:", tostring(selectedTab),
    "tabs:", tostring(tab1Visible), tostring(tab2Visible), tostring(tab3Visible),
    "craft:", tostring(craftingVisible),
    "orders:", tostring(ordersVisible),
    "interaction:", interactionType
  )
end

function addon:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(_, interactionType)
  self:CaptureUIState("EVENT:PLAYER_INTERACTION_MANAGER_FRAME_SHOW:" .. tostring(interactionType))
end

function addon:PLAYER_INTERACTION_MANAGER_FRAME_HIDE(_, interactionType)
  self:CaptureUIState("EVENT:PLAYER_INTERACTION_MANAGER_FRAME_HIDE:" .. tostring(interactionType))
end

function addon:TRADE_SKILL_SHOW()
  self:CaptureUIState("EVENT:TRADE_SKILL_SHOW")
end

function addon:TRADE_SKILL_CLOSE()
  self:CaptureUIState("EVENT:TRADE_SKILL_CLOSE")
end

function addon:DumpTrace()
  if not self.traceBuffer or #self.traceBuffer == 0 then
    self:Print(L["TRACE_EMPTY"])
    return
  end
  local dumpText = table.concat(self.traceBuffer, "\n")
  if self.db and self.db.global then
    self.db.global.lastTraceDump = dumpText
    self.db.global.lastTraceAt = time and time() or 0
  end
  self:Print(L["TRACE_DUMP_BEGIN"])
  for _, line in ipairs(self.traceBuffer) do
    self:Print(line)
  end
  self:Print(L["TRACE_DUMP_END"])
  self:Print(L["TRACE_SAVED_TO_SV"])
end

function addon:ProbeProfessionsFrame()
  local pf = ProfessionsFrame
  if not pf then
    self:Print(L["PROBE_PF_NIL"])
    return
  end

  local keys = {}
  for k, v in pairs(pf) do
    if type(v) == "function" and (
      tostring(k):find("Tab") or tostring(k):find("Page") or tostring(k):find("Show") or tostring(k):find("Hide") or tostring(k):find("Open")
    ) then
      keys[#keys + 1] = tostring(k)
    end
  end
  table.sort(keys)

  self:Print(L["PROBE_BEGIN"])
  self:Print(L["PROBE_SHOWN"], tostring(pf:IsShown()), L["PROBE_NAME"], tostring(pf:GetName()))
  self:Print(L["PROBE_CRAFTING_PAGE"], tostring(pf.CraftingPage ~= nil), L["PROBE_ORDERS_PAGE"], tostring(pf.OrdersPage ~= nil))
  self:Print(L["PROBE_KNOWN_TAB_GLOBALS"],
    tostring(_G.ProfessionsFrameTab1 ~= nil),
    tostring(_G.ProfessionsFrameTab2 ~= nil),
    tostring(_G.ProfessionsFrameTab3 ~= nil))
  self:Print(L["PROBE_METHODS"])
  for _, k in ipairs(keys) do
    self:Print(" -", k)
  end
  self:Print(L["PROBE_END"])
end

function addon:DebugPrint(...)
  if self.db and self.db.profile and self.db.profile.debug then
    self:Print(...)
  end
end

function addon:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("EnhancedCraftingDB", defaults, true)
  self:SetupOptions()
  self:RegisterChatCommand("ecraft", "HandleSlash")
  self:RegisterEvent("CHAT_MSG_SYSTEM")
  self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
  self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
  self:RegisterEvent("TRADE_SKILL_SHOW")
  self:RegisterEvent("TRADE_SKILL_CLOSE")
end

function addon:OnEnable()
  if not self.db.profile.enabled then
    return
  end

  safeLoadAddOn("Blizzard_ProfessionsCustomerOrders")
  safeLoadAddOn("Blizzard_Professions")
  safeLoadAddOn("Blizzard_AuctionHouseUI")

  self.form = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
  if not self.form then
    self:Print(L["PROF_UI_UNAVAILABLE"])
    return
  end
  if not self.form.OrderRecipientTarget or not self.form.ReagentContainer or not self.form.ReagentContainer.Reagents then
    self:Print(L["PROF_UI_LAYOUT_UNEXPECTED"])
    return
  end

  if ProfessionsCustomerOrdersFrame then
    self:PrepareOrdersFrame(ProfessionsCustomerOrdersFrame)
  end

  if not self.hooksInitialized then
    self.hooksInitialized = true

    self:SecureHookScript(self.form, "OnShow")
    self:SecureHookScript(self.form, "OnHide")
    if ProfessionsCustomerOrdersFrame then
      self:SecureHookScript(ProfessionsCustomerOrdersFrame, "OnHide", "OnCustomerOrdersFrameHide")
    end
    self:SecureHookScript(self.form.ReagentContainer.Reagents, "OnShow", "AddCheckBox")
    self:SecureHookScript(self.form.ReagentContainer.Reagents, "OnHide", "AddCheckBox")

    if ProfessionsFrame then
      self:SecureHookScript(ProfessionsFrame, "OnShow", "OpenOrdersButton")
      if ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm then
        self:SecureHookScript(ProfessionsFrame.CraftingPage.SchematicForm.Reagents, "OnShow", "AddCheckBox")
        self:SecureHookScript(ProfessionsFrame.CraftingPage.SchematicForm.Reagents, "OnHide", "AddCheckBox")
        local craftingQM = ProfessionsFrame.CraftingPage.SchematicForm.Details and ProfessionsFrame.CraftingPage.SchematicForm.Details.QualityMeter
        if craftingQM then
          self:SecureHookScript(craftingQM, "OnShow", "UpdateSkillLine")
          self:SecureHookScript(craftingQM, "OnHide", "UpdateSkillLine")
          self:SecureHookScript(craftingQM, "OnUpdate", "UpdateSkillLine")
        end
      end
      if ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView and ProfessionsFrame.OrdersPage.OrderView.OrderDetails then
        local details = ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm
        if details then
          self:SecureHookScript(details.Reagents, "OnShow", "AddCheckBox")
          self:SecureHookScript(details.Reagents, "OnHide", "AddCheckBox")
          local orderQM = details.Details and details.Details.QualityMeter
          if orderQM then
            self:SecureHookScript(orderQM, "OnShow", "UpdateSkillLine")
            self:SecureHookScript(orderQM, "OnHide", "UpdateSkillLine")
            self:SecureHookScript(orderQM, "OnUpdate", "UpdateSkillLine")
          end
        end
      end
    end

    if AuctionHouseFrame and AuctionHouseFrame.TitleContainer then
      self:SecureHookScript(AuctionHouseFrame.TitleContainer, "OnShow", "OpenOrdersButton")
    end
  end

  self:CaptureUIState("OnEnable")
  self:Print(L["ADDON_LOADED"])
  self:Print("Версия: " .. getAddonVersion())
end

function addon:OnDisable()
  if self.allockCheck then
    self.allockCheck:Cancel()
    self.allockCheck = nil
  end
  if ItemUtil and self:IsHooked(ItemUtil, "GetCraftingReagentCount") then
    self:Unhook(ItemUtil, "GetCraftingReagentCount")
  end
  if self.reminderFrame then
    self.reminderFrame:Hide()
  end
end

function addon:OnShow()
  if not self.form or not self.form.ReagentContainer then
    return
  end
  self.allocationCache = nil
  self.allockCheck = nil

  self:AddCheckBox(self.form.ReagentContainer)
  self:CaptureUIState("CustomerOrdersForm:OnShow")
end

function addon:OnHide()
  self:CaptureUIState("CustomerOrdersForm:OnHide")
end

local function clickProfessionsTab(index)
  local tab
  if ProfessionsFrame and ProfessionsFrame.GetTabButton then
    tab = ProfessionsFrame:GetTabButton(index)
  end
  if not tab then
    tab = _G["ProfessionsFrameTab" .. tostring(index)]
  end
  if tab and tab:IsShown() and tab.Click then
    tab:Click()
    return true
  end
  return false
end

function addon:RestoreProfessionsTab()
  if not self.needsProfTabRestore then
    return
  end
  local pf = ProfessionsFrame
  if not pf or not pf:IsShown() then
    return
  end

  local targetTab = tonumber(self.restoreProfTabIndex) or 1
  if ProfessionsFrame and type(ProfessionsFrame.SetTab) == "function" then
    local ok = pcall(ProfessionsFrame.SetTab, ProfessionsFrame, targetTab)
    if ok then
      if ProfessionsFrame.UpdateTabs then
        pcall(ProfessionsFrame.UpdateTabs, ProfessionsFrame)
      end
      self.needsProfTabRestore = false
      self.restoreProfTabIndex = nil
      self.restoreRetryCount = nil
      self:Trace("RestoreProfessionsTab:SetTab success", targetTab)
      return
    end
  end
  if clickProfessionsTab(targetTab) then
    self.needsProfTabRestore = false
    self.restoreProfTabIndex = nil
    self.restoreRetryCount = nil
    return
  end

  -- Tabs can be temporarily unavailable on the first frame after panel show.
  self.restoreRetryCount = (self.restoreRetryCount or 0) + 1
  if self.restoreRetryCount <= 80 then
    if (self.restoreRetryCount % 10) == 0 then
      self:Trace("RestoreProfessionsTab:retry", self.restoreRetryCount, "targetTab", targetTab)
      self:CaptureUIState("RestoreRetry")
    end
    C_Timer.After(0.05, function()
      addon:RestoreProfessionsTab()
    end)
  else
    self:Trace("RestoreProfessionsTab:giveup targetTab", targetTab)
    self.needsProfTabRestore = false
    self.restoreProfTabIndex = nil
    self.restoreRetryCount = nil
  end
end

function addon:EnsureProfessionsPageVisible(originTag)
  local pf = ProfessionsFrame
  if not pf or not pf:IsShown() then
    return false
  end

  local craftingVisible = pf.CraftingPage and pf.CraftingPage:IsVisible() or false
  local ordersVisible = pf.OrdersPage and pf.OrdersPage:IsVisible() or false
  if craftingVisible or ordersVisible then
    return false
  end

  self:Trace("EnsureProfessionsPageVisible:repair", originTag or "unknown")

  -- Prefer Crafting page as safe default when frame is in blank state.
  if pf.CraftingPage then
    pcall(function() pf.CraftingPage:Show() end)
    pcall(function() if pf.CraftingPage.OnShow then pf.CraftingPage:OnShow() end end)
  end
  if pf.OrdersPage then
    pcall(function() pf.OrdersPage:Hide() end)
  end
  if pf.SetTab then
    pcall(pf.SetTab, pf, 1)
  end
  if pf.UpdateTabs then
    pcall(pf.UpdateTabs, pf)
  end

  self:CaptureUIState("AfterEnsureProfessionsPageVisible")
  return true
end

function addon:OnCustomerOrdersFrameHide()
  self:CaptureUIState("CustomerOrdersFrame:OnHide")
  C_Timer.After(0, function()
    addon:RestoreProfessionsTab()
    addon:EnsureProfessionsPageVisible("CustomerOrdersHide+0")
    addon:CaptureUIState("AfterRestoreFromCustomerOrdersHide")
  end)
end

function addon:OnProfessionsFrameShow()
  self:CaptureUIState("ProfessionsFrame:OnShow")
  C_Timer.After(0, function()
    addon:RestoreProfessionsTab()
    addon:EnsureProfessionsPageVisible("ProfessionsShow+0")
    addon:CaptureUIState("AfterRestoreFromProfessionsShow")
  end)
  C_Timer.After(0.15, function()
    addon:EnsureProfessionsPageVisible("ProfessionsShow+0.15")
  end)
end

function addon:ApplyOrdersButtonStyle(btn)
  if not btn then
    return
  end

  btn:SetSize(100, 22)
  btn:SetNormalFontObject(GameFontHighlightSmall)
  btn:SetHighlightFontObject(GameFontHighlightSmall)
  btn:SetPushedTextOffset(1, -1)
  local fs = btn:GetFontString()
  if fs then
    fs:SetTextColor(1.0, 0.82, 0.25)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
  end

  btn:SetText(L["BTN_PLACE_ORDER"])
end

function addon:RepositionOrdersButton(target, btn)
  if not target or not btn then
    return
  end

  btn:SetFrameStrata("HIGH")
  btn:SetFrameLevel((target:GetFrameLevel() or 1) + 20)
  btn:ClearAllPoints()
  if AuctionHouseFrame and target == AuctionHouseFrame.TitleContainer then
    btn:SetPoint("TOPRIGHT", target, "TOPRIGHT", -13, 0)
  else
    btn:SetPoint("TOPRIGHT", target, "TOPRIGHT", -49, 0)
  end
end

function addon:OpenOrdersButton(target)
  if not target then
    return
  end

  if target == ProfessionsFrame then
    self:OnProfessionsFrameShow()
  end

  local targetName = target:GetName() or (target.GetParent and target:GetParent() and target:GetParent():GetName()) or "Default"
  local name = "ECUIOrders" .. targetName
  local btn = _G[name] or CreateFrame("Button", name, target, "UIPanelButtonTemplate")
  btn:SetFrameLevel(600)
  self:ApplyOrdersButtonStyle(btn)
  self:RepositionOrdersButton(target, btn)
  C_Timer.After(0, function()
    addon:RepositionOrdersButton(target, btn)
  end)
  C_Timer.After(0.12, function()
    addon:RepositionOrdersButton(target, btn)
  end)

  btn:SetScript("OnClick", function(b)
    addon:CaptureUIState("O:BeforeClick")
    local frame = ProfessionsCustomerOrdersFrame
    if not frame then
      return
    end

    addon:PrepareOrdersFrame(frame)

    if target == ProfessionsFrame and ProfessionsFrame and ProfessionsFrame:IsShown() then
      local currentTab = 1
      if ProfessionsFrame.GetTab then
        local ok, value = pcall(ProfessionsFrame.GetTab, ProfessionsFrame)
        if ok and tonumber(value) then
          currentTab = tonumber(value)
        end
      elseif PanelTemplates_GetSelectedTab then
        currentTab = PanelTemplates_GetSelectedTab(ProfessionsFrame) or 1
      end
      self.restoreProfTabIndex = currentTab
      self.needsProfTabRestore = true
      self.restoreRetryCount = 0
    end

    if frame:IsShown() then
      frame:Hide()
    else
      frame.ecuiUseAddonPortrait = true
      frame:Show()
    end
    addon:CaptureUIState("O:AfterClick")
  end)

  if not target.ecuiOrdersLayoutHooked then
    target.ecuiOrdersLayoutHooked = true
    self:SecureHookScript(target, "OnShow", function()
      addon:RepositionOrdersButton(target, btn)
      C_Timer.After(0.08, function()
        addon:RepositionOrdersButton(target, btn)
      end)
    end)
  end
end

function addon:PrepareOrdersFrame(frame)
  if not frame or frame.ecuiPrepared then
    return
  end

  frame.ecuiPrepared = true
  frame.ignoreFramePositionManager = true
  pcall(frame.SetMovable, frame, true)
  pcall(frame.SetClampedToScreen, frame, true)
  self:SecureHookScript(frame, "OnShow", function()
    if frame.ecuiUseAddonPortrait then
      frame.ecuiUseAddonPortrait = nil
      addon:ApplyOrdersPortrait(frame)
    end
  end)
end

function addon:ApplyOrdersPortrait(frame)
  if not frame then
    return
  end

  local function trySetTexture(texture)
    if texture and texture.SetTexture then
      texture:SetTexture(ORDERS_ICON_PATH)
      if texture.SetTexCoord then
        texture:SetTexCoord(0, 1, 0, 1)
      end
      return true
    end
    return false
  end

  local applied = false
  if frame.PortraitContainer then
    applied = trySetTexture(frame.PortraitContainer.portrait)
      or trySetTexture(frame.PortraitContainer.Portrait)
      or trySetTexture(frame.PortraitContainer.Icon)
  end
  if not applied then
    applied = trySetTexture(frame.portrait)
  end
  if not applied and frame.GetName then
    applied = trySetTexture(_G[tostring(frame:GetName()) .. "Portrait"])
  end
  if not applied then
    self:Trace("ApplyOrdersPortrait:portrait texture not found")
  end
end

function addon:CreateCheckBox(target)
  if not target then
    return nil
  end

  local arb = CreateFrame("CheckButton", nil, target, "UICheckButtonTemplate")
  target.UnlockAllReagents = arb
  arb:SetSize(20, 20)
  arb.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(L["LABEL_UNLOCK_ALL"]))
  arb:SetChecked(false)
  arb:Hide()

  function arb:Update()
    if self:GetChecked() then
      if not addon:IsHooked(ItemUtil, "GetCraftingReagentCount") then
        addon:RawHook(ItemUtil, "GetCraftingReagentCount", "GetCraftingReagentCountOverride", true)
      end
    else
      if addon:IsHooked(ItemUtil, "GetCraftingReagentCount") then
        addon:Unhook(ItemUtil, "GetCraftingReagentCount")
      end
    end

    local sf = self:GetParent()
    if sf then
      if ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView and ProfessionsFrame.OrdersPage.OrderView:IsVisible() then
        local schematicForm = ProfessionsFrame.OrdersPage.OrderView.OrderDetails and ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm
        if schematicForm then
          schematicForm:UpdateAllSlots()
        end
      elseif ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form and ProfessionsCustomerOrdersFrame.Form:IsVisible() then
        ProfessionsCustomerOrdersFrame.Form:OnEvent("BAG_UPDATE")
      elseif ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm then
        ProfessionsFrame.CraftingPage.SchematicForm:UpdateAllSlots()
      end

      local qd = sf.QualityDialog
      if qd and qd.recipeID then
        qd:Setup()
      end
    end
  end

  arb:SetScript("OnClick", function(selfBtn)
    selfBtn:Update()
  end)
  arb:SetScript("OnHide", function()
    if addon:IsHooked(ItemUtil, "GetCraftingReagentCount") then
      addon:Unhook(ItemUtil, "GetCraftingReagentCount")
    end
  end)

  return arb
end

function addon:AddCheckBox(target)
  if not target then
    return
  end

  local arb = target.UnlockAllReagents or self:CreateCheckBox(target)
  if not arb then
    return
  end

  if ItemUtil and self:IsHooked(ItemUtil, "GetCraftingReagentCount") then
    self:Unhook(ItemUtil, "GetCraftingReagentCount")
  end
  arb:ClearAllPoints()
  arb:SetChecked(false)
  if target.Label and target.Label:IsVisible() then
    arb:SetPoint("LEFT", target.Label, "LEFT", target.Label:GetWrappedWidth(), 0)
    arb:Show()
  else
    arb:Hide()
  end
end

function addon:GetCraftingReagentCountOverride()
  return 9999
end

function addon:UpdateSkillLine(frame)
  if (not frame or not frame.operationInfo or not frame.statLinePool) and frame and frame.GetParent then
    frame = frame:GetParent()
  end
  if not frame or not frame.operationInfo or not frame.statLinePool then
    return
  end

  for statLine in frame.statLinePool:EnumerateActive() do
    if statLine.LeftLabel:GetText() == PROFESSIONS_CRAFTING_STAT_TT_CRIT_HEADER then
      local text = self.FormatDetails(frame.operationInfo)
      statLine.RightLabel:SetText(text)
      break
    end
  end
end

function addon.FormatDetails(details)
  if not details then
    return nil
  end
  if details.learned == "notloaded" then
    return L["STATUS_NOT_LOADED"]
  end
  if details.learned == "notlearned" then
    return L["STATUS_NOT_LEARNED"]
  end
  if not details.isQualityCraft then
    return L["STATUS_OK"]
  end

  local skill = details.baseSkill + details.bonusSkill
  local bonus
  local pct

  for _, stat in pairs(details.bonusStats or {}) do
    if stat.bonusStatName == PROFESSIONS_CRAFTING_STAT_TT_CRIT_HEADER then
      pct, bonus = string.match(stat.ratingDescription or "", "([0-9]+%.?[0-9]+)%%[^0-9]+([0-9]+)")
      break
    end
  end

  if not (pct and bonus and skill) then
    return nil
  end

  local diff = skill - details.upperSkillTreshold + (skill < details.upperSkillTreshold and bonus or 0)
  local baseQuality = details.craftingQuality
  local procQuality = min(details.guaranteedCraftingQualityID <= 3 and 3 or 5, baseQuality + (diff >= 0 and 1 or 0))

  local icon = format("|A:%s:16:16|a", Professions.GetIconForQuality(procQuality, true))
  local iconNext = format("|A:%s:16:16|a", Professions.GetIconForQuality(min(5, procQuality + 1), true))

  local diffText = (diff < 0 and format("(|cffff0000%d|r to %s)", diff, iconNext))
    or (diff >= 0 and format("(|cff00ff00+%d|r)", diff))

  local text = (baseQuality == procQuality and format("%s%s", icon, diffText))
    or format("%.1f%% to %s%s", pct, icon, diffText)

  return text
end

function addon.compare(t1, t2, ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then
    return false
  end
  if ty1 ~= "table" and ty2 ~= "table" then
    return t1 == t2
  end
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then
    return t1 == t2
  end
  for k1, v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not addon.compare(v1, v2) then
      return false
    end
  end
  for k2, v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not addon.compare(v1, v2) then
      return false
    end
  end
  return true
end

function addon:CreateReminderFrame()
  if self.reminderFrame then
    return self.reminderFrame
  end

  local frame = CreateFrame("Frame", "ECUICraftingReminder", UIParent, "BackdropTemplate")
  frame:SetFrameStrata("HIGH")
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  frame:SetBackdropColor(0, 0, 0, 0.45)
  frame:SetBackdropBorderColor(0, 0.6, 0, 0.8)
  frame:Hide()

  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetPoint("CENTER", frame, "CENTER", 0, 0)
  text:SetTextColor(0.04, 1.0, 0.0, 1.0)
  text:SetText(self.db.profile.reminderText)
  frame.text = text

  self.reminderFrame = frame
  self:ApplyReminderLayout(frame)
  self:ApplyReminderStyle(frame)
  return frame
end

function addon:ApplyReminderLayout(frame)
  frame = frame or self.reminderFrame
  if not frame or not self.db or not self.db.profile then
    return
  end

  local profile = self.db.profile
  local anchor = tostring(profile.reminderAnchor or "CENTER")
  if not REMINDER_ANCHORS[anchor] then
    anchor = "CENTER"
  end
  local x = tonumber(profile.reminderX) or -434
  local y = tonumber(profile.reminderY) or -321
  local w = tonumber(profile.reminderWidth) or 380
  local h = tonumber(profile.reminderHeight) or 60
  w = math.max(160, min(1400, math.floor(w + 0.5)))
  h = math.max(30, min(600, math.floor(h + 0.5)))

  frame:SetSize(w, h)
  frame:ClearAllPoints()
  frame:SetPoint(anchor, UIParent, anchor, x, y)
end

function addon:ApplyReminderStyle(frame)
  frame = frame or self.reminderFrame
  if not frame or not frame.text or not self.db or not self.db.profile then
    return
  end

  local fontPath, _, fontFlags = GameFontNormalLarge:GetFont()
  local size = tonumber(self.db.profile.reminderFontSize) or 18
  size = math.max(8, min(64, math.floor(size + 0.5)))

  if not frame.text:SetFont(fontPath, size, fontFlags) then
    frame.text:SetFont(STANDARD_TEXT_FONT, size, fontFlags)
  end
end

function addon:ResetReminderLayoutDefaults()
  if not self.db or not self.db.profile then
    return
  end
  self.db.profile.reminderAnchor = "CENTER"
  self.db.profile.reminderX = -434
  self.db.profile.reminderY = -321
  self.db.profile.reminderWidth = 380
  self.db.profile.reminderHeight = 60
  self.db.profile.reminderFontSize = 18
  self:ApplyReminderLayout()
  self:ApplyReminderStyle()
end

function addon:ShowReminder()
  if not self.db.profile.reminderEnabled then
    return
  end

  local frame = self:CreateReminderFrame()
  self:ApplyReminderStyle(frame)
  frame.text:SetText(self.db.profile.reminderText or L["REMINDER_TEXT_DEFAULT"])
  frame:Show()

  if self.reminderTimer then
    self.reminderTimer:Cancel()
  end
  self.reminderTimer = C_Timer.NewTimer(tonumber(self.db.profile.reminderDuration) or 6, function()
    frame:Hide()
  end)

  self:PlayReminderSound()
end

function addon:PlayReminderSound()
  local sound = self.db and self.db.profile and self.db.profile.reminderSound
  if not sound or sound == "" then
    return false
  end

  local channel = self.db.profile.reminderSoundChannel or "Dialog"
  local channels = { channel, "Master", "SFX", "Dialog" }
  local tried = {}

  local function tryPlayOnChannel(ch)
    if not ch or tried[ch] then
      return false
    end
    tried[ch] = true

    if type(sound) == "string" and sound:find("^SOUNDKIT:") then
      local kitName = sound:match("^SOUNDKIT:(.+)$")
      local kitValue = kitName and SOUNDKIT and SOUNDKIT[kitName]
      if kitValue then
        local ok, played = pcall(PlaySound, kitValue, ch)
        if ok and played ~= false then
          return true
        end
      end
    end

    local ok, played = pcall(PlaySoundFile, sound, ch)
    if ok and played ~= false then
      return true
    end
    return false
  end

  for _, ch in ipairs(channels) do
    if tryPlayOnChannel(ch) then
      return true
    end
  end
  return false
end

function addon:CHAT_MSG_SYSTEM(_, message)
  if not self.db.profile.enabled then
    return
  end
  if tContainsText(message, self.db.profile.reminderSystemPattern or "") then
    self:ShowReminder()
  end
end

function addon:HandleSlash(input)
  local cmd, arg = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()

  if cmd == "" or cmd == "config" or cmd == "options" then
    self:OpenConfig()
    return
  end
  if cmd == "reload" then
    self:OnEnable()
    self:Print(L["SLASH_RELOADED"])
    return
  end
  if cmd == "debug" then
    self.db.profile.debug = not self.db.profile.debug
    self:Print(L["SLASH_DEBUG"] .. tostring(self.db.profile.debug))
    return
  end
  if cmd == "trace" then
    if arg == "on" then
      self.db.profile.trace = true
    elseif arg == "off" then
      self.db.profile.trace = false
    else
      self.db.profile.trace = not self.db.profile.trace
    end
    self:Print(L["SLASH_TRACE"] .. tostring(self.db.profile.trace))
    self:CaptureUIState("TraceToggle")
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("BlizzMove") then
      self:Print(L["SLASH_BLIZZMOVE_NOTE"])
    end
    return
  end
  if cmd == "dump" then
    self:DumpTrace()
    return
  end
  if cmd == "probe" then
    self:ProbeProfessionsFrame()
    return
  end
  if cmd == "state" then
    self:CaptureUIState("ManualState")
    self:DumpTrace()
    return
  end
  if cmd == "remind" then
    self:ShowReminder()
    return
  end
  if cmd == "enable" then
    self.db.profile.enabled = true
    self:Print(L["SLASH_ENABLED"])
    return
  end
  if cmd == "disable" then
    self.db.profile.enabled = false
    self:Print(L["SLASH_DISABLED"])
    return
  end

  self:Print(L["SLASH_HELP"])
end
