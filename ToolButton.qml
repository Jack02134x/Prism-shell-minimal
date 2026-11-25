pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: button

    required property PaletteTheme theme
    required property string label
    property bool selected: false
    signal clicked()

    implicitWidth: caption.implicitWidth + 20
    implicitHeight: 33
    radius: 5
    border.color: selected ? theme.accent : theme.line
    color: selected || pointer.hovered ? theme.selection : theme.background
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: clicked()

    Text {
        id: caption
        anchors.centerIn: parent
        text: button.label
        color: button.selected ? button.theme.accent : button.theme.foreground
        font.family: button.theme.display
        font.pixelSize: 14
    }

    HoverHandler { id: pointer; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: button.clicked() }
}
