pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import "Search.js" as Search

PanelWindow {
    id: picker

    required property PaletteTheme theme
    required property DesktopTools desktop
    property bool open: false
    property string mode: "apps"
    property int selectedIndex: 0
    property alias actions: sources
    property var confirmation: null

    signal barToggleRequested()
    signal nativeQueryRequested(string query)

    readonly property var primaryModes: [
        { id: "apps", label: "Apps", prefix: "", placeholder: "Find an app…" },
        { id: "windows", label: "Windows", prefix: "@", placeholder: "Find an open window…" },
        { id: "workspaces", label: "Workspaces", prefix: ":", placeholder: "Find a workspace or enter its number…" },
        { id: "clipboard", label: "Clipboard", prefix: ">", placeholder: "Find a clipboard entry…" },
        { id: "commands", label: "Commands", prefix: "/", placeholder: "Find a shell action…" }
    ]
    readonly property var modes: primaryModes.concat([
        { id: "wallpapers", label: "Wallpapers", prefix: "w ", placeholder: "Find a wallpaper…" },
        { id: "emoji", label: "Emoji", placeholder: "Find an emoji…" },
        { id: "captures", label: "Screenshot", placeholder: "Find a capture action…" },
        { id: "edit", label: "Quick edit", placeholder: "Find a folder to edit…" },
        { id: "shortcuts", label: "Shortcuts", placeholder: "Search shortcuts…" },
        { id: "power", label: "Power", placeholder: "Find a power action…" },
        { id: "confirm", label: "Confirm", placeholder: "Confirm " + (picker.confirmation?.title ?? "action") + "?" }
    ])
    readonly property var activeMode: modes.find(option => option.id === mode)
    readonly property var matches: open ? Search.rank(entries(), input.text) : []
    readonly property bool isWallpaper: mode === "wallpapers"
    readonly property bool isShortcuts: mode === "shortcuts"

    function entries(): var {
        switch (mode) {
        case "apps": return sources.apps;
        case "windows": return sources.windows();
        case "workspaces": return sources.workspaces(input.text);
        case "clipboard": return sources.clipboardEntries;
        case "commands": return sources.commands;
        case "wallpapers": return desktop.wallpapers;
        case "emoji": return desktop.emojis;
        case "captures": return desktop.captureOptions;
        case "edit": return desktop.editOptions;
        case "shortcuts": return desktop.shortcuts;
        case "power": return sources.powerOptions;
        case "confirm": return confirmation ? [
            { title: "Cancel", detail: "Back to power actions", mode: "power" },
            { title: confirmation.title, detail: "Confirm action", run: confirmation.run }
        ] : [];
        }
        return [];
    }

    function showMode(nextMode: string): bool {
        if (!modes.some(option => option.id === nextMode))
            return false;

        if (!open) {
            const focusedMonitor = Hyprland.focusedMonitor?.name;
            screen = Quickshell.screens.find(output => output.name === focusedMonitor) ?? Quickshell.screens[0] ?? null;
            if (screen === null)
                return false;
        }

        setMode(nextMode);
        open = true;
        return true;
    }

    function toggleMode(nextMode: string): void {
        if (open && mode === nextMode)
            open = false;
        else
            showMode(nextMode);
    }

    function showSearch(nextMode: string, query: string): void {
        if (showMode(nextMode))
            input.text = query;
    }

    function setMode(nextMode: string): void {
        mode = nextMode;
        input.clear();
        selectedIndex = 0;
        if (nextMode === "wallpapers")
            desktop.refreshWallpapers(false);
        if (nextMode === "shortcuts")
            desktop.refreshShortcuts();
    }

    function stepMode(direction: int): void {
        const count = primaryModes.length;
        const index = primaryModes.findIndex(option => option.id === mode);
        const next = index === -1 ? (direction > 0 ? 0 : count - 1) : (index + direction + count) % count;
        setMode(primaryModes[next].id);
    }

    function moveSelection(direction: int): void {
        const count = matches.length;
        if (!count)
            return;

        const current = Math.min(selectedIndex, count - 1);
        selectedIndex = (current + direction + count * 2) % count;
    }

    function runSelected(): void {
        const entry = matches[Math.min(selectedIndex, matches.length - 1)];
        if (!entry)
            return;

        if (entry.mode) {
            setMode(entry.mode);
        } else if (entry.confirm) {
            confirmation = entry;
            setMode("confirm");
        } else if (entry.run) {
            open = false;
            Qt.callLater(entry.run);
        }
    }

    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "prism-minimal-palette"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onBackingWindowVisibleChanged: {
        if (backingWindowVisible) {
            input.forceActiveFocus();
        } else {
            input.focus = false;
            input.clear();
        }
    }

    PaletteActions {
        id: sources
        clipboardActive: picker.open && picker.mode === "clipboard"
        desktop: picker.desktop
        onBarToggleRequested: picker.barToggleRequested()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            const point = panel.mapFromItem(parent, mouse.x, mouse.y);
            if (!panel.contains(point))
                picker.open = false;
        }
    }

    Rectangle {
        id: panel

        width: picker.isShortcuts ? parent.width / Config.uiScale : Math.min(picker.isWallpaper ? 1080 : 620, (parent.width - 24) / Config.uiScale)
        height: picker.isShortcuts ? parent.height / Config.uiScale : contents.implicitHeight
        scale: Config.uiScale
        transformOrigin: Item.Top
        anchors.horizontalCenter: parent.horizontalCenter
        y: picker.isShortcuts ? 0 : Math.max(12, Math.min(Math.round(parent.height * 0.18), parent.height - height * scale - 12))
        color: picker.theme.background
        radius: picker.isShortcuts ? 0 : 6
        border.color: picker.theme.line

        ColumnLayout {
            id: contents

            width: parent.width
            height: picker.isShortcuts ? parent.height : implicitHeight
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: picker.isShortcuts ? 34 : 16
                Layout.rightMargin: picker.isShortcuts ? 34 : 16
                Layout.preferredHeight: picker.isShortcuts ? 84 : 56
                Layout.maximumHeight: Layout.preferredHeight
                Layout.minimumHeight: Layout.preferredHeight
                spacing: 16

                Label {
                    visible: picker.isShortcuts
                    text: "Keyboard shortcuts"
                    font.family: picker.theme.display
                    font.pixelSize: 27
                    font.weight: Font.DemiBold
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 43
                        radius: 6
                        visible: picker.isShortcuts
                        color: picker.theme.selection
                        border.color: picker.theme.line
                    }

                    Label {
                        anchors.fill: input
                        visible: !input.text && !input.inputMethodComposing
                        text: picker.activeMode.placeholder
                        color: picker.theme.muted
                        font.pixelSize: picker.isShortcuts ? 18 : 15
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    TextInput {
                        id: input

                        anchors.fill: parent
                        anchors.leftMargin: picker.isShortcuts ? 12 : 0
                        anchors.rightMargin: picker.isShortcuts ? 12 : 0
                        clip: true
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: picker.theme.foreground
                        selectionColor: picker.theme.accent
                        selectedTextColor: picker.theme.background
                        font.family: picker.theme.mono
                        font.pixelSize: picker.isShortcuts ? 18 : 15
                        Accessible.name: picker.activeMode.placeholder

                        onTextChanged: picker.selectedIndex = 0
                        onTextEdited: {
                            if (picker.mode === "apps" && text.length > 0 && text.length <= 2) {
                                if (["=", "$", "#", "y ", "?"].includes(text)) {
                                    picker.nativeQueryRequested(text);
                                    return;
                                }
                                const option = picker.modes.find(entry => entry.prefix === text);
                                if (option)
                                    picker.setMode(option.id);
                            }
                        }

                        Keys.onPressed: event => {
                            const control = event.modifiers === Qt.ControlModifier;
                            const key = event.key;

                            if (key === Qt.Key_Escape)
                                picker.open = false;
                            else if (key === Qt.Key_Tab || key === Qt.Key_Backtab)
                                picker.stepMode(key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                            else if (key === Qt.Key_Down || (control && (key === Qt.Key_J || key === Qt.Key_N)))
                                picker.moveSelection(picker.isWallpaper ? wallpaperGrid.columns : 1);
                            else if (key === Qt.Key_Up || (control && (key === Qt.Key_K || key === Qt.Key_P)))
                                picker.moveSelection(picker.isWallpaper ? -wallpaperGrid.columns : -1);
                            else if (picker.isWallpaper && event.modifiers === Qt.NoModifier && (key === Qt.Key_Left || key === Qt.Key_Right))
                                picker.moveSelection(key === Qt.Key_Left ? -1 : 1);
                            else if (picker.isWallpaper && control && key === Qt.Key_T)
                                picker.desktop.setThemeMode(picker.theme.light ? "dark" : "light");
                            else if (picker.isWallpaper && control && key === Qt.Key_G)
                                picker.theme.cycleTransition();
                            else if (picker.isWallpaper && control && key === Qt.Key_R)
                                picker.desktop.refreshWallpapers(true);
                            else if (picker.isShortcuts && (key === Qt.Key_PageDown || key === Qt.Key_PageUp))
                                picker.moveSelection(key === Qt.Key_PageDown ? list.visibleRows : -list.visibleRows);
                            else if (picker.mode === "clipboard" && key === Qt.Key_Delete && event.modifiers === Qt.ShiftModifier)
                                picker.matches[list.currentIndex]?.remove();
                            else if (key === Qt.Key_Return || key === Qt.Key_Enter)
                                picker.runSelected();
                            else if (control && key === Qt.Key_U)
                                input.clear();
                            else if (control && key === Qt.Key_E)
                                picker.setMode("emoji");
                            else if (control && key >= Qt.Key_1 && key <= Qt.Key_5)
                                picker.setMode(picker.primaryModes[key - Qt.Key_1].id);
                            else
                                return;

                            event.accepted = true;
                        }
                    }
                }

                Label {
                    text: picker.isShortcuts ? "Esc to close" : picker.activeMode.label
                    color: picker.theme.accent
                }
            }

            Divider {}

            WallpaperGrid {
                id: wallpaperGrid
                visible: picker.isWallpaper
                Layout.fillWidth: true
                Layout.margins: 12
                theme: picker.theme
                desktop: picker.desktop
                entries: visible ? picker.matches : []
                selectedIndex: picker.selectedIndex
                onActivated: index => {
                    picker.selectedIndex = index;
                    picker.runSelected();
                }
            }

            ListView {
                id: list

                visible: !picker.isWallpaper
                Layout.fillWidth: true
                Layout.fillHeight: picker.isShortcuts
                Layout.leftMargin: picker.isShortcuts ? 26 : 6
                Layout.rightMargin: picker.isShortcuts ? 26 : 6
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                Layout.preferredHeight: Math.min(Math.max(count, 1), visibleRows) * rowHeight
                readonly property int rowHeight: picker.isShortcuts ? 49 : picker.mode === "clipboard" && picker.matches.some(entry => entry.imageId) ? 74 : 34
                readonly property int visibleRows: Math.max(1, Math.min(picker.isShortcuts ? 99 : 8, Math.floor((picker.height - 148) / rowHeight)))

                clip: true
                interactive: picker.isShortcuts || picker.mode === "clipboard"
                model: picker.isWallpaper ? [] : picker.matches
                currentIndex: Math.min(picker.selectedIndex, count - 1)
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain);
                }

                delegate: Rectangle {
                    id: result

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: list.rowHeight
                    radius: 3
                    color: ListView.isCurrentItem ? picker.theme.selection : "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 16
                        color: picker.theme.accent
                        visible: result.ListView.isCurrentItem
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Image {
                            id: preview
                            readonly property string imageId: result.modelData.imageId ?? ""
                            visible: imageId !== ""
                            Layout.preferredWidth: 112
                            Layout.preferredHeight: 64
                            fillMode: Image.PreserveAspectFit
                            cache: false

                            onImageIdChanged: loadPreview()
                            Component.onCompleted: loadPreview()
                            function loadPreview(): void {
                                source = "";
                                decode.running = imageId !== "";
                            }
                            Process {
                                id: decode
                                command: ["sh", "-c", 'cliphist decode "$1" | magick - -delete 1--1 -thumbnail 160x96 png:- | base64 -w0', "clipboard-preview", preview.imageId]
                                stdout: StdioCollector {
                                    onStreamFinished: if (text.length) preview.source = "data:image/png;base64," + text
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: result.modelData.title
                            font.family: picker.isShortcuts ? picker.theme.display : picker.theme.mono
                            font.pixelSize: picker.isShortcuts ? 17 : 13
                            elide: Text.ElideRight
                        }

                        Label {
                            Layout.maximumWidth: result.width * 0.45
                            text: result.modelData.detail
                            font.pixelSize: picker.isShortcuts ? 16 : 13
                            color: picker.isShortcuts ? picker.theme.accent : picker.theme.muted
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                    }

                    TapHandler {
                        onTapped: {
                            picker.selectedIndex = result.index;
                            picker.runSelected();
                        }
                    }
                }

                Label {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    visible: list.count === 0
                    elide: Text.ElideRight
                    color: picker.theme.muted
                    text: picker.mode === "clipboard" && sources.clipboardLoading ? "Reading clipboard history…"
                        : picker.mode === "clipboard" && !input.text ? "Clipboard history is empty or unavailable"
                        : picker.mode === "windows" && !input.text ? "No open windows"
                        : "No matches"
                }
            }

            Divider {}

            Label {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
                color: picker.theme.muted
                elide: Text.ElideRight
                text: picker.isWallpaper ? "Arrows Browse    Enter Apply    Ctrl+T Theme    Ctrl+G Transition    Ctrl+R Random"
                    : picker.isShortcuts ? "↑↓ or PgUp/PgDn Scroll    Type to filter"
                    : picker.mode === "clipboard" ? "↑↓ Select    Enter Copy    Shift+Del Remove    Esc Close"
                    : "↑↓ Select    Enter Open    Tab Mode    Esc Close"
            }
        }
    }

    component Label: Text {
        color: picker.theme.foreground
        font.family: picker.theme.mono
        font.pixelSize: 13
        textFormat: Text.PlainText
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 1
        Layout.rightMargin: 1
        implicitHeight: 1
        color: picker.theme.line
    }
}
