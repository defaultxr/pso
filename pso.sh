#!/bin/sh

trap "exit 0" TERM
export TOP_PID=$$

CONFIG_FILE="$HOME/.config/pso.config"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"


show_help(){
    echo "Pretty Straightforward file Opener"
    echo "Usage ./pso.sh [-h] [-d] file|uri"
    echo "-h : Show this help"
    echo "-d : Run in debug mode (dry run)"
}

exec_cmd(){
    exec_cmd=$(printf "$1" \""$2"\")
    eval $exec_cmd
    kill -s TERM $TOP_PID
}

try_regex(){
    grep "^[^#]" $1 |
    while IFS=: read -r cmd regex; do
        echo "$resource" | grep -E "$regex" > /dev/null
        if [ "$?" -eq 0 ]; then
            if [ "$debug" -eq 0 ]; then
                exec_cmd "$cmd" "$resource"
            fi
            [ "$debug" -eq 1 ] && echo "regex: $regex cmd: $cmd (from $1)"
        fi
    done
}


try_mime(){
    grep "^[^#]" "$1" |
    while IFS=: read -r cmd mime; do
        if [ "$mime" = "$resource_mime" ]; then
            if [ "$debug" -eq 0 ]; then
                exec_cmd "$cmd" "$resource"
            fi
            [ "$debug" -eq 1 ] && echo "mime: $mime cmd: $cmd (from $1)"
        fi
    done
}


ask(){
    if [ "$PSO_ASK_MENU" != "false" ]; then
        app=$(eval "$PSO_ASK_MENU")
        if [ "$app" != "" ]; then
            [ "$PSO_ASK_AUTOSAVE" != "false" ] && printf "$app %%s:$resource_mime\n" >> $PSO_MIME_CONFIG
            exec_cmd "$app %s" "$resource"
        fi
    fi
}


OPTIND=1

debug=0
while getopts "hd?:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    d)  debug=1
        ;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

resource=$@

echo "$resource" | grep -E "^file://" > /dev/null
[ $? -eq 0 ] && resource=$(echo "$resource" | sed 's#^file://##;s/+/ /g;s/%\(..\)/\\x\1/g;' | xargs -0 printf "%b")

if [ -f "$resource" ]; then
    resource_mime=$(file -b --mime-type "$resource")
    try_regex "$PSO_REGEX_CONFIG"
    try_mime "$PSO_MIME_CONFIG"
    ask
else
    try_regex "$PSO_URI_CONFIG"
    notify-send "Cant open the URI, configure a regex in $PSO_URI_CONFIG"
fi