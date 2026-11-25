pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services
import qs.widgets

PanelWindow {
    id: osd

    property bool enabled: true
    screen: Panels.focusedScreen
    visible: enabled && Osd.visible && !Panels.capturing && Osd.kind !== "workspace"
    anchors.top: true
    margins.top: Config.barExtent + 10
    implicitWidth: 248
    implicitHeight: Osd.value >= 0 ? 55 : 40
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "prism-compact-osd"
    mask: Region {}

    Rectangle {
        anchors.fill: parent
        radius: Theme.r.sm
        color: Theme.surface
        border.color: Theme.outlineVariant

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                Icon { icon: Osd.icon; color: Theme.primary; size: 17 }
                Txt { text: Osd.label; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            Rectangle {
                visible: Osd.value >= 0
                Layout.fillWidth: true
                implicitHeight: 3
                radius: 2
                color: Theme.surfaceVariant
                Rectangle {
                    height: parent.height
                    width: parent.width * Utils.clamp(Osd.value, 0, 1)
                    radius: parent.radius
                    color: Theme.primary
                }
            }
        }
    }
}
