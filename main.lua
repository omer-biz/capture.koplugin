--[[--
Org Captrue inside koreader

@module koplugin.Capture
--]] --

local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputDialog = require("ui/widget/inputdialog")
local CheckButton = require("ui/widget/checkbutton")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local _ = require("gettext")
local GS = G_reader_settings
local DataStorage = require("datastorage")
local DocSettings = require("docsettings")
local Util = require("util")
local ffiUtil = require("ffi/util")
local T = ffiUtil.template

local OrgCapture = WidgetContainer:extend {
  name = "orgcapture",
  is_doc_only = true,
}

local function default_setting()
  return {
    target = "inbox.org",
    folder = DataStorage:getFullDataDir() .. "/org",
    templates_folder = DataStorage:getFullDataDir() .. "/capture_templates",
    default_capture_t = "default.orgcapture"
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
  self:createDefaultTemplates()

  self.ui.menu:registerToMainMenu(self)

  if self.ui.highlight then
    self:addToHighlightDialog()
  end
end

function OrgCapture:createDefaultTemplates()
  if (self.settings.templates_folder == default_setting().templates_folder) then
    if (not Util.pathExists(self.settings.templates_folder)) then
      Util.makePath(self.settings.templates_folder)
    end

    if (Util.isEmptyDir(self.settings.templates_folder)) then
      -- copy from "./templates/*" to self.settings.template_folder the captrue files
      local templates_dir_src = ffiUtil.joinPath(self.path, "templates")
      local templates_dir_des = self.settings.templates_folder

      Util.findFiles(templates_dir_src, function(fullpath, filename)
        fullpath = ffiUtil.joinPath(DataStorage:getFullDataDir(), fullpath)
        ffiUtil.copyFile(fullpath, ffiUtil.joinPath(templates_dir_des, filename))
      end, false)
    end
  end
end

-- template is { name = "name.orgcapture", path = "/full/path/name.orgcapture" }
function OrgCapture:templateEditor(template)
  local input_dialog
  local check_default_button

  input_dialog = InputDialog:new {
    title = T(_("Edit: %1"), template.name),
    input = "",
    allow_newline = true,
    fullscreen = true,
    save_callback = function(content)
      print("wrting to", template.path)
      Util.writeToFile(content, template.path, true)
      return true, string.format("%q saved successfully", template.name)
    end
  }

  check_default_button = CheckButton:new {
    text = _("Set as the default captrue"),
    checked = self.settings.default_capture_t == template.name,
    parent = input_dialog,
    callback = function()
      self:saveLocalSetting("default_capture_t", template.name)
    end,
    hold_callback = function()
      self:saveGlobalSetting("default_capture_t", template.name)
    end
  }

  input_dialog:addWidget(check_default_button)

  UIManager:show(input_dialog)

  UIManager:nextTick(function()
    local content = Util.readFromFile(template.path)
    if content then
      input_dialog:setInputText(content)
    end
    input_dialog:onShowKeyboard()
  end)
end

-- FIX: new file are not being shown after their creation
function OrgCapture:listTemplates()
  local templates_menu = {
    {
      text = _("Templates Folder"),
      callback = function()
        filemanagerutil.showChooseDialog("capture templates folder", function(path)
            self:saveLocalSetting("templates_folder", path)
          end,
          self.settings.templates_folder,
          default_setting().templates_folder,
          nil)
      end,
    },
    {
      text = _("New Template"),
      callback = function()
        local input_dialog
        input_dialog = InputDialog:new {
          title = _("File Name"),
          input = "name.orgcapture",
          buttons = {
            {
              {
                text = _("Continue"),
                callback = function()
                  local filename = input_dialog:getInputValue()
                  UIManager:close(input_dialog)
                  -- TODO: trim and chedk if it's not empty
                  self:templateEditor({
                    name = input_dialog:getInputValue(),
                    path = ffiUtil.joinPath(self.settings.templates_folder, filename)
                  })
                end
              },
              {
                text = _("Cancel"),
                callback = function()
                  UIManager:close(input_dialog)
                end
              }
            }
          }
        }
        UIManager:show(input_dialog)
        input_dialog:onShowKeyboard()
      end,
      separator = true
    }
  }

  local templates = {}
  Util.findFiles(self.settings.templates_folder, function(fullpath, name)
    table.insert(templates,
      {
        name = name,
        path = ffiUtil.joinPath(self.settings.templates_folder, fullpath)
      })
  end)

  for _k, t in pairs(templates) do
    table.insert(templates_menu, {
      text = _(t.name),
      callback = function()
        self:templateEditor(t)
      end
    })
  end

  return templates_menu
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
        sub_item_table = self:listTemplates(),
        separator = true
      },
      {
        text = _("Capture Target"),
        keep_menu_open = true,
        callback = function()
          local FileManagerBookInfo = require("apps/filemanager/filemanagerbookinfo")
          local input_dialog
          input_dialog = InputDialog:new {
            title = _("Capture target"),
            input = self.settings.target,
            save_callback = function(content)
              self:saveLocalSetting("target", content)
              return true, string.format("Saved: %q", self.ui.bookinfo:expandString(content))
            end,
            buttons = {
              {
                {
                  text = _("Info"),
                  callback = FileManagerBookInfo.expandString,
                },
              }
            }
          }

          UIManager:show(input_dialog)
          input_dialog:onShowKeyboard()
        end
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
