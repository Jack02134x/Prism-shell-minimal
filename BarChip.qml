pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.widgets

Rectangle {
    id: chip

    required property PaletteTheme theme
    property string text: ""
    property string glyph: ""
    property string hint: ""
    property bool selected: false
    property bool subdued: false
    property int textLimit: 160
    signal clicked(int button)
    signal stepped(int direction)

    implicitHeight: 24
    implicitWidth: contents.implicitWidth + 12
    radius: 4
    color: selected || mouse.containsMouse ? theme.selection : "transparent"
    border.width: selected ? 1 : 0
    border.color: theme.accent
    Accessible.role: Accessible.Button
    Accessible.name: hint || text || glyph
    Accessible.onPressAction: clicked(Qt.LeftButton)

    Row {
        id: contents
        anchors.centerIn: parent
        spacing: 5

        Icon {
            visible: chip.glyph !== ""
            icon: chip.glyph
            size: 14
            bounce: false
            color: chip.subdued ? chip.theme.muted : chip.theme.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: chip.text !== ""
            width: Math.min(implicitWidth, chip.textLimit)
            text: chip.text
            textFormat: Text.PlainText
            color: chip.subdued ? chip.theme.muted : chip.theme.foreground
            font.family: chip.theme.mono
            font.pixelSize: 12
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => {
            hoverDelay.stop();
            tip.visible = false;
            chip.clicked(event.button);
        }
        onWheel: event => {
            if (event.angleDelta.y)
                chip.stepped(event.angleDelta.y > 0 ? 1 : -1);
        }
        onEntered: hoverDelay.restart()
        onExited: {
            hoverDelay.stop();
            tip.visible = false;
        }
    }

    Timer {
        id: hoverDelay
        interval: 350
        onTriggered: if (chip.hint && !Panels.anyOpen && !Panels.capturing) tip.visible = true
    }

    PopupWindow {
        id: tip
        anchor.item: chip
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.All
        anchor.margins.top: 4
        grabFocus: false
        visible: false
        implicitWidth: Math.min(350, hintText.implicitWidth + 18)
        implicitHeight: hintText.height + 12
        color: "transparent"
        mask: Region {}

        Rectangle {
            anchors.fill: parent
            radius: 5
            color: chip.theme.background
            border.color: chip.theme.line

            Text {
                id: hintText
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 9; topMargin: 6 }
                text: chip.hint
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                color: chip.theme.foreground
                font.family: chip.theme.display
                font.pixelSize: 12
            }
        }
    }

    Connections {
        target: Panels
        function onAnyOpenChanged() { if (Panels.anyOpen) tip.visible = false; }
        function onCapturingChanged() { if (Panels.capturing) tip.visible = false; }
    }
}
