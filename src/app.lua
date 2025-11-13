local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local lock = require "tsmping.lock"
local timer = require "tsmping.timer"
local notifier = require "tsmping.notifier"

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
    ["command"] = "",
    ["value"] = "",
    ["time"] = "",
    ["unread"] = "",
    ["comment"] = ""
}

function make_ubus()
	local ubus_methods = {
		["tsmping"] = {
            check = {
                function(req, msg)
                    local resp = ping.state
                    resp.unread = "false"
                    conn:reply(req, resp);

                end, {}
            },
            update = {
                function(req, msg)
                    local resp = {}
                    if msg["host"] and msg["value"] then
                        local host   = msg["host"]
                        local value  = msg["value"]
                        local command = "ping " .. host
                        local comment = ""
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
    local newval = tostring(value)
    local oldval = ping.state.value

    if(oldval ~= newval) then
        local item = {
            ["command"] = command,
            ["value"] = newval,
            ["time"] = tostring(os.time()),
            ["unread"] = "true",
            ["comment"] = comment
        }
        ping.state = util.clone(item)
        notifier:fire("PING_CHANGED", command, newval)
    
    --[[ IF NOTHING CHANGED THEN UPDATE ONLY TIME ]]
    elseif value == "1" then
        ping.state.time = tostring(os.time())
    end
end



uloop.init()
make_ubus()
timer:start()
uloop.run()
