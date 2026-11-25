pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

Overlay {
    id: popup

    name: "calendar"
    open: Panels.calendar
    requestedScreen: Panels.popupScreen
    margins.top: Config.barExtent
    scrimOpacity: 0
    openDuration: 0
    closeDuration: 0
    onDismiss: Panels.calendar = false
    onOpened: {
        month.offset = 0;
        body.forceActiveFocus();
    }

    Rectangle {
        anchors { top: parent.top; right: parent.right; margins: 8 }
        width: Math.min(328, parent.width - 16)
        height: body.implicitHeight + 26
        radius: 9
        color: Theme.surface
        border.color: Theme.outlineVariant

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 13
            focus: true
            Keys.onLeftPressed: month.shift(-1)
            Keys.onRightPressed: month.shift(1)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_PageUp)
                    month.shift(-1);
                else if (event.key === Qt.Key_PageDown)
                    month.shift(1);
                else if (event.key === Qt.Key_Home)
                    month.offset = 0;
                else
                    return;
                event.accepted = true;
            }

            Calendar { id: month; Layout.fillWidth: true }

            Txt {
                Layout.fillWidth: true
                text: "← → Month   ·   Home Today   ·   Esc Close"
                font.pixelSize: 11
                color: Theme.fgDim
            }
        }
    }
}
