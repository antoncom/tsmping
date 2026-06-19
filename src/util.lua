-- Модуль вспомогательных функций

local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local socket = require "socket"

local dbg = {}

dbg.if_debug = function(msg)
	local is_debug = (uci:get("tsmping", "debug", "enable") == "1")
	local val = ""

	if (is_debug) then
		if (msg and type(msg) == "table") then
			val = util.serialize_json(msg)
		elseif (msg and type(msg) == "string") then
			val = msg:gsub("%c", " ")
		else
			val = msg
		end
		local dt = os.date("*t")  
		local ms = string.match(tostring(os.clock()), "%d%.(%d+)")  
		local d = string.format("%d:%d:%d", dt.hour, dt.min, dt.sec)  

		local socket = require 'socket'  
		local now = socket.gettime()  
		local millis = math.floor((now % 1) * 100)  
		print(string.format('%s.%02d', d, millis) .. " [" .. dbg.filename() .. "]:" .. tostring(val))
	end
end

dbg.filename = function()
    -- уровень 1: сама функция get_caller_filename
    -- уровень 2: функция, которая вызвала get_caller_filename (например, my_print)
    -- уровень 3: функция, которая вызвала my_print (та, которая использует util.lua)
    local info = debug.getinfo(3, "S")
    local full_path = info.source:match("^@?(.+)$") or "unknown"
    -- Извлекаем только имя файла (после последнего / или \)
    local filename = full_path:match("([^/\\]+)$") or full_path
    return filename
end

return dbg