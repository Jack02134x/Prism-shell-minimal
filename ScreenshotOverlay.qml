pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: shot

    required property PaletteTheme theme
    required property ScreenshotSession session

    property rect selection: Qt.rect(0, 0, 0, 0)
    property point cursor: Qt.point(-1, -1)
    readonly property bool selected: selection.width >= 2 && selection.height >= 2
    readonly property bool windowMode: session.mode === "window"
    readonly property HyprlandMonitor monitor: Hyprland.monitors.values.find(entry => entry.name === session.output?.name) ?? null
    readonly property var windows: {
        if (!monitor)
            return [];

        const active = monitor.activeWorkspace?.id;
        const special = monitor.lastIpcObject.specialWorkspace?.id;
        return Hyprland.toplevels.values.map(window => window.lastIpcObject)
            .filter(window => window?.at && window.size && (window.workspace?.id === active || window.workspace?.id === special))
            .map(window => ({
                bounds: clampRect(window.at[0] - monitor.x, window.at[1] - monitor.y, window.size[0], window.size[1]),
                rank: (window.workspace.id === special ? 8 : 0) + (window.fullscreen ? 4 : 0) + (window.floating ? 2 : 0),
                order: window.focusHistoryID ?? 99
            })).sort((left, right) => right.rank - left.rank || left.order - right.order)
            .map(entry => entry.bounds);
    }
    readonly property var hovered: windows.find(box => cursor.x >= box.x && cursor.y >= box.y
        && cursor.x < box.x + box.width && cursor.y < box.y + box.height)
    readonly property rect outlined: selected ? selection : (hovered ?? Qt.rect(0, 0, 0, 0))

    screen: session.output
    visible: session.open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "prism-minimal-capture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onBackingWindowVisibleChanged: if (backingWindowVisible) {
        selection = Qt.rect(0, 0, 0, 0);
        cursor = Qt.point(-1, -1);
        stage.forceActiveFocus();
    }

    function clampRect(x: real, y: real, w: real, h: real): rect {
        const left = Math.max(0, Math.min(width, x));
        const top = Math.max(0, Math.min(height, y));
        return Qt.rect(left, top, Math.max(0, Math.min(width, x + w) - left), Math.max(0, Math.min(height, y + h) - top));
    }

    function setMode(mode: string): void {
        session.mode = mode;
        selection = Qt.rect(0, 0, 0, 0);
    }

    function nudge(dx: int, dy: int, resize: bool): void {
        const box = selection;
        if (resize) {
            selection = clampRect(box.x, box.y, Math.max(2, box.width + dx), Math.max(2, box.height + dy));
        } else {
            const x = Math.max(0, Math.min(width - box.width, box.x + dx));
            const y = Math.max(0, Math.min(height - box.height, box.y + dy));
            selection = Qt.rect(x, y, box.width, box.height);
        }
    }

    function pixels(box: rect): rect {
        const sx = frame.sourceSize.width / width;
        const sy = frame.sourceSize.height / height;
        const x = Math.floor(box.x * sx);
        const y = Math.floor(box.y * sy);
        return Qt.rect(x, y, Math.ceil((box.x + box.width) * sx) - x, Math.ceil((box.y + box.height) * sy) - y);
    }

    function save(action: string): void {
        if (frame.status !== Image.Ready)
            return;

        const crop = selected && (selection.width < width || selection.height < height) ? pixels(selection) : null;
        session.finish(crop ? `${crop.width}x${crop.height}+${crop.x}+${crop.y}` : "", action);
    }

    Item {
        id: stage
        anchors.fill: parent

        Keys.onPressed: event => {
            const key = event.key;
            const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
            if (key === Qt.Key_Escape)
                shot.session.cancel();
            else if (key === Qt.Key_Return || key === Qt.Key_Enter)
                shot.save(shot.session.defaultAction);
            else if (ctrl && key === Qt.Key_C)
                shot.save("copy");
            else if (ctrl && key === Qt.Key_S)
                shot.save("save");
            else if (key === Qt.Key_C)
                shot.session.color();
            else if (key === Qt.Key_Tab)
                shot.setMode(shot.windowMode ? "region" : "window");
            else if (shot.selected && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(key))
                shot.nudge(key === Qt.Key_Left ? -1 : key === Qt.Key_Right ? 1 : 0,
                    key === Qt.Key_Up ? -1 : key === Qt.Key_Down ? 1 : 0, (event.modifiers & Qt.ShiftModifier) !== 0);
            else
                return;
            event.accepted = true;
        }

        Image {
            id: frame
            anchors.fill: parent
            source: shot.session.directory ? shot.theme.imageUrl(shot.session.directory + "/frame.png") : ""
            cache: false
            smooth: false
        }

        Rectangle { width: stage.width; height: shot.outlined.y; color: "#78000000" }
        Rectangle { y: shot.outlined.y + shot.outlined.height; width: stage.width; height: stage.height - y; color: "#78000000" }
        Rectangle { y: shot.outlined.y; width: shot.outlined.x; height: shot.outlined.height; color: "#78000000" }
        Rectangle { x: shot.outlined.x + shot.outlined.width; y: shot.outlined.y; width: stage.width - x; height: shot.outlined.height; color: "#78000000" }

        Rectangle {
            x: shot.outlined.x
            y: shot.outlined.y
            width: shot.outlined.width
            height: shot.outlined.height
            visible: width > 0 && height > 0
            color: "transparent"
            border.color: shot.theme.accent
            border.width: 2
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.CrossCursor
            property point origin
            property bool dragging: false

            onPressed: event => {
                if (event.button === Qt.RightButton) {
                    shot.session.cancel();
                    return;
                }
                origin = Qt.point(event.x, event.y);
                shot.cursor = origin;
                dragging = false;
            }
            onPositionChanged: event => {
                shot.cursor = Qt.point(event.x, event.y);
                if (!pressed || shot.windowMode)
                    return;

                const w = Math.abs(origin.x - event.x);
                const h = Math.abs(origin.y - event.y);
                if (!dragging && Math.max(w, h) < 4)
                    return;
                dragging = true;
                shot.selection = shot.clampRect(Math.min(origin.x, event.x), Math.min(origin.y, event.y), w, h);
            }
            onReleased: event => {
                if (event.button === Qt.LeftButton && !dragging)
                    shot.selection = shot.hovered ?? Qt.rect(0, 0, 0, 0);
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: Math.min(parent.width - 24, controls.implicitWidth + 24)
            height: controls.implicitHeight + 22
            color: shot.theme.background
            border.color: shot.theme.line
            radius: 8

            ColumnLayout {
                id: controls
                anchors.centerIn: parent
                spacing: 8

                RowLayout {
                    spacing: 6
                    ToolButton { theme: shot.theme; label: "Area"; selected: !shot.windowMode; onClicked: shot.setMode("region") }
                    ToolButton { theme: shot.theme; label: "Window"; selected: shot.windowMode; onClicked: shot.setMode("window") }
                    ToolButton { theme: shot.theme; label: "Whole screen"; onClicked: shot.selection = shot.clampRect(0, 0, shot.width, shot.height) }
                    ToolButton { theme: shot.theme; label: "Colour"; onClicked: shot.session.color() }
                    Item { Layout.preferredWidth: 8 }
                    ToolButton { theme: shot.theme; label: "Copy"; onClicked: shot.save("copy") }
                    ToolButton { theme: shot.theme; label: "Save"; onClicked: shot.save("save") }
                    ToolButton { theme: shot.theme; label: "Copy and save"; selected: true; onClicked: shot.save("both") }
                }

                Text {
                    Layout.fillWidth: true
                    text: (shot.selected ? shot.pixels(shot.selection).width + " × " + shot.pixels(shot.selection).height + "   ·   " : "")
                        + (shot.windowMode ? "Click a window" : "Drag an area or click a window") + "   ·   Tab mode   ·   Enter capture   ·   Esc cancel"
                    horizontalAlignment: Text.AlignHCenter
                    color: shot.theme.muted
                    font.family: shot.theme.display
                    font.pixelSize: 13
                }
            }
        }
    }
}
