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
  menu_items.hello_world = {
    text = _("Capture"),
    -- in which menu this should be appended
    sorting_hint = "more_tools",
    -- a callback when tapping
    callback = function()
      UIManager:show(InfoMessage:new {
        text = _("Hello, plugin world"),
      })
    end,
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
          buttons = {
            {
              {
                text = _("Cancel"),
                callback = function()
                  UIManager:close(dialog)
                end,
              },
              {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                  local final_text = dialog:getInputText()
                  UIManager:close(dialog)
                  UIManager:show(InfoMessage:new {
                    text = _("Captured:\n") .. final_text:sub(1, 200),
                  })
                end,
              },
            },
          }
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
