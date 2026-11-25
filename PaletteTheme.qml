pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: theme

    readonly property string mono: "monospace"
    readonly property string display: "sans-serif"
    readonly property bool light: settings.mode === "light"
    property alias mode: settings.mode
    property alias transition: settings.transition
    property alias wallpaper: settings.wallpaper
    property alias lastStaticWallpaper: settings.lastStaticWallpaper
    property alias videoFrame: settings.videoFrame
    readonly property string imageWallpaper: /\.(mp4|webm|mkv|mov)$/i.test(wallpaper) ? videoFrame : wallpaper
    readonly property var transitions: [
        { id: "none", label: "Instant" }, { id: "fade", label: "Fade" },
        { id: "wipe", label: "Wipe" }, { id: "grow", label: "Grow" }, { id: "wave", label: "Wave" }
    ]

    readonly property color seed: quantizer.colors.find(color => color.hslSaturation > 0.18) ?? "#79a488"
    readonly property real hue: seed.hslHue < 0 ? 0.39 : seed.hslHue
    readonly property color background: Qt.hsla(hue, 0.13, light ? 0.965 : 0.087, 1)
    readonly property color bar: Qt.hsla(hue, 0.13, light ? 0.95 : 0.068, 0.93)
    readonly property color foreground: Qt.hsla(hue, 0.15, light ? 0.13 : 0.94, 1)
    readonly property color muted: Qt.hsla(hue, 0.10, light ? 0.36 : 0.69, 1)
    readonly property color line: Qt.hsla(hue, 0.12, light ? 0.79 : 0.25, 1)
    readonly property color selection: Qt.hsla(hue, 0.20, light ? 0.88 : 0.18, 1)
    readonly property color accent: Qt.hsla(hue, 0.44, light ? 0.32 : 0.76, 1)
    signal preferencesLoaded()

    function cycleTransition(): void {
        const index = transitions.findIndex(option => option.id === settings.transition);
        settings.transition = transitions[(index + 1) % transitions.length].id;
    }

    function imageUrl(path: string): url {
        return path ? "file://" + path.split("/").map(part => encodeURIComponent(part)).join("/") : "";
    }

    FileView {
        path: Quickshell.stateDir + "/appearance.json"
        printErrors: false
        onLoaded: theme.preferencesLoaded()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property string mode: "dark"
            property string transition: "fade"
            property string wallpaper: ""
            property string lastStaticWallpaper: ""
            property string videoFrame: ""
        }
    }

    ColorQuantizer {
        id: quantizer
        source: theme.imageUrl(theme.imageWallpaper)
        rescaleSize: 96
        depth: 4
    }
}
