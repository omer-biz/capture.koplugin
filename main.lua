--[[--
Org Captrue inside koreader

@module koplugin.Capture
--]] --

local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputDialog = require("ui/widget/inputdialog")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local _ = require("gettext")
local GS = G_reader_settings
local DataStorage = require("datastorage")
local DocSettings = require("docsettings")
local Util = require("util")
local ffiUtil = require("ffi/util")

local OrgCapture = WidgetContainer:extend {
  name = "orgcapture",
  is_doc_only = true,
}

local function default_setting()
  return {
    target = "inbox.org",
    folder = DataStorage:getFullDataDir() .. "/org",
    templates_folder = DataStorage:getFullDataDir() .. "/capture_templates",
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

function OrgCapture:listTemplates()
  local templates = {
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
      separator = true
    }
  }



  return templates
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
