--[[--
Org Captrue inside koreader

@module koplugin.Capture
--]] --

local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputDialog = require("ui/widget/inputdialog")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local _ = require("gettext")
local ffiUtil = require("ffi/util")
local T = ffiUtil.template
local GS = G_reader_settings
local DataStorage = require("datastorage")
local DocSettings = require("docsettings")
local Util = require("util")

local OrgCapture = WidgetContainer:extend {
  name = "orgcapture",
  is_doc_only = true,
}

local function default_setting()
  return {
    strategy = "Unified",
    folder = DataStorage:getFullDataDir() .. "/org"
  }
end

function OrgCapture:loadSettings()
  if not self.ui.document or not self.ui.document.file then return end
  self.settings = default_setting()

  local global_settings = GS:readSetting("orgcapture")
  if global_settings ~= nil then
    Util.tableMerge(self.settings, GS:readSetting())
  end

  local doc_settings = DocSettings:open(self.ui.document.file)
  local local_settings = doc_settings:readSetting("orgcapture")
  if local_settings ~= nil then
    Util.tableMerge(self.settings, doc_settings:readSetting("orgcapture"))
  end
end

function OrgCapture:saveLocalSetting(key, value)
  if not self.ui.document or not self.ui.document.file then return end

  self.settings[key] = value

  local doc_settings = DocSettings:open(self.ui.document.file)
  local saved_local = doc_settings:readSetting("orgcapture") or {}
  saved_local[key] = value

  doc_settings:saveSetting("orgcapture", saved_local)
  doc_settings:flush()
end

function OrgCapture:saveGlobalSetting(key, value)
  self.settings[key] = value
  local saved_global = GS:readSetting("orgcapture") or {}

  saved_global[key] = value
  GS:saveSetting("orgcapture", saved_global)
  GS:flush()
end

function OrgCapture:init()
  self:loadSettings()

  self.ui.menu:registerToMainMenu(self)

  if self.ui.highlight then
    self:addToHighlightDialog()
  end
end

function OrgCapture:addToMainMenu(menu_items)
  menu_items.org_capture = {
    text = _("Capture"),
    sorting_hint = "tools",
    keep_menu_open = true,
    sub_item_table = {
      {
        text = _("About Capture"),
        keep_menu_open = true,
      },
      {
        text = _("Capture Templates"),
        keep_menu_open = true,
        callback = function()
          print("TODO: list capture templats as well as allowing to edit and add new ones")
        end,
        separator = true
      },
      {
        text_func = function()
          return T(_("Capture Strategy: %1"),
            self.settings.strategy)
        end,

        keep_menu_open = true,
        sub_item_table = {
          {
            text = _("Unified"),
            radio = true,
            checked_func = function()
              return self.settings.strategy == "Unified"
            end,
            callback = function()
              self:saveSetting("strategy", "Unified")
            end,
          },
          {
            text = _("Per Book"),
            radio = true,
            keep_menu_open = true,
            checked_func = function()
              return self.settings.strategy == "Per Book"
            end,
            callback = function()
              self:saveSetting("strategy", "Per Book")
            end,
          }
        }
      },
      {
        text = "Select Folder",
        keep_menu_open = true,
        callback = function()
          local current_path = self.settings.folder

          filemanagerutil.showChooseDialog("Current Capture Folder", function(path)
              self:saveLocalSetting("folder", path)
            end,
            current_path,
            DataStorage:getFullDataDir() .. "/org",
            nil)
        end
      }
    }
  }
end

function OrgCapture:addToHighlightDialog()
  self.ui.highlight:addToHighlightDialog("13_capture_default", function(this)
    return {
      text = _("Capture (Org)"),
      callback = function()
        local selected_text = this.selected_text.text
        local template = string.format([[
*** %s
:PROPERTIES:
:CREATED: %s
:END:

#+begin_quote
%s
#+end_quote

]],
          selected_text:sub(1, 10),
          os.date("!%Y-%m-%dT%H:%M:%SZ"),
          selected_text
        )

        local dialog
        dialog = InputDialog:new {
          title = _("Org Capture"),
          input = template,
          allow_newline = true,
          fullscreen = true,
          cursor_at_end = true,
          add_nav_bar = true,
          save_callback = function(content, closing)
            if closing then
              UIManager:nextTick(
              -- Stuff to do when InputDialog is closed, if anything.
              )
            end
            -- TODO: write `content` to org file
            return true, "Highlight captured sucessfully"
          end
        }

        UIManager:show(dialog)
        dialog:onShowKeyboard()
      end
    }
  end)
end

return OrgCapture
