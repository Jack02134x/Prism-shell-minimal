pragma Singleton

import Quickshell
import qs.common

Singleton {
    property var controller: null
    readonly property bool light: controller?.theme.light ?? (Config.wallpaper.mode === "light")

    function apply(path: string): void {
        controller?.setWallpaper(path);
    }

    function random(): void {
        controller?.refreshWallpapers(true);
    }

    function setMode(mode: string): void {
        controller?.setThemeMode(mode);
    }

    function toggleMode(): void {
        setMode(light ? "dark" : "light");
    }
}
