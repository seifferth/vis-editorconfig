local source_str = debug.getinfo(1, 'S').source:sub(2)
local script_path = source_str:match('(.*/)')

return dofile(script_path .. 'edconf.lua')
