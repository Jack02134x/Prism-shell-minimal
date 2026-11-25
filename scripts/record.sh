#!/bin/sh

mode=$1
file=$2
output=$3
audio=$4
selector=
capture=
geometry_file=

cleanup() {
    if [ -n "$geometry_file" ]; then
        rm -f -- "$geometry_file"
    fi
}

stop() {
    if [ -n "$capture" ]; then
        kill -INT "$capture" 2>/dev/null
        wait "$capture"
        exit $?
    fi
    if [ -n "$selector" ]; then
        kill -TERM "$selector" 2>/dev/null
        wait "$selector" 2>/dev/null
    fi
    exit 2
}
trap cleanup EXIT
trap stop INT TERM

mkdir -p -- "$(dirname "$file")" || exit 1
sleep 0.15
set --
case "$mode" in
    region)
        geometry_file=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/prism-record.XXXXXX") || exit 1
        slurp > "$geometry_file" &
        selector=$!
        wait "$selector" || exit 2
        selector=
        read -r geometry < "$geometry_file" || exit 2
        set -- -g "$geometry"
        ;;
    window)
        geometry=$(hyprctl -j activewindow | jq -er 'select(.at and .size) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') || exit 2
        set -- -g "$geometry"
        ;;
    full)
        if [ -n "$output" ]; then
            set -- -o "$output"
        fi
        ;;
    *) exit 1 ;;
esac

if [ "$audio" = audio ]; then
    set -- "$@" --audio
fi

printf '%s\n' PRISM_RECORD_STARTED
wf-recorder "$@" -f "$file" &
capture=$!
wait "$capture"
