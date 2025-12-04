--[[--
This is a debug plugin to test Plugin functionality.

@module koplugin.Capture
--]]                                     --

local Dispatcher = require("dispatcher") -- luacheck:ignore
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputDialog = require("ui/widget/inputdialog")
local _ = require("gettext")
local ffiUtil = require("ffi/util")
local T = ffiUtil.template

local Hello = WidgetContainer:extend {
  name = "hello",
  is_doc_only = false,
}

function Hello:onDispatcherRegisterActions()
  Dispatcher:registerAction("helloworld_action",
    { category = "none", event = "HelloWorld", title = _("Hello World"), general = true, })
end

function Hello:init()
  self:onDispatcherRegisterActions()
  self.ui.menu:registerToMainMenu(self)

  if self.ui.highlight then
    self:addToHighlightDialog()
  end
end

function Hello:addToMainMenu(menu_items)
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
            G_reader_settings:readSetting("org_capture_strategy", "Unified"))
        end,

        keep_menu_open = true,
        sub_item_table = {
          {
            text = _("Unified"),
            radio = true,
            checked_func = function()
              return G_reader_settings:readSetting("org_capture_strategy", {}) == "Unified"
            end,
            callback = function() G_reader_settings:saveSetting("org_capture_strategy", "Unified") end,
          },
          {
            text = _("Per Book"),
            radio = true,
            keep_menu_open = true,
            checked_func = function()
              return G_reader_settings:readSetting("org_capture_strategy", {}) == "Per Book"
            end,
            callback = function() G_reader_settings:saveSetting("org_capture_strategy", "Per Book") end,
          }
        }
      },
      {
        text = _("Select Folder"),
        keep_menu_open = true,
        callback = function()
          print("TODO: prompt folder selector")
        end
      },
    }
  }
end

function Hello:addToHighlightDialog()
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

function Hello:onHelloWorld()
  local popup = InfoMessage:new {
    text = _("Hello World"),
  }
  UIManager:show(popup)
end

return Hello
