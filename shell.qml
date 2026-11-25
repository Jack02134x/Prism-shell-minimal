//@ pragma UseQApplication
//@ pragma IconTheme breeze-dark

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services
import qs.widgets
import qs.modules.bar
import qs.modules.clock
import qs.modules.corners
import qs.modules.drawers
import qs.modules.edit
import qs.modules.launcher
import qs.modules.lock
import qs.modules.overview
import qs.modules.polkit
import qs.modules.power
import qs.modules.screenshot
import qs.modules.switcher

ShellRoot {
    id: root

    property bool showBar: true

    // The original panels share one palette and open on demand.
    CoreIpc {}

    LazyLoader {
        active: root.showBar && Config.bar.classic
        Variants { model: Quickshell.screens; Bar {} }
    }
    LazyLoader {
        active: root.showBar && Config.bar.classic
        Variants { model: Quickshell.screens; FullscreenIsland {} }
    }
    Variants { model: Quickshell.screens; Drawers {} }
    LazyLoader {
        active: Config.fx.corners || Config.fx.hotCorner
        Variants { model: Quickshell.screens; Corners {} }
    }

    LazyPanel { want: Panels.launcher; Launcher {} }
    LazyPanel { want: Panels.preferences; PreferencesPopup {} }
    LazyPanel { want: Panels.calendar; CalendarPopup {} }
    LazyPanel { want: Panels.overview; Overview {} }
    LazyPanel { want: Panels.record; RecordMenu {} }
    LazyPanel { want: Panels.edit; QuickEdit {} }
    LazyPanel { want: Panels.switcher; Switcher {} }
    LazyPanel { want: Panels.power; PowerMenu {} }
    LazyPanel { want: Chrono.open; ClockWindow {} }
    LazyPanel { want: Chrono.ringing !== null; RingCard {} }
    Lock {}
    CompactOsd { enabled: (!root.showBar || !Config.bar.classic) && !capture.open }

    LazyLoader {
        active: Config.polkit.enabled
        PolkitDialog {}
    }

    FileView {
        id: localEntry
        path: Quickshell.shellDir + "/local/Local.qml"
        printErrors: false
        property bool exists: false
        onLoaded: exists = true
        onLoadFailed: exists = false
    }
    LazyLoader {
        active: localEntry.exists
        source: localEntry.exists ? Quickshell.shellDir + "/local/Local.qml" : ""
    }

    Process {
        command: ["mkdir", "-p", Config.stateDir, Config.cacheDir]
        running: true
    }

    Component.onCompleted: {
        Theme.compact = appearance;
        Wallpapers.controller = desktopTools;
        Chrono.loaded;
        Breaks.enabled;
        Focus.active;
        Idle.active;
    }

    Connections {
        target: Panels
        function onAnyOpenChanged() {
            if (Panels.anyOpen)
                palette.open = false;
        }
        function onWallpaperRequested(query) {
            palette.showSearch("wallpapers", query);
        }
        function onCheatsheetRequested() { palette.showMode("shortcuts"); }
    }

    Connections {
        target: Shot
        function onRequested(mode, action, delay) {
            palette.open = false;
            Panels.closeAll();
            if (mode === "color")
                capture.color();
            else
                capture.begin(mode, action, delay);
        }
        function onCancelled() { capture.cancel(); }
    }

    PaletteTheme { id: appearance }
    DesktopTools {
        id: desktopTools
        theme: appearance
    }

    ScreenshotSession { id: capture }
    Binding {
        target: Panels
        property: "capturing"
        value: capture.open || capture.pending || capture.pickingColor || Toggles.recordSelecting
    }

    ScreenshotOverlay {
        theme: appearance
        session: capture
    }

    IpcHandler {
        target: "theme"
        function toggle(): void { Wallpapers.toggleMode(); }
        function light(): void { Wallpapers.setMode("light"); }
        function dark(): void { Wallpapers.setMode("dark"); }
    }

    Variants {
        model: Quickshell.screens

        StatusBar {
            required property ShellScreen modelData

            output: modelData
            visible: root.showBar && !Config.bar.classic
            theme: appearance
            onLauncherRequested: palette.toggleMode("apps")
        }
    }

    CommandPalette {
        id: palette

        theme: appearance
        desktop: desktopTools
        onBarToggleRequested: root.showBar = !root.showBar
        onVisibleChanged: if (visible) Panels.closeAll()
        onNativeQueryRequested: query => {
            palette.open = false;
            Panels.openLauncher(query);
        }
    }

    IpcHandler {
        target: "minimal"

        function openMode(mode: string): bool { return palette.showMode(mode); }
        function hide(): void { palette.open = false; }
        function toggleBar(): void { root.showBar = !root.showBar; }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (Panels.launcher)
                Panels.launcher = false;
            else
                palette.toggleMode("apps");
        }
        function open(): void { palette.showMode("apps"); }
        function close(): void {
            palette.open = false;
            Panels.launcher = false;
        }
        function search(query: string): void { Panels.openLauncher(query); }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (Panels.launcher && Panels.launcherQuery === ">")
                Panels.launcher = false;
            else
                Panels.openLauncher(">");
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { palette.toggleMode("wallpapers"); }
        function random(): void { desktopTools.refreshWallpapers(true); }
        function set(path: string): void { desktopTools.setWallpaper(path); }
        function stop(): void { desktopTools.stopLiveWallpaper(); }
    }

    IpcHandler {
        target: "screenshot"
        function menu(): void {
            if (capture.open || capture.pending)
                capture.cancel();
            else
                desktopTools.screenshot("region");
        }
        function region(): void { desktopTools.screenshot("region"); }
        function window(): void { desktopTools.screenshot("window"); }
        function full(): void { desktopTools.screenshot("full"); }
        function color(): void {
            palette.open = false;
            Panels.closeAll();
            capture.color();
        }
        function cancel(): void { capture.cancel(); }
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { palette.toggleMode("shortcuts"); }
    }

    IpcHandler {
        target: "emoji"
        function toggle(): void { palette.toggleMode("emoji"); }
    }

}
