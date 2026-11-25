#!/bin/sh

video=$1
target=$2
if [ -s "$target" ] && [ "$target" -nt "$video" ]; then
    printf '%s\n' "$target"
    exit 0
fi

mkdir -p -- "$(dirname "$target")" || exit 1
temp=$(mktemp --suffix=.jpg "$target.XXXXXX") || exit 1
trap 'rm -f -- "$temp"' EXIT
if ffmpeg -nostdin -v error -y -threads 1 -i "$video" -vf 'scale=320:-1:flags=fast_bilinear' -frames:v 1 -threads 1 "$temp" && [ -s "$temp" ]; then
    mv -f -- "$temp" "$target" || exit 1
    printf '%s\n' "$target"
else
    exit 1
fi
