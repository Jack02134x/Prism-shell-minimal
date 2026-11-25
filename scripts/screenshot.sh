#!/bin/sh

mode=$1
monitor=$2
runtime=${XDG_RUNTIME_DIR:-/tmp}

discard() {
    case "$1" in
        "$runtime"/prism-shot.??????)
            rm -f -- "$1/frame.png" "$1/crop.png"
            rmdir -- "$1"
            ;;
        *) return 1 ;;
    esac
}

destination() {
    folder="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
    mkdir -p -- "$folder" || return 1
    mktemp --suffix=.png "$folder/Screenshot-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX"
}

if [ "$mode" = freeze ]; then
    shot=$(mktemp -d "$runtime/prism-shot.XXXXXX") || exit 1
    if grim -o "$monitor" "$shot/frame.png"; then
        printf '%s\n' "$shot"
    else
        discard "$shot"
        notify-send 'Screenshot failed' 'Could not freeze the focused screen.'
        exit 1
    fi
    exit 0
fi

if [ "$mode" = discard ]; then
    discard "$2"
    exit $?
fi

if [ "$mode" = finalize ]; then
    shot=$2
    crop=$3
    action=$4
    case "$shot" in "$runtime"/prism-shot.??????) ;; *) exit 2 ;; esac
    trap 'discard "$shot"' EXIT
    image="$shot/frame.png"
    if [ -n "$crop" ]; then
        image="$shot/crop.png"
        if ! magick "$shot/frame.png" -crop "$crop" +repage "$image"; then
            notify-send 'Screenshot failed' 'Could not crop the frozen screen.'
            exit 1
        fi
    fi

    if [ "$action" != copy ]; then
        file=$(destination) || exit 1
        if ! cat -- "$image" > "$file"; then
            rm -f -- "$file"
            exit 1
        fi
        notify-send 'Screenshot saved' "$file"
    fi
    if [ "$action" != save ]; then
        wl-copy --type image/png < "$image"
        if [ "$action" = copy ]; then
            notify-send 'Screenshot copied'
        fi
    fi
    exit 0
fi

case "$mode" in
    region)
        geometry=$(slurp) || exit 0
        set -- -g "$geometry"
        ;;
    full)
        set --
        if [ -n "$monitor" ]; then
            set -- -o "$monitor"
        fi
        ;;
    *) exit 2 ;;
esac

image=$(destination) || exit 1

if ! grim "$@" "$image"; then
    rm -f -- "$image"
    notify-send 'Screenshot failed' 'grim could not capture the screen.'
    exit 1
fi

wl-copy --type image/png < "$image"
notify-send 'Screenshot saved' "$image"
