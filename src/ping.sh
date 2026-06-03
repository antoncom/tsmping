#!/bin/sh

# Исполнительный срипт.
# Пингует хост стандартной шелл-командой "ping".
# Результат отправляет на шину UBUS в сервис tsmping для раздачи другим сервисам-потребителям.

ping_host() {
    host=$1
    #host=mmm.com
    result=$(ping $host -c1 -A -w3 -W3 -q 2>/dev/null | awk -v HOST="$host" '{
        if(NF>6) {
            loss = $7; loss = substr($7, 0, length($7)-1);
            if(loss == "100") {
                print "0"
            } else {
                print "1"
            }
        }
    }')

    # If ping responds with any error then it's the same like host unreachable
    if [[ -z "$result" ]]; then
       result=0
    fi

    ubus call tsmping update '{"host":"'$host'","value":"'$result'"}' &> /dev/null

}

APP=$0
CMD=$1; shift
usage() {
    echo "Usage: $APP COMMAND [ OPTIONS ]"
    echo
    echo "Example:"
    echo "./ping.sh --host 8.8.8.8"
    echo "will run UBUS method: ubus call tsmping update '{\"host\":\"8.8.8.8\",\"value\":\"1\"}'"
    
}

case "$CMD" in
    help|-h|--help)
        usage
        exit 0
        ;;
    --host)
        ping_host $1
        ;;
    *)
        usage $APP
        exit 1
        ;;
esac
