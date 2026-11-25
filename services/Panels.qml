pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which popup panel is open. Opening one closes the others.
Singleton {
    id: root

    property bool launcher: false
    property string launcherQuery: ""
    property bool preferences: false
    property string preferencesTab: "settings"
    property bool calendar: false
    property var popupScreen: null
    property bool controls: false
    property bool power: false
    property bool overview: false
    property bool record: false
    property bool edit: false
    property bool switcher: false
    property string switcherFrom: ""
    // true while hyprpicker runs: every Prism surface hides instantly
    property bool capturing: false
    signal wallpaperRequested(string query)
    signal clipboardRequested(string query)
    signal cheatsheetRequested()

    readonly property var names: ["launcher", "preferences", "calendar", "controls", "power", "overview", "record", "edit", "switcher"]
    readonly property bool anyOpen: launcher || preferences || calendar || controls || power || overview || record || edit || switcher

    readonly property var focusedScreen: {
        const name = Hyprland.focusedMonitor?.name ?? "";
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    function closeAll(except) {
        for (const k of names)
            if (k !== except)
                root[k] = false;
    }

    function toggle(name) {
        const v = !root[name];
        // a plain toggle opens the launcher empty, not with the last prefix (":" ">")
        if (name === "launcher" && v)
            launcherQuery = "";
        if (name === "switcher" && v)
            switcherFrom = Hypr.addr(Hypr.activeWindow);
        closeAll(name);
        root[name] = v;
    }

    function show(name) {
        if (name === "switcher" && !switcher)
            switcherFrom = Hypr.addr(Hypr.activeWindow);
        closeAll(name);
        root[name] = true;
    }

    function openLauncher(query) {
        if (query && query.startsWith(">")) {
            closeAll();
            clipboardRequested(query.slice(1).trim());
            return;
        }
        launcherQuery = query ?? "";
        if (launcher && query !== undefined) {
            // re-trigger the query even if already open
            launcher = false;
        }
        show("launcher");
    }

    function openPreferences(tab, screen) {
        preferencesTab = ["settings", "network", "audio"].includes(tab) ? tab : "settings";
        popupScreen = screen ?? focusedScreen;
        show("preferences");
    }

    function togglePreferences(tab, screen) {
        const target = screen ?? focusedScreen;
        if (preferences && (!tab || preferencesTab === tab) && popupScreen === target)
            preferences = false;
        else
            openPreferences(tab, target);
    }

    function toggleCalendar(screen) {
        const target = screen ?? focusedScreen;
        if (calendar && popupScreen === target) {
            calendar = false;
        } else {
            popupScreen = target;
            show("calendar");
        }
    }

    function openWallpapers(query) {
        closeAll();
        wallpaperRequested(query ?? "");
    }

    function openCheatsheet() {
        closeAll();
        cheatsheetRequested();
    }
}
