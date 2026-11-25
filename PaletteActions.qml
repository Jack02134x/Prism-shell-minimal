pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.services

Scope {
    id: root

    required property DesktopTools desktop
    property bool clipboardActive: false
    property var clipboardEntries: []
    property var recentWindows: []
    readonly property bool clipboardLoading: clipboardList.running

    signal barToggleRequested()

    readonly property var apps: DesktopEntries.applications.values
        .filter(entry => !entry.noDisplay && entry.name)
        .map(entry => ({ title: entry.name, detail: entry.genericName === entry.name ? "" : entry.genericName, run: () => entry?.execute() }))
        .sort((left, right) => left.title.localeCompare(right.title));

    readonly property var commands: [
        { title: "Open terminal", detail: "Terminal emulator", run: () => Quickshell.execDetached([Quickshell.env("TERMINAL") || Config.apps.terminal]) },
        { title: "Open files", detail: "Home folder", run: () => Quickshell.execDetached(["xdg-open", Quickshell.env("HOME")]) },
        { title: "Wallpapers", detail: "Browse images and videos", mode: "wallpapers" },
        { title: "Random wallpaper", detail: "Pick any image", run: () => root.desktop.refreshWallpapers(true) },
        { title: "Stop live wallpaper", detail: "Return to the last still image", run: () => root.desktop.stopLiveWallpaper() },
        { title: "Screenshots", detail: "Area, screen or colour picker", mode: "captures" },
        { title: "Calendar", detail: "Browse months", run: () => Panels.toggleCalendar() },
        { title: "Clock", detail: "Alarms, timer and stopwatch", run: () => root.desktop.clock() },
        { title: "Emoji", detail: "Search and copy", mode: "emoji" },
        { title: "Quick edit", detail: "Open or manage editor folders", mode: "edit" },
        { title: "Keyboard shortcuts", detail: "Palette keys", mode: "shortcuts" },
        { title: "Power", detail: "Session actions", run: () => Panels.show("power") },
        { title: "Recording controls", detail: "Record area, window or screen", run: () => Panels.show("record") },
        { title: "Lock screen", detail: "Hyprlock", run: () => root.lockScreen() },
        { title: "Toggle bar", detail: "Show or hide the status bar", run: () => root.barToggleRequested() },
        { title: "Volume up", detail: "Raise output volume by 5%", run: () => root.volumeUp() },
        { title: "Volume down", detail: "Lower output volume by 5%", run: () => root.volumeDown() },
        { title: "Toggle mute", detail: "Audio output", run: () => root.toggleMute() }
    ].concat(Actions.list.filter(action => !["Wallpapers", "Random Wallpaper", "Clock", "Keybind Cheatsheet", "Quick Edit", "Lock", "Suspend"].includes(action.name))
        .map(action => ({ title: action.name, detail: action.desc, keywords: action.kw, run: action.run })))

    readonly property var powerOptions: [
        { title: "Lock screen", detail: "Hyprlock", run: () => root.lockScreen() },
        { title: "Suspend", detail: "Sleep", confirm: true, run: () => root.desktop.power("suspend") },
        { title: "Log out", detail: "Exit Hyprland", confirm: true, run: () => root.desktop.power("logout") },
        { title: "Restart", detail: "Reboot the computer", confirm: true, run: () => root.desktop.power("reboot") },
        { title: "Shut down", detail: "Power off", confirm: true, run: () => root.desktop.power("poweroff") }
    ]

    function lockScreen(): void {
        Session.lock();
    }

    function volumeUp(): void {
        Audio.nudge(0.05);
    }

    function volumeDown(): void {
        Audio.nudge(-0.05);
    }

    function toggleMute(): void {
        Audio.toggleMute();
    }

    function rememberWindow(): void {
        const address = Hyprland.activeToplevel?.address;
        if (address)
            recentWindows = [address, ...recentWindows.filter(previous => previous !== address)].slice(0, 100);
    }

    function windows(): var {
        // With an empty query, Enter should go to the previous window.
        const [active, ...previous] = recentWindows;
        const recent = new Map(previous.map((address, index) => [address, index]));

        return Hyprland.toplevels.values.filter(window => window.address)
            .map(window => {
                const address = window.address;
                const selector = "address:" + (address.startsWith("0x") ? address : "0x" + address);
                const app = window.wayland?.appId || window.lastIpcObject?.class || "Window";
                const workspace = window.workspace?.name;
                const detail = workspace ? app + " · " + workspace : app;
                return {
                    title: window.title || app,
                    detail: address === active ? detail + " · Current" : detail,
                    order: address === active ? Infinity : (recent.get(address) ?? recent.size),
                    run: () => Hyprland.dispatch(`hl.dsp.focus({ window = ${JSON.stringify(selector)} })`)
                };
            }).sort((left, right) => left.order - right.order || left.title.localeCompare(right.title));
    }

    function numberedWorkspace(id: int): void {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    function workspaces(query: string): var {
        const entries = Hyprland.workspaces.values.map(workspace => {
            const name = workspace.name;
            const special = name === "special" || name.startsWith("special:");
            const number = workspace.id;
            const count = workspace.toplevels.values.length;
            const detail = workspace.focused ? "Current workspace" : count + (count === 1 ? " window" : " windows");
            return {
                title: name,
                detail,
                number,
                run: () => {
                    if (special)
                        Hyprland.dispatch(`hl.dsp.workspace.toggle_special(${JSON.stringify(name.slice(8))})`);
                    else if (number > 0)
                        root.numberedWorkspace(number);
                    else
                        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify("name:" + name)} })`);
                }
            };
        });

        const trimmed = query.trim();
        const number = Number(trimmed);
        if (/^[1-9][0-9]*$/.test(trimmed) && number <= 2147483647 && !entries.some(entry => entry.number === number)) {
            entries.push({ title: trimmed, detail: "New workspace", number, run: () => root.numberedWorkspace(number) });
        }

        return entries.sort((left, right) => {
            const leftNumber = left.number > 0 ? left.number : Infinity;
            const rightNumber = right.number > 0 ? right.number : Infinity;
            return leftNumber - rightNumber || left.title.localeCompare(right.title);
        });
    }

    onClipboardActiveChanged: {
        if (clipboardActive && !clipboardList.running)
            clipboardList.running = true;
        else if (!clipboardActive)
            clipboardEntries = [];
    }

    Component.onCompleted: rememberWindow()

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { root.rememberWindow(); }
    }

    Process {
        id: clipboardList
        command: ["cliphist", "list"]
        stdout: StdioCollector { id: clipboardOutput }

        onExited: exitCode => {
            if (!root.clipboardActive || exitCode !== 0)
                return;

            const items = [];
            for (const line of clipboardOutput.text.split("\n")) {
                const match = /^(\d+)\t(.+)$/.exec(line);
                if (match) {
                    const [, id, preview] = match;
                    items.push({
                        title: preview,
                        detail: "",
                        run: () => Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "prism-clipboard", id])
                    });
                }
            }
            root.clipboardEntries = items;
        }
    }
}
