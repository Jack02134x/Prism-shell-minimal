#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'HELP'
Install Minimalistic Prism from this checkout.

Usage: ./install.sh [--packages] [--replace] [--dry-run]
  --packages   Install the shell and desktop utilities with pacman (Arch Linux).
  --replace    Back up an existing Quickshell directory and keep its local settings.
  --dry-run    Show the installation plan.
  -h, --help   Show this help.
HELP
}

fail() { printf '%s\n' "$*" >&2; exit 1; }

packages=false
replace=false
dry_run=false
for arg in "$@"; do
    case "$arg" in
        --packages) packages=true ;;
        --replace) replace=true ;;
        --dry-run|-n) dry_run=true ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $arg" ;;
    esac
done

((EUID != 0)) || fail "Run this installer as your regular desktop user."
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
destination="$config_home/quickshell"
installed=false
[[ -f "$source_dir/shell.qml" && -f "$source_dir/hypr/minimal-binds.lua" ]] ||
    fail "Run this installer from a complete Minimalistic Prism checkout."

if [[ -d "$destination" && "$source_dir" -ef "$destination" ]]; then
    installed=true
elif [[ -L "$destination" || ( -e "$destination" && ! -d "$destination" ) ]]; then
    fail "Choose a different XDG_CONFIG_HOME or move the existing path at $destination."
elif [[ -d "$destination" ]] && ! "$replace"; then
    fail "A Quickshell config already exists at $destination. Use --replace to back it up and install."
fi

arch_packages=(
    hyprland quickshell qt6-wayland qt6-svg qt6-imageformats
    awww hyprlock wl-clipboard cliphist grim imagemagick hyprpicker
    wf-recorder ffmpeg brightnessctl libnotify curl
    pipewire wireplumber networkmanager bluez upower
    kitty thunar ttf-nerd-fonts-symbols ttf-jetbrains-mono-nerd
    noto-fonts noto-fonts-emoji breeze-icons
)

if "$packages"; then
    if "$dry_run"; then
        printf 'Would run sudo pacman -S --needed %s\n' "${arch_packages[*]}"
    else
        command -v pacman >/dev/null || fail "--packages requires Arch Linux or a compatible pacman repository."
        sudo pacman -S --needed "${arch_packages[@]}"
    fi
fi

if "$installed"; then
    printf 'Shell files are already in %s\n' "$destination"
elif "$dry_run"; then
    printf 'Would install shell files in %s\n' "$destination"
    if [[ -d "$destination" ]]; then
        printf 'Would back up the existing directory and carry over config.json, .state, and local.\n'
    fi
else
    mkdir -p -- "$config_home"
    staging=$(mktemp -d "$config_home/.minimalistic-prism.XXXXXX")
    backup=""
    trap 'if [[ -n $backup && ! -e $destination ]]; then mv -T -- "$backup/quickshell" "$destination"; fi; rm -rf -- "$staging"' EXIT

    # Copy only distribution files. A checkout can also be someone's live config.
    cp -a -- "$source_dir"/*.qml "$source_dir"/Search.js "$source_dir"/KeybindDescriptions.js \
        "$source_dir"/{common,docs,hypr,matugen,modules,scripts,services,shaders,widgets} \
        "$source_dir"/{.gitignore,README.md,action_commands.md,install.sh} "$staging/"

    if [[ -d "$destination" ]]; then
        for entry in config.json .state local; do
            if [[ -e "$destination/$entry" || -L "$destination/$entry" ]]; then
                cp -a -- "$destination/$entry" "$staging/"
            fi
        done
        backup=$(mktemp -d "$config_home/quickshell.bak-XXXXXX")
        mv -T -- "$destination" "$backup/quickshell"
    fi

    mv -T -- "$staging" "$destination"
    printf 'Installed Minimalistic Prism in %s\n' "$destination"
    if [[ -n "$backup" ]]; then
        printf 'Previous configuration saved in %s/quickshell\n' "$backup"
    fi
fi

printf '\nStart the shell with qs --no-duplicate.\n'
printf 'See %s/README.md for Hyprland autostart, keybindings, and optional tools.\n' "$destination"
