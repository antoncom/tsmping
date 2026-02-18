local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local lock = require "tsmping.lock"
local timer = require "tsmping.timer"
local notifier = require "tsmping.notifier"

local if_debug = require("tsmping.util").if_debug


local signal = require("posix.signal")
signal.signal(signal.SIGINT, function(signum)

  io.write("\n")
  print("-----------------------")
  print("Tsmping debug stopped.")
  print("-----------------------")
  io.write("\n")
  os.exit(128 + signum)
end)

local conn = ubus.connect()

local ping = {}
ping.state = {
    ["value"] = "",
    ["command"] = "",
    ["updated"] = "",
    ["changed"] = "",
    ["comment"] = ""
}

function make_ubus()
	local ubus_methods = {
		["tsmping"] = {
            check = {
                function(req, msg)
                    local resp = ping.state
                    local owner = msg["owner"] or ""
                    if_debug("-----------------")
                    if_debug(string.format("ping state asked by [%s]: %s", owner, luci.jsonc.stringify(resp)))
                    if_debug("-----------------")
                    
                    conn:reply(req, resp);
                end, {}
            },
            update = {
                function(req, msg)
                    local resp = {}
                    if msg["host"] and msg["value"] then
                        local host   = tostring(msg["host"])
                        local value  = tostring(msg["value"])
                        local command = "ping " .. host
                        local owner = msg["owner"] or ""
                        local comment = owner

                        if value == "1" or value == "0" then
                            ping:update(value, command, comment)
                            resp = { status = "updated"}
                        else
                            resp = { msg = "Param [value] has to be 0 or 1. "}
                        end
                    else
                        resp = { msg = "[host], [value] are required params. Nothing was done." }
                    end

                    conn:reply(req, resp);
                end, { host = ubus.STRING, value = ubus.STRING, owner = ubus.STRING }
            },
        },
	}
	conn:add( ubus_methods )
    notifier:init(ubus_methods)
end


function ping:update(value, command, comment)

    local newval = value
    local oldval = ping.state.value

    local newcomm = command
    local oldcomm = ping.state.command

    -- время обновления всегда текущее
    -- время изменения - только если изменилось значение или команда

    if(newval == oldval and newcomm == oldcomm) then
        

        ping.state.updated = tostring(os.time())

    else

        ping.state.value = value
        ping.state.command = command
        ping.state.updated = tostring(os.time())
        ping.state.changed = tostring(os.time())
        ping.state.comment = comment

        if (newval ~= oldval) then
            notifier:fire("PING_CHANGED", command, newval)
        end
    end
    local owner = ping.state.comment
    if_debug(string.format("ping result updated by [%s]: %s", owner, luci.jsonc.stringify(ping.state)))

end



uloop.init()
make_ubus()
timer:start()
uloop.run()
