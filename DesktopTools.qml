pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.services
import "KeybindDescriptions.js" as Keybinds

Scope {
    id: tools

    required property PaletteTheme theme
    readonly property string home: Quickshell.env("HOME")
    readonly property var wallpaperDirectories: {
        const directory = Quickshell.env("PRISM_WALLPAPER_DIR");
        return directory ? [directory] : [...new Set([home + "/wallpapers", Config.wallpaper.dir, Config.wallpaper.videoDir].filter(path => path))];
    }
    property var wallpapers: []
    property bool randomPending: false
    property string pendingWallpaper: ""
    property string applyingWallpaper: ""
    property var liveBindings: []
    readonly property bool wallpapersLoading: wallpaperScan.running
    readonly property bool playingWallpaper: videoPlayer.running

    readonly property var emojis: emojiFile.text().split("\n").filter(line => line).map(line => {
        const [emoji, name, category] = line.split("\t");
        return {
            title: emoji + "  " + name,
            searchTitle: name,
            detail: category ?? "",
            run: () => Quickshell.execDetached(["wl-copy", "--type", "text/plain;charset=utf-8", "--", emoji])
        };
    })

    readonly property var captureOptions: [
        { title: "Capture area", detail: "Select and review", run: () => tools.screenshot("region") },
        { title: "Capture window", detail: "Select and review", run: () => tools.screenshot("window") },
        { title: "Capture focused screen", detail: "Save PNG and copy", run: () => tools.screenshot("full") },
        { title: "Pick screen colour", detail: "Copy hex code", run: () => tools.pickColor() }
    ]

    readonly property var editOptions: Config.apps.editFolders.map(folder => ({
        title: "Edit " + (Utils.fileName(folder.replace(/\/+$/, "")) || folder),
        detail: folder === tools.home || folder.startsWith(tools.home + "/") ? "~" + folder.slice(tools.home.length) : folder,
        run: () => tools.editFolder(folder)
    })).concat([{ title: "Manage folders", detail: "Add or remove Quick Edit folders", run: () => Panels.show("edit") }])

    readonly property var paletteShortcuts: [
        { title: "Move selection", detail: "↑ / ↓ or Ctrl+K / Ctrl+J" },
        { title: "Select", detail: "Enter" },
        { title: "Cycle palette modes", detail: "Tab / Shift+Tab" },
        { title: "Jump to a palette mode", detail: "Ctrl+1 through Ctrl+5" },
        { title: "Clear search", detail: "Ctrl+U" },
        { title: "Close palette", detail: "Esc" },
        { title: "Apps, windows, workspaces, clipboard, commands", detail: "@  :  >  /" },
        { title: "Wallpapers and emoji from app search", detail: "w + Space / Ctrl+E" }
    ]
    readonly property var shortcuts: liveBindings.concat(paletteShortcuts)

    function refreshShortcuts(): void {
        if (!bindingReader.running)
            bindingReader.running = true;
    }

    function bindingLabel(binding: var): string {
        const parts = [];
        const modifiers = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"], [32, "Mod3"], [128, "Mod5"]];
        for (const [mask, label] of modifiers) {
            if (binding.modmask & mask)
                parts.push(label);
        }
        parts.push(binding.key || "Key " + binding.keycode);
        return parts.join(" + ");
    }

    function refreshWallpapers(pickRandom: bool): void {
        randomPending = randomPending || pickRandom;
        if (!wallpaperScan.running)
            wallpaperScan.running = true;
    }

    function setWallpaper(path: string): void {
        pendingWallpaper = path.startsWith("~/") ? home + path.slice(1) : path;
        applyPendingWallpaper();
    }

    function setThemeMode(mode: string): void {
        if (mode !== "dark" && mode !== "light")
            return;
        theme.mode = mode;
        Config.wallpaper.mode = mode;
        syncWallpaperColors();
    }

    function syncWallpaperColors(): void {
        const source = theme.imageWallpaper || Theme.matugenWallpaper;
        if (!source || !Config.wallpaper.syncApps)
            return;

        const command = ["matugen", "-m", theme.mode, "--source-color-index", String(Config.wallpaper.matugenIndex)];
        if (Config.wallpaper.scheme)
            command.push("-t", Config.wallpaper.scheme);
        Quickshell.execDetached([...command, "image", source]);
    }

    function isVideo(path: string): bool {
        return /\.(mp4|webm|mkv|mov)$/i.test(path);
    }

    function videoThumbnail(path: string): string {
        return Quickshell.cacheDir + "/video-wallpaper-" + Qt.md5(path) + ".jpg";
    }

    function stopLiveWallpaper(): void {
        videoPlayer.running = false;
        if (isVideo(theme.wallpaper)) {
            const still = theme.lastStaticWallpaper;
            theme.wallpaper = still;
            if (still)
                setWallpaper(still);
        }
    }

    function applyPendingWallpaper(): void {
        if (wallpaperSetter.running || !pendingWallpaper)
            return;

        if (videoPlayer.running) {
            videoPlayer.running = false;
            return;
        }

        applyingWallpaper = pendingWallpaper;
        pendingWallpaper = "";
        if (isVideo(applyingWallpaper)) {
            videoPlayer.exec(["mpvpaper", "-o", "no-audio --loop-playlist --hwdec=auto-safe", "ALL", applyingWallpaper]);
            return;
        }
        const transition = theme.transitions.some(option => option.id === theme.transition) ? theme.transition : "fade";
        wallpaperSetter.exec(["awww", "img", "--transition-type", transition,
            "--transition-duration", "0.28", "--transition-fps", "60", "--", applyingWallpaper]);
    }

    function screenshot(mode: string): void {
        Shot.capture(mode, "both", 0);
    }

    function pickColor(): void {
        Shot.pickColor();
    }

    function clock(): void {
        Chrono.toggle();
    }

    function editFolder(path: string): void {
        Quickshell.execDetached([Quickshell.env("PRISM_EDITOR") || Config.apps.editor, path]);
    }

    function power(action: string): void {
        if (action === "logout")
            Hyprland.dispatch("hl.dsp.exit()");
        else
            Quickshell.execDetached(["systemctl", action]);
    }

    Connections {
        target: tools.theme
        function onPreferencesLoaded() {
            if (tools.isVideo(tools.theme.wallpaper))
                tools.setWallpaper(tools.theme.wallpaper);
        }
    }

    FileView {
        id: emojiFile
        path: Quickshell.shellDir + "/scripts/emoji.tsv"
    }

    FileView {
        id: hyprConfig
        path: Config.paths.binds
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: hyprBinds
        path: Config.configHome + "/hypr/hyprconfigs/binds.lua"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: extraBinds
        path: Config.paths.extraBinds
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    Process {
        id: bindingReader
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector { id: bindingOutput }

        onExited: exitCode => {
            if (exitCode !== 0)
                return;

            try {
                const descriptions = Keybinds.fromSource(hyprConfig.text() + "\n" + hyprBinds.text() + "\n" + extraBinds.text());
                tools.liveBindings = JSON.parse(bindingOutput.text).map(binding => {
                    const detail = tools.bindingLabel(binding);
                    return { title: Keybinds.describe(binding, detail, descriptions), detail };
                });
            } catch (error) {
                console.warn("Could not read Hyprland bindings:", String(error));
                tools.liveBindings = [];
            }
        }
    }

    Process {
        id: wallpaperScan
        command: ["sh", "-c", `for directory do
            [ -d "$directory" ] || continue
            find -H "$directory" -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' \\) -print0
        done`, "prism-wallpapers", ...tools.wallpaperDirectories]
        stdout: StdioCollector { id: wallpaperOutput }

        onExited: {
            const paths = [...new Set(wallpaperOutput.text.split("\u0000").filter(path => path))];
            tools.wallpapers = paths.map(path => {
                const slash = path.lastIndexOf("/");
                return {
                    title: path.slice(slash + 1),
                    path,
                    video: tools.isVideo(path),
                    detail: path.slice(0, slash).replace(tools.home + "/", "~/"),
                    run: () => tools.setWallpaper(path)
                };
            }).sort((left, right) => left.title.localeCompare(right.title));

            if (tools.randomPending) {
                tools.randomPending = false;
                const images = tools.wallpapers.filter(entry => !entry.video);
                if (images.length)
                    images[Math.floor(Math.random() * images.length)].run();
                else
                    Quickshell.execDetached(["notify-send", "Wallpaper", "No images found in the wallpaper folders."]);
            }
        }
    }

    Timer {
        id: settleVideo
        interval: 500
        onTriggered: {
            if (!videoPlayer.running)
                return;
            tools.theme.wallpaper = tools.applyingWallpaper;
            const frame = tools.videoThumbnail(tools.applyingWallpaper);
            videoColor.exec(["sh", Config.shellDir + "/scripts/video-thumb.sh", tools.applyingWallpaper, frame]);
        }
    }

    Process {
        id: videoPlayer
        onStarted: settleVideo.restart()
        onExited: exitCode => {
            settleVideo.stop();
            if (tools.pendingWallpaper) {
                Qt.callLater(tools.applyPendingWallpaper);
            } else if (exitCode !== 0 && !tools.isVideo(tools.theme.wallpaper)) {
                Quickshell.execDetached(["notify-send", "Video wallpaper failed", "Check that mpvpaper is installed."]);
            }
        }
    }

    Process {
        id: videoColor
        stdout: StdioCollector { id: videoColorResult }
        onExited: exitCode => {
            const frame = videoColorResult.text.trim();
            if (exitCode === 0 && tools.isVideo(tools.theme.wallpaper) && frame === tools.videoThumbnail(tools.theme.wallpaper)) {
                tools.theme.videoFrame = frame;
                tools.syncWallpaperColors();
            }
        }
    }

    Process {
        id: wallpaperSetter
        stderr: StdioCollector { id: wallpaperError }

        onExited: exitCode => {
            if (exitCode === 0) {
                tools.theme.wallpaper = tools.applyingWallpaper;
                tools.theme.lastStaticWallpaper = tools.applyingWallpaper;
                tools.syncWallpaperColors();
            } else {
                const reason = wallpaperError.text.trim();
                Quickshell.execDetached(["notify-send", "Wallpaper change failed", reason || "Check that awww-daemon is running."]);
            }
            if (tools.pendingWallpaper)
                Qt.callLater(tools.applyPendingWallpaper);
        }
    }
}
