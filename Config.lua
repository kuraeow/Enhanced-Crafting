local AddonName, ns = ...
local addon = ns.Addon
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local APP_NAME = "EnhancedCrafting"
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local REMINDER_SOUND_OPTIONS = {
  ["SOUNDKIT:RAID_WARNING"] = "SOUND_RAID_WARNING",
  ["SOUNDKIT:ALARM_CLOCK_WARNING_3"] = "SOUND_ALARM_CLOCK",
  ["SOUNDKIT:LEVELUP"] = "SOUND_LEVEL_UP",
  ["SOUNDKIT:MAP_PING"] = "SOUND_MAP_PING",
  ["SOUNDKIT:READY_CHECK"] = "SOUND_READY_CHECK",
  ["SOUNDKIT:PVP_THROUGH_QUEUE"] = "SOUND_FLAG_TAKEN"
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

local function getValue(key)
  return addon.db.profile[key]
end

local function setValue(key, value)
  addon.db.profile[key] = value
  if key == "reminderEnabled" and not value then
    addon:SetReminderPreviewForConfig(false)
    if addon.reminderFrame then
      addon.reminderFrame:Hide()
    end
  end
  if key == "reminderText" and addon.reminderFrame and addon.reminderFrame.text then
    addon.reminderFrame.text:SetText(value or "")
  end
  if key == "reminderFontSize" then
    addon:ApplyReminderStyle()
  end
  if key == "reminderAnchor" or key == "reminderX" or key == "reminderY" or key == "reminderWidth" or key == "reminderHeight" then
    addon:ApplyReminderLayout()
  end
  if key == "reminderEnabled" then
    AceConfigRegistry:NotifyChange(APP_NAME)
  end
end

function addon:ResetAllSettings()
  addon.db:ResetProfile()
  if addon.reminderTimer then
    addon.reminderTimer:Cancel()
    addon.reminderTimer = nil
  end
  if addon.reminderFrame then
    addon.reminderFrame:Hide()
  end
  addon:ApplyReminderLayout()
  addon:ApplyReminderStyle()
  addon:SetReminderPreviewForConfig(false)
  addon:OnEnable()
  AceConfigRegistry:NotifyChange(APP_NAME)
  addon:Print(L["MSG_SETTINGS_RESET"])
end

function addon:SetReminderPreviewForConfig(active)
  self.reminderPreviewForConfig = active and true or false

  if self.reminderTimer then
    self.reminderTimer:Cancel()
    self.reminderTimer = nil
  end

  local frame = self.reminderFrame
  if self.reminderPreviewForConfig then
    frame = self:CreateReminderFrame()
    self:ApplyReminderLayout(frame)
    self:ApplyReminderStyle(frame)
    frame.text:SetText(self.db.profile.reminderText or L["REMINDER_TEXT_DEFAULT"])
    frame:Show()
  elseif frame then
    frame:Hide()
  end
end

function addon:EnsureHeaderResetButton()
  local panel = self.optionsPanel
  if not panel or self.resetAllButton then
    return
  end

  local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  btn:SetSize(140, 22)
  if btn.SetTextToFit then
    btn:SetTextToFit(L["OPT_RESET_ALL"])
  else
    btn:SetText(L["OPT_RESET_ALL"])
  end
  btn:ClearAllPoints()
  btn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -12)
  btn:SetScript("OnClick", function()
    addon:ResetAllSettings()
  end)

  self.resetAllButton = btn

  if not panel.ecraftOnHideHooked then
    panel.ecraftOnHideHooked = true
    panel:HookScript("OnHide", function()
      if addon.reminderPreviewForConfig then
        addon:SetReminderPreviewForConfig(false)
        AceConfigRegistry:NotifyChange(APP_NAME)
      end
    end)
  end
end

function addon:SetupOptions()
  local function reminderHidden()
    return not getValue("reminderEnabled")
  end

  local options = {
    name = L["ADDON_NAME"],
    type = "group",
    args = {
      mainDesc = {
        type = "description",
        order = 1,
        width = "full",
        name = string.format("%s\nVersion: %s", L["OPT_MAIN_DESC"], getAddonVersion())
      },
      enabled = {
        type = "toggle",
        order = 10,
        name = L["OPT_ENABLE_ADDON"],
        get = function() return getValue("enabled") end,
        set = function(_, v) setValue("enabled", v) end
      },
      reminderHeader = {
        type = "header",
        order = 40,
        name = L["OPT_REMINDER_HEADER"]
      },
      reminderEnabled = {
        type = "toggle",
        order = 50,
        width = "normal",
        name = L["OPT_REMINDER_ENABLE"],
        get = function() return getValue("reminderEnabled") end,
        set = function(_, v) setValue("reminderEnabled", v) end
      },
      reminderPreviewInConfig = {
        type = "toggle",
        order = 50.1,
        width = "normal",
        name = L["OPT_REMINDER_PREVIEW"],
        desc = L["OPT_REMINDER_PREVIEW_DESC"],
        hidden = reminderHidden,
        get = function() return addon.reminderPreviewForConfig and true or false end,
        set = function(_, v) addon:SetReminderPreviewForConfig(v) end
      },
      reminderText = {
        type = "input",
        order = 60,
        width = "full",
        name = L["OPT_REMINDER_TEXT"],
        hidden = reminderHidden,
        get = function() return getValue("reminderText") or "" end,
        set = function(_, v) setValue("reminderText", v or "") end
      },
      reminderSystemPattern = {
        type = "input",
        order = 70,
        width = "full",
        name = L["OPT_REMINDER_PATTERN"],
        desc = L["OPT_REMINDER_PATTERN_DESC"],
        hidden = reminderHidden,
        get = function() return getValue("reminderSystemPattern") or "" end,
        set = function(_, v) setValue("reminderSystemPattern", v or "") end
      },
      reminderDuration = {
        type = "range",
        order = 80,
        name = L["OPT_REMINDER_DURATION"],
        hidden = reminderHidden,
        min = 1,
        max = 20,
        step = 1,
        get = function() return tonumber(getValue("reminderDuration")) or 6 end,
        set = function(_, v) setValue("reminderDuration", tonumber(v) or 6) end
      },
      reminderFontSize = {
        type = "range",
        order = 80.5,
        name = L["OPT_REMINDER_FONT_SIZE"],
        hidden = reminderHidden,
        min = 8,
        max = 64,
        step = 1,
        get = function() return tonumber(getValue("reminderFontSize")) or 18 end,
        set = function(_, v) setValue("reminderFontSize", tonumber(v) or 18) end
      },
      reminderAnchor = {
        type = "select",
        order = 81,
        name = L["OPT_REMINDER_ANCHOR"],
        hidden = reminderHidden,
        values = {
          CENTER = L["ANCHOR_CENTER"],
          TOPLEFT = L["ANCHOR_TOPLEFT"],
          TOP = L["ANCHOR_TOP"],
          TOPRIGHT = L["ANCHOR_TOPRIGHT"],
          LEFT = L["ANCHOR_LEFT"],
          RIGHT = L["ANCHOR_RIGHT"],
          BOTTOMLEFT = L["ANCHOR_BOTTOMLEFT"],
          BOTTOM = L["ANCHOR_BOTTOM"],
          BOTTOMRIGHT = L["ANCHOR_BOTTOMRIGHT"]
        },
        get = function() return getValue("reminderAnchor") or "CENTER" end,
        set = function(_, v) setValue("reminderAnchor", v) end
      },
      reminderCoordsBreak = {
        type = "description",
        order = 81.5,
        name = " ",
        width = "full",
        hidden = reminderHidden
      },
      reminderX = {
        type = "range",
        order = 82,
        name = L["OPT_REMINDER_X"],
        hidden = reminderHidden,
        min = -2000,
        max = 2000,
        step = 1,
        bigStep = 10,
        get = function() return tonumber(getValue("reminderX")) or -434 end,
        set = function(_, v) setValue("reminderX", tonumber(v) or -434) end
      },
      reminderY = {
        type = "range",
        order = 83,
        name = L["OPT_REMINDER_Y"],
        hidden = reminderHidden,
        min = -2000,
        max = 2000,
        step = 1,
        bigStep = 10,
        get = function() return tonumber(getValue("reminderY")) or -321 end,
        set = function(_, v) setValue("reminderY", tonumber(v) or -321) end
      },
      reminderSizeBreak = {
        type = "description",
        order = 83.5,
        name = " ",
        width = "full",
        hidden = reminderHidden
      },
      reminderWidth = {
        type = "range",
        order = 84,
        name = L["OPT_REMINDER_WIDTH"],
        hidden = reminderHidden,
        min = 160,
        max = 1400,
        step = 1,
        bigStep = 10,
        get = function() return tonumber(getValue("reminderWidth")) or 380 end,
        set = function(_, v) setValue("reminderWidth", tonumber(v) or 380) end
      },
      reminderHeight = {
        type = "range",
        order = 85,
        name = L["OPT_REMINDER_HEIGHT"],
        hidden = reminderHidden,
        min = 30,
        max = 600,
        step = 1,
        bigStep = 10,
        get = function() return tonumber(getValue("reminderHeight")) or 60 end,
        set = function(_, v) setValue("reminderHeight", tonumber(v) or 60) end
      },
      reminderSound = {
        type = "select",
        order = 90,
        width = "normal",
        name = L["OPT_REMINDER_SOUND"],
        hidden = reminderHidden,
        values = function()
          local values = {}
          for path, key in pairs(REMINDER_SOUND_OPTIONS) do
            values[path] = L[key]
          end
          local current = getValue("reminderSound")
          if current and current ~= "" and not values[current] then
            values[current] = L["SOUND_CUSTOM_SAVED"]
          end
          return values
        end,
        get = function()
          local current = getValue("reminderSound")
          if current and current ~= "" then
            return current
          end
          return "SOUNDKIT:RAID_WARNING"
        end,
        set = function(_, v) setValue("reminderSound", v or "SOUNDKIT:RAID_WARNING") end
      },
      reminderPlaySound = {
        type = "execute",
        order = 90.1,
        width = "normal",
        name = L["OPT_REMINDER_PLAY_SOUND"],
        hidden = reminderHidden,
        func = function()
          local played = addon:PlayReminderSound()
          if not played then
            addon:Print(L["MSG_SOUND_PLAY_FAILED"])
          end
        end
      },
      reminderSoundChannel = {
        type = "select",
        order = 100,
        name = L["OPT_SOUND_CHANNEL"],
        hidden = reminderHidden,
        values = {
          Master = L["SOUND_MASTER"],
          SFX = "SFX",
          Music = L["SOUND_MUSIC"],
          Ambience = L["SOUND_AMBIENCE"],
          Dialog = L["SOUND_DIALOG"]
        },
        get = function() return getValue("reminderSoundChannel") or "SFX" end,
        set = function(_, v) setValue("reminderSoundChannel", v) end
      },
      testReminder = {
        type = "execute",
        order = 101,
        name = L["OPT_TEST_REMINDER"],
        hidden = reminderHidden,
        func = function() addon:ShowReminder() end
      },
      toolsHeader = {
        type = "header",
        order = 110,
        name = L["OPT_TOOLS_HEADER"]
      },
      debug = {
        type = "toggle",
        order = 120,
        name = L["OPT_DEBUG"],
        get = function() return getValue("debug") end,
        set = function(_, v) setValue("debug", v) end
      },
      trace = {
        type = "toggle",
        order = 121,
        name = L["OPT_TRACE"],
        desc = L["OPT_TRACE_DESC"],
        get = function() return getValue("trace") end,
        set = function(_, v) setValue("trace", v) end
      },
      reloadHooks = {
        type = "execute",
        order = 150,
        name = L["OPT_RELOAD_HOOKS"],
        func = function() addon:OnEnable() end
      }
    }
  }

  AceConfig:RegisterOptionsTable(APP_NAME, options)
  local panel, categoryId = AceConfigDialog:AddToBlizOptions(APP_NAME, L["ADDON_NAME"])
  self.optionsPanel = panel
  self.optionsCategoryId = categoryId
  self:EnsureHeaderResetButton()
end

function addon:OpenConfig()
  self:EnsureHeaderResetButton()
  if Settings and Settings.OpenToCategory and self.optionsCategoryId then
    Settings.OpenToCategory(self.optionsCategoryId)
    return
  end
  AceConfigDialog:Open(APP_NAME)
end
