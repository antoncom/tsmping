-- Модуль реализует поднятие события на шине UBUS

local ubus = require "ubus"
local util = require "luci.util"

local conn = ubus.connect()
local notifier = {}
notifier.ubus_methods = nil

function notifier:init(ubus_methods)
    notifier.ubus_methods = ubus_methods
end

function notifier:fire(ev_name, comm, res)
    local ev_body = {
        service = "Tsmping",
        command = comm,
        result = res,
        note = "Изменилось состояние Ping сети"

    }
	conn:notify(notifier.ubus_methods["tsmping"].__ubusobj, ev_name, ev_body)
end

return notifier
