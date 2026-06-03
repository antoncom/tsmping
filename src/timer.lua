-- Модуль выпоняет периодический запуск срипта ./ping.sh

local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local uloop = require "uloop"
local if_debug = require("tsmping.util").if_debug


local timer = {}
timer.interval = 4000

-- [[ PING Google to check internet connection ]]
function do_ping()

    if_debug("-----------------------")
    if_debug("Do ping every " .. tostring(timer.interval) .. " sec.")

    function p1(r) --[[ call back is empty as not needed now. ]]   end

    local host = uci:get("tsmodem", "default", "ping_host") or '8.8.8.8'
    uloop.process("/usr/lib/lua/tsmping/ping.sh", {"--host", host }, {"PROCESS=1"}, p1)
    timer.ping:set(timer.interval)
end
timer.ping = uloop.timer(do_ping)

function timer:start()
    timer.ping:set(timer.interval)
end

return timer