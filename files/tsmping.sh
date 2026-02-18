#!/bin/sh

INITFILE=/etc/init.d/tsmping
SERVICE_PID_FILE=/var/run/tsmping.pid
APP=$0

usage() {
    echo "Usage: $APP [ COMMAND ]"
    doexit
}
callinit() {
    [ -x $INITFILE ] || {
        echo "No init file '$INITFILE'"
        return
    }
    exec $INITFILE $1
    RETVAL=$?
}
run() {
    uci set tsmping.debug.enable='0'
    uci commit
    exec /usr/bin/lua /usr/lib/lua/tsmping/app.lua
    RETVAL=$?
}

debug() {
    /etc/init.d/tsmping stop

    uci set tsmping.debug.enable='1'
    uci commit

    echo "----------------------------"
    echo "|  Tsmping debug started   |"
    echo "----------------------------"

    exec /usr/bin/lua /usr/lib/lua/tsmping/app.lua
    RETVAL=$?
}

doexit() {
    exit $RETVAL
}

[ -n "$INCLUDE_ONLY" ] && return

CMD="$1"
[ -z $CMD ] && {
    run
    doexit
}
shift
# See how we were called.
case "$CMD" in
    start|stop|restart|reload)
        callinit $CMD
        ;;
    debug)
        debug
        ;;
    *)
        RETVAL=1
        usage $0
        ;;
esac

doexit
