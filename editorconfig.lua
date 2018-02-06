require "vis"
ec = require "editorconfig_core"

-- Simple wrapper
function vis_set(option, value)
  if type(value) == "boolean" then
    if value then
      value = "yes"
    else
      value = "no"
    end
  end

  vis:command("set " .. option .. " " .. value)
end

OPTIONS = {
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

  -- Not supported by vis
  --   end_of_line
  --   charset
  --   trim_trailing_whitespace
  --   insert_final_newline
  --   max_line_length
}

-- Uses editorconfig-core-lua's as yet unreleased iterator API
--function ec_iter(p) do
--  return ec.open(p)
--end

-- Compatible with editorconfig-core-lua v0.1.1
function ec_iter(p)
  i = 0
  props, keys = ec.parse(p)
  n = #keys
  return function ()
    i = i + 1
    if i <= n then
      return keys[i], props[keys[i]]
    end
  end
end

function ec_set_values(path)
  if path then
    for name, value in ec_iter(path) do
      if OPTIONS[name] then
        OPTIONS[name](value)
      end
    end
  end
end

function ec_parse_cmd() ec_set_values(vis.win.file.path) end
vis:command_register("econfig_parse", ec_parse_cmd, "(Re)parse an editorconfig file")

vis.events.subscribe(vis.events.FILE_OPEN, function (file)
  ec_set_values(file.path)
end)

vis.events.subscribe(vis.events.FILE_SAVE_POST, function (file, path)
  ec_set_values(path)
end)
