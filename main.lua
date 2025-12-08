--[[--
Org Captrue inside koreader

@module koplugin.Capture
--]] --

local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local KeyValuePage = require("ui/widget/keyvaluepage")
local CheckButton = require("ui/widget/checkbutton")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local _ = require("gettext")
local GS = G_reader_settings
local DataStorage = require("datastorage")
local DocSettings = require("docsettings")
local Util = require("util")
local ffiUtil = require("ffi/util")
local T = ffiUtil.template
local FileManagerBookInfo = require("apps/filemanager/filemanagerbookinfo")

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
    Util.tableMerge(self.settings, global_settings)
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
function OrgCapture:templateEditor(template, closing_callback)
  local input_dialog
  local check_default_button

  input_dialog = InputDialog:new {
    title = T(_("Edit: %1"), template.name),
    input = "",
    allow_newline = true,
    fullscreen = true,
    save_callback = function(content)
      Util.writeToFile(content, template.path, true)
      return true, string.format("%q saved successfully", template.name)
    end,
    close_callback = function()
      -- INFO: This is a hack to redraw KeyValuePage with the newly created template
      if template.name ~= "" and closing_callback then
        closing_callback()
      end
    end,
    buttons = {
      {
        {
          text = _("Info"),
          callback = function()
            UIManager:show(InfoMessage:new {
              text = _([[
%i highlighted text
%T title
%A author
%S series
%t total pages
%c current page
%l pages left in chapter
%p book percentage read
%H time left in book
%C chapter title
%P chapter percentage read
%h time left in chapter
%F file path
%f file name
%b battery level
%B battery symbol
%r separator
%D current date (yyyy-mm-dd)
%d current date (mm-dd)
%m current time (hh:mm)
%M current time (hh-mm-ss)]]),
              monospace_font = true,
            })
          end
        }
      }
    }
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

local function getTemplatesFromFS(templates_folder)
  local templates = {}
  Util.findFiles(templates_folder, function(path, name)
    table.insert(templates,
      {
        name = name,
        path = ffiUtil.joinPath(templates_folder, path)
      })
  end)
  return templates
end

function OrgCapture:listTemplates()
  local function newTemplate() end

  local function buildTemplates()
    local templates = getTemplatesFromFS(self.settings.templates_folder)
    local templates_list = {}

    for _k, t in ipairs(templates) do
      local templ = t
      table.insert(templates_list, {
        _(templ.name),
        "",
        callback = function()
          self:templateEditor(templ)
        end,
      })
    end

    table.insert(templates_list, "--------------")
    table.insert(templates_list, { _("Add new template"), "", callback = newTemplate })

    return templates_list
  end


  function newTemplate()
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

              filename = filename:gsub("^%s+", ""):gsub("%s+$", "")
              if filename == "" then return end

              self:templateEditor({
                name = filename,
                path = ffiUtil.joinPath(self.settings.templates_folder, filename)
              }, function()
                -- There must be a better way to refresh the list kvs
                if self.templates_page then
                  UIManager:close(self.templates_page)
                end
                self.templates_page = KeyValuePage:new {
                  title = _("Capture Templates"),
                  kv_pairs = buildTemplates()
                }

                UIManager:show(self.templates_page)
              end)
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
    UIManager:nextTick(function()
      input_dialog:onShowKeyboard()
    end)
  end

  self.templates_page = KeyValuePage:new {
    title = _("Capture Templates"),
    kv_pairs = buildTemplates()
  }

  UIManager:show(self.templates_page)
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
        callback = function()
          local msg = [[
KOReader Org-Capture Plugin
Version: 1.0

Capture highlights from KOReader into Org-mode files.
Supports templates, and dynamic target paths.

Author: Omer A. Adem
GitHub: https://github.com/omer-biz/capture.koplugin

Enjoy seamless note-taking and knowledge management!
]]

          UIManager:show(InfoMessage:new { text = msg })
        end
      },
      {
        text = _("Capture Templates"),
        keep_menu_open = true,
        callback = function()
          self:listTemplates()
        end,
        separator = true,
      },
      {
        text = _("Capture Target"),
        keep_menu_open = true,
        callback = function()
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
      },
      {
        text = _("Templates Folder"),
        keep_menu_open = true,
        callback = function()
          filemanagerutil.showChooseDialog("capture templates folder", function(path)
              self:saveLocalSetting("templates_folder", path)
            end,
            self.settings.templates_folder,
            default_setting().templates_folder,
            nil)
        end,
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

        local default_template = ffiUtil.joinPath(
          ffiUtil.joinPath(DataStorage:getFullDataDir(),
            self.settings.templates_folder),
          self.settings.default_capture_t)

        local template = Util.readFromFile(default_template)
        local highlight_replace = template:gsub("%%i", selected_text)
        local expanded = self.ui.bookinfo:expandString(highlight_replace)

        local dialog
        dialog = InputDialog:new {
          title = _("Org Capture"),
          input = expanded,
          allow_newline = true,
          fullscreen = true,
          cursor_at_end = true,
          add_nav_bar = true,
          save_callback = function(content)
            local expanded_target = self.ui.bookinfo:expandString(self.settings.target)
            expanded_target = expanded_target:gsub("[/\\:*?\"<>|]", "-")
            local base_dir = ffiUtil.joinPath(
              DataStorage:getFullDataDir(),
              self.settings.folder
            )
            local fullpath = ffiUtil.joinPath(base_dir, expanded_target)

            if not Util.fileExists(fullpath) then
              Util.makePath(base_dir)
              Util.writeToFile(content, fullpath, true)
              return true, "Highlight captured created successfully"
            end

            local capture_file = io.open(fullpath, "a+")
            if not capture_file then
              return false, "Coudn't open capture file"
            end
            capture_file:write("\n", content, "\n")
            capture_file:close()

            return true, "Highlight captured updated successfully"
          end
        }

        UIManager:show(dialog)
        dialog:onShowKeyboard()
      end
    }
  end)
end

return OrgCapture
