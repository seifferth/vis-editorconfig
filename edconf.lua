-- Copyright 2018-2019 Samadi van Koten
-- Copyright 2019-2025 Frank Seifferth
-- Copyright 2021-2023 Florian Fischer
-- Copyright 2025 Matěj Cepl

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


require "vis"
local ec = require "editorconfig"
local M = {}

-- Simple wrapper
local function vis_set(option, value)
  if type(value) == "boolean" then
    if value then
      value = "yes"
    else
      value = "no"
    end
  end

  vis:command("set " .. option .. " " .. value)
end

local function set_pre_save(f, value)
  if value == "true" then
    vis.events.subscribe(vis.events.FILE_SAVE_PRE, f)
  else
    vis.events.unsubscribe(vis.events.FILE_SAVE_PRE, f)
  end
end

local function set_file_open(f, value)
  if value == "true" then
    vis.events.subscribe(vis.events.FILE_OPEN, f)
  else
    vis.events.unsubscribe(vis.events.FILE_OPEN, f)
  end
end

-- Custom functionality
M.enable_hooks = false
vis:option_register("edconfhooks", "bool", function(value)
  M.enable_hooks = value
end, "Enable optional pre-save-hooks for certain editorconfig settings")

local function insert_final_newline(file)
  -- Technically speaking, this is a pre-save-hook as well and could
  -- therefore respect edconf_hooks_enabled. Since this function runs
  -- blazingly fast and scales with a complexity of O(1), however,
  -- there is no need to disable it.
  if file.size > 0 and file:content(file.size-1, 1) ~= '\n' then
    file:insert(file.size, '\n')
  end
end

local function strip_final_newline(file)
  -- In theory, this would have a complexity of O(n) as well and could
  -- thus be made optional via edconf_hooks_enabled. On the other hand,
  -- this is probably a very rare edge case, so stripping all trailing
  -- newline characters is probably safe enough.
  while file:content(file.size-1, 1) == '\n' do
    file:delete(file.size-1, 1)
  end
end

local function trim_trailing_whitespace(file)
  if not M.enable_hooks then return end
  for i=1, #file.lines do
    if string.match(file.lines[i], '[ \t]$') then
      file.lines[i] = string.gsub(file.lines[i], '[ \t]*$', '')
    end
  end
end

local function enforce_crlf_eol(file)
  if not M.enable_hooks then return end
  for i=1, #file.lines do
    if not string.match(file.lines[i], '\r$') then
      file.lines[i] = string.gsub(file.lines[i], '$', '\r')
    end
  end
end

local function enforce_lf_eol(file)
  if not M.enable_hooks then return end
  for i=1, #file.lines do
    if string.match(file.lines[i], '\r$') then
      file.lines[i] = string.gsub(file.lines[i], '\r$', '')
    end
  end
end

M.max_line_length = 80     -- This is ugly, but we do want to use
                           -- single function that we can register
                           -- or unregister as needed
local function max_line_length(file)
  if not M.enable_hooks then return end
  local overlong_lines = {}
  for i=1, #file.lines do
    if string.len(file.lines[i]) > M.max_line_length then
      table.insert(overlong_lines, i)
    end
  end
  if #overlong_lines > 0 then
    local lines_are = (function(x)
        if x>1 then return "lines are" else return "line is" end
    end)(#overlong_lines)
    vis:info(string.format(
      "%d %s longer than %d characters: %s",
      #overlong_lines, lines_are, M.max_line_length,
      table.concat(overlong_lines, ",")
    ))
  end
end

local OPTIONS = {
  indent_style = function (value)
    vis_set("expandtab", (value == "space"))
  end,

  indent_size = function (value)
    if value ~= "tab" then -- tab_width is a synonym anyway
      vis_set("tabwidth", value)
    end
  end,

  tab_width = function (value)
    vis_set("tabwidth", value)
  end,

  spelling_language = function (value, file)
    file.spelling_language = value
  end,

  insert_final_newline = function (value)
    -- According to the editorconfig specification, insert_final_newline
    -- false is supposed to mean stripping the final newline, if present.
    -- See https://editorconfig-specification.readthedocs.io/#supported-pairs
    --
    -- Quote: insert_final_newline Set to true ensure file ends with a
    -- newline when saving and false to ensure it doesn’t.
    --
    set_pre_save(insert_final_newline, tostring(value == "true"))
    set_pre_save(strip_final_newline, tostring(value == "false"))
  end,

  trim_trailing_whitespace = function (value)
    set_pre_save(trim_trailing_whitespace, value)
  end,

  -- End of line is only partially implemented. While vis does not
  -- support customized newlines, it does work well enough with crlf
  -- newlines. Therefore, setting end_of_line=crlf will just ensure
  -- that there is a cr at the end of each line. Setting end_of_line=lf
  -- will strip any cr characters at the end of lines. This hopefully
  -- eases the pain of working with crlf files a little.
  end_of_line = function (value)
    set_pre_save(enforce_crlf_eol, tostring(value == "crlf"))
    set_pre_save(enforce_lf_eol, tostring(value == "lf"))
  end,

  -- There is probably no straightforward way to enforce a maximum line
  -- length across different programming languages. If a maximum line
  -- length is set, we can at least issue a warning, however.
  max_line_length = function(value)
    if value ~= "off" then
      M.max_line_length = tonumber(value)
    end
    set_pre_save(max_line_length, tostring(value ~= "off"))
  end,

  -- Not supported by vis
  --   charset
  -- Partial support
  --   end_of_line
  --   max_line_length

  -- What follows is non-standard functionality supported by this plugin
  -- but not defined in the editorconfig standard. To enable these
  -- functions, set 'module.enable_non_standard.function_name = true'
  -- after loading this module as 'module = require("editorconfig")'
  --
  -- To activate the x_spelling_enable function, for instance, you
  -- would use 'module.enable_non_standard.x_spelling_enable = true'
  x_spelling_enable = function(value, file)
    if not M.enable_non_standard.x_spelling_enable then return end
    file.spelling_enable = value
    vis:info("setting " .. value)
  end,
}

M.enable_non_standard = {
  x_spelling_enable = false,
}

-- Compatible with editorconfig-core-lua v0.3.0
local function ec_iter(p)
  local i = 0
  local props, keys = ec.parse(p)
  local n = #keys
  return function ()
    i = i + 1
    if i <= n then
      return keys[i], props[keys[i]]
    end
  end
end

local function ec_set_values(win)
  if not win or not win.file or not win.file.path then return end
  for name, value in ec_iter(win.file.path) do
    if OPTIONS[name] then
      OPTIONS[name](value, win.file)
    end
  end
end


vis:command_register("econfig_parse", function()
  ec_set_values(vis.win)
end, "(Re)parse an editorconfig file")

vis.events.subscribe(vis.events.WIN_OPEN, function (win)
  ec_set_values(win)
end)

vis.events.subscribe(vis.events.FILE_SAVE_POST, function()
  ec_set_values(vis.win)
end)

return M
