pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.services
import qs.modules.bar

PanelWindow {
    id: bar

    required property PaletteTheme theme
    required property ShellScreen output
    signal launcherRequested()

    readonly property HyprlandMonitor monitor: Hyprland.monitors.values.find(monitor => monitor.name === bar.output.name) ?? null
    readonly property var workspaces: Hyprland.workspaces.values.filter(workspace =>
        bar.monitor !== null && workspace.monitor === bar.monitor
        && (workspace.active || workspace.toplevels.values.length > 0))
    readonly property HyprlandToplevel focusedWindow: Hyprland.activeToplevel
    readonly property bool roomForLabels: width >= 1140

    color: theme.bar
    screen: output
    implicitHeight: Config.barExtent
    exclusiveZone: implicitHeight
    anchors { top: true; left: true; right: true }
    WlrLayershell.namespace: "prism-minimal-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    IdleInhibitor {
        window: bar
        enabled: Toggles.caffeine && bar.visible
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    TrayMenu { id: trayMenu }

    RowLayout {
        x: 6 * Config.uiScale
        width: parent.width / Config.uiScale - 12
        height: parent.height / Config.uiScale
        scale: Config.uiScale
        transformOrigin: Item.TopLeft
        spacing: 3

        BarChip {
            theme: bar.theme
            glyph: "apps"
            hint: "Application launcher"
            onClicked: button => {
                if (button === Qt.RightButton)
                    Panels.toggle("overview");
                else
                    bar.launcherRequested();
            }
        }

        Row {
            Layout.maximumWidth: Math.max(75, bar.width * 0.25)
            Layout.alignment: Qt.AlignVCenter
            spacing: 3
            clip: true

            Repeater {
                model: bar.workspaces
                BarChip {
                    id: workspace
                    required property HyprlandWorkspace modelData
                    readonly property string workspaceName: modelData?.name ?? ""
                    theme: bar.theme
                    visible: modelData !== null
                    text: workspaceName.replace(/^special(?::|$)/, "~")
                    selected: Boolean(modelData?.active || modelData?.urgent)
                    hint: modelData ? "Workspace " + workspaceName + " · " + modelData.toplevels.values.length + " windows" : ""
                    onClicked: {
                        if (workspaceName === "special" || workspaceName.startsWith("special:"))
                            Hypr.toggleSpecial(workspaceName.slice(8));
                        else if (modelData)
                            Hypr.focusWorkspace(modelData.id > 0 ? modelData.id : "name:" + workspaceName);
                    }
                }
            }
        }

        BarChip {
            theme: bar.theme
            Layout.maximumWidth: Math.max(0, bar.width * 0.22)
            textLimit: Math.max(0, bar.width * 0.22 - 12)
            visible: Config.bar.showTitle && Boolean(text)
            text: bar.focusedWindow?.monitor === bar.monitor ? (bar.focusedWindow?.title ?? "") : ""
            hint: text + "\nClick to switch windows"
            subdued: true
            onClicked: Panels.toggle("switcher")
        }

        Item { Layout.fillWidth: true }

        BarChip {
            theme: bar.theme
            visible: Config.bar.showStats && bar.width >= 960
            text: "CPU " + Math.round(SysStats.cpu * 100) + "%  RAM " + Math.round(SysStats.mem * 100) + "%"
                + (SysStats.cpuTemp > 0 && bar.roomForLabels ? "  " + Math.round(SysStats.cpuTemp) + "°" : "")
            hint: "Memory " + Utils.bytes(SysStats.memUsed) + " / " + Utils.bytes(SysStats.memTotal)
                + "\nDown " + Utils.rate(SysStats.netDown) + "  Up " + Utils.rate(SysStats.netUp) + " · Uptime " + Utils.human(SysStats.uptime)
            onClicked: Panels.toggle("controls")
        }

        BarChip {
            theme: bar.theme
            visible: Toggles.recording || Focus.active || Chrono.timerRunning
            glyph: Toggles.recording ? "record_rec" : "timer_outline"
            text: Toggles.recording ? "REC" : Focus.active ? Focus.leftText : Chrono.untilText(Chrono.timerLeft)
            hint: Toggles.recording ? "Recording · click for controls" : Focus.active ? "Focus timer · click for controls" : "Open timer"
            onClicked: {
                if (Toggles.recording)
                    Panels.toggle("record");
                else if (Focus.active)
                    Panels.toggle("controls");
                else
                    Chrono.show("timer");
            }
        }

        Tray { menu: trayMenu }

        BarChip {
            theme: bar.theme
            glyph: Net.icon
            textLimit: 95
            text: bar.roomForLabels ? (Net.connected ? Net.name : Net.wifiEnabled ? "Offline" : "Wi-Fi off") : ""
            hint: Net.name + (Net.active ? " · " + Math.round(Net.strength * 100) + "% signal" : "") + "\nClick for network settings"
            subdued: !Net.connected
            selected: Panels.preferences && Panels.preferencesTab === "network" && Panels.popupScreen === bar.output
            onClicked: Panels.togglePreferences("network", bar.output)
        }

        BarChip {
            theme: bar.theme
            glyph: BT.icon
            textLimit: 90
            text: bar.roomForLabels ? (BT.available ? BT.summary : "—") : ""
            hint: (BT.available ? "Bluetooth · " + BT.summary : "No Bluetooth adapter") + "\nClick for Bluetooth settings"
            subdued: !BT.enabled
            onClicked: Panels.togglePreferences("network", bar.output)
        }

        BarChip {
            theme: bar.theme
            glyph: Audio.icon
            text: Audio.ready ? Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%" : "—"
            hint: (Audio.ready ? Audio.nodeName(Audio.sink) : "No audio output") + "\nClick for Audio · Scroll volume · Right-click mute"
            subdued: Audio.muted || !Audio.ready
            selected: Panels.preferences && Panels.preferencesTab === "audio" && Panels.popupScreen === bar.output
            onClicked: button => button === Qt.RightButton ? Audio.toggleMute() : Panels.togglePreferences("audio", bar.output)
            onStepped: direction => Audio.nudge(direction * 0.05)
        }

        BarChip {
            theme: bar.theme
            visible: Audio.source !== null || bar.roomForLabels
            glyph: Audio.micIcon
            text: Audio.source && bar.roomForLabels ? (Audio.micMuted ? "Off" : Math.round(Audio.micVolume * 100) + "%") : ""
            hint: (Audio.source ? Audio.nodeName(Audio.source) : "No microphone") + "\nClick for Audio · Right-click mute"
            subdued: Audio.micMuted || Audio.source === null
            onClicked: button => button === Qt.RightButton ? Audio.toggleMic() : Panels.togglePreferences("audio", bar.output)
        }

        BarChip {
            theme: bar.theme
            visible: Brightness.available
            glyph: Brightness.icon
            text: bar.roomForLabels ? Math.round(Brightness.value * 100) + "%" : ""
            hint: "Brightness · " + Math.round(Brightness.value * 100) + "%\nClick for quick controls · Scroll to adjust"
            onClicked: Panels.toggle("controls")
            onStepped: direction => Brightness.nudge(direction * 0.05)
        }

        BarChip {
            theme: bar.theme
            visible: Power.present
            glyph: Power.icon
            text: Power.percent + "%"
            hint: Power.statusText + " · " + Power.profileName + "\nClick for power options"
            onClicked: Panels.toggle("power")
        }

        BarChip {
            theme: bar.theme
            glyph: "cog"
            hint: "Settings, Networks and Audio"
            selected: Panels.preferences && Panels.preferencesTab === "settings" && Panels.popupScreen === bar.output
            onClicked: Panels.togglePreferences("settings", bar.output)
        }

        BarChip {
            theme: bar.theme
            glyph: Notifs.count ? "bell_badge" : "bell_outline"
            text: Notifs.count ? String(Notifs.count) : ""
            hint: "Open notifications"
            selected: Panels.notifications && Panels.popupScreen === bar.output
            onClicked: Panels.toggleNotifications(bar.output)
        }

        BarChip {
            theme: bar.theme
            glyph: "calendar_today"
            text: Qt.formatDateTime(clock.date, bar.roomForLabels ? "ddd dd MMM  HH:mm" : "ddd HH:mm")
            hint: Qt.formatDate(clock.date, "dddd, d MMMM yyyy") + "\nClick for calendar · Right-click for clock"
            selected: Panels.calendar && Panels.popupScreen === bar.output
            onClicked: button => button === Qt.RightButton ? Chrono.toggle() : Panels.toggleCalendar(bar.output)
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: bar.theme.line
    }
}
