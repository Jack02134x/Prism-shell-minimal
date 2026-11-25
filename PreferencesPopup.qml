pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.widgets
import qs.modules.dashboard

Overlay {
    id: popup

    name: "preferences"
    open: Panels.preferences
    requestedScreen: Panels.popupScreen
    margins.top: Config.barExtent
    scrimOpacity: 0
    openDuration: 0
    closeDuration: 0
    onDismiss: Panels.preferences = false
    onOpened: navigation.forceActiveFocus()

    readonly property var tabs: [
        { id: "settings", name: "Settings", icon: "cog" },
        { id: "network", name: "Networks", icon: "wifi" },
        { id: "audio", name: "Audio", icon: "volume_high" }
    ]
    readonly property int selected: tabs.findIndex(tab => tab.id === Panels.preferencesTab)

    function switchBy(amount: int): void {
        select((Math.max(0, selected) + amount + tabs.length) % tabs.length);
    }

    function select(index: int): void {
        Panels.preferencesTab = tabs[index].id;
        navigation.forceActiveFocus();
    }

    Shortcut { sequences: ["Ctrl+Tab"]; enabled: popup.open; onActivated: popup.switchBy(1) }
    Shortcut { sequences: ["Ctrl+Shift+Tab"]; enabled: popup.open; onActivated: popup.switchBy(-1) }
    Shortcut { sequence: "Alt+1"; enabled: popup.open; onActivated: popup.select(0) }
    Shortcut { sequence: "Alt+2"; enabled: popup.open; onActivated: popup.select(1) }
    Shortcut { sequence: "Alt+3"; enabled: popup.open; onActivated: popup.select(2) }

    Rectangle {
        id: panel
        anchors { top: parent.top; right: parent.right; margins: 8 }
        width: Math.min(605, parent.width - 16)
        height: Math.min(482, parent.height - 16)
        color: Theme.surface
        border.color: Theme.outlineVariant
        radius: 9

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Item {
                    id: navigation
                    focus: true
                    Keys.onLeftPressed: popup.switchBy(-1)
                    Keys.onRightPressed: popup.switchBy(1)
                    Keys.onDownPressed: navigation.nextItemInFocusChain(true).forceActiveFocus()
                    Keys.onPressed: event => {
                        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                            popup.select(event.key - Qt.Key_1);
                            event.accepted = true;
                        }
                    }
                }

                Repeater {
                    model: popup.tabs
                    Btn {
                        required property var modelData
                        required property int index
                        text: modelData.name
                        icon: modelData.icon
                        filled: false
                        active: popup.selected === index
                        radius: 5
                        accent: Theme.accent(index * 2)
                        onClicked: popup.select(index)
                    }
                }

                Item { Layout.fillWidth: true }
                IconBtn { icon: "close"; tooltip: "Close"; onClicked: popup.dismiss() }
            }

            Loader {
                id: page
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: popup.open
                sourceComponent: popup.selected === 1 ? networks : popup.selected === 2 ? audio : settings
            }

            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: "1–3 or Ctrl+Tab to switch   ·   Tab to move   ·   Esc to close"
                font.pixelSize: 11
                color: Theme.fgDim
            }
        }
    }

    Component { id: settings; SettingsTab { active: popup.open } }
    Component { id: networks; NetworkTab { active: popup.open } }
    Component { id: audio; AudioTab { active: popup.open } }
}
