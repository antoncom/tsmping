-- Серсис Tsmping предназначен для периодической проверки соединения с удалённым хостом
---====================================================================================
-- Сервис запускает шелл-команду "ping" и предоставляет на шине UBUS состояние пинга сети.

-- Взаимодействие с другими сервисами
---==================================
-- Сервис Tsmping служит исполнительным механизмом для сервиса Applogic (applicaion logic rules).
-- Applogic содержит "Правило переключения слотов Сим-карт при отсутствии PING сети",
-- используя данные сервиса Tsmping для принятия решеня.

local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local timer = require "tsmping.timer"
local notifier = require "tsmping.notifier"

local if_debug = require("tsmping.util").if_debug


local signal = require("posix.signal")
signal.signal(signal.SIGINT, function(signum)

  io.write("\n")
  print("[app.lua] -----------------------")
  print("[app.lua] Tsmping debug stopped.")
  print("[app.lua] -----------------------")
  io.write("\n")
  os.exit(128 + signum)
end)

local conn = ubus.connect()

local ping = {}

-- Сервис предоставляет на шине UBUS состояние пинга сети.
-- Поэтому данной таблице оно хранится и обновляется.

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

            -- Метод check - для потребителей: то есть выдает по шине UBUS состояние пинга сети

            check = {
                function(req, msg)
                    local resp = ping.state
                    local owner = msg["owner"] or ""
                    if_debug("[[[ CHECK ]]] ")
                    if_debug(string.format("ping state asked by [%s]: %s", owner, luci.jsonc.stringify(resp)))
                    
                    conn:reply(req, resp);
                end, {}
            },

            -- Метод update - для загрузки на шину данных, полученных от выполнения шел-команды "ping"
            -- Сама шелл-команда выполняется в срипте ./ping.sh. После её выполнения
            -- ping.sh делает вызов вида "ubus call tsmping update.." который и выполняет этот метод:

            update = {
                function(req, msg)
                    local resp = {}
                    if_debug("[[[ UPDATE ]]] ")
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
                    
                    if_debug(resp)

                    conn:reply(req, resp);
                end, { host = ubus.STRING, value = ubus.STRING, owner = ubus.STRING }
            },
        },
	}
	conn:add( ubus_methods )
    notifier:init(ubus_methods)
end


-- Вспомогательная функция, которая обновляет состояние пинга в таблице ping.state
-- Кроме того в этой функции поднимается событие "PING_CHANGED" на шине UBUS.

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
