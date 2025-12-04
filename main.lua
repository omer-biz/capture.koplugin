--[[--
This is a debug plugin to test Plugin functionality.

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

local OrgCapture = WidgetContainer:extend {
  name = "hello",
  is_doc_only = false,
}

local function default_setting()
  return {
    strategy = "Unified",
    folder = DataStorage:getFullDataDir() .. "/org"
  }
end

function OrgCapture:init()
  self.settings = GS:readSetting("org-capture") or default_setting()

  self.ui.menu:registerToMainMenu(self)

  if self.ui.highlight then
    self:addToHighlightDialog()
  end
end

function OrgCapture:saveSetting(setting, value)
  self.settings[setting] = value
  GS:saveSetting("org-capture", self.settings)
end

function OrgCapture:addToMainMenu(menu_items)
  menu_items.org_capture = {
    text = _("Capture"),
    sorting_hint = "more_tools",
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
              self:saveSetting("folder", path)
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
