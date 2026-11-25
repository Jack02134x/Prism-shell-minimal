import QtQuick
import qs.common
import qs.services
import qs.widgets

// Plasma orb that wobbles with the music. Opens the launcher, settings, or overview.
Item {
    id: root

    implicitWidth: 34
    implicitHeight: 34

    Orb {
        anchors.centerIn: parent
        width: ma.containsMouse ? 38 : 32
        height: width
        level: Math.min(1, Cava.bass * 1.4)
        Behavior on width { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Panels.togglePreferences();
            else if (mouse.button === Qt.MiddleButton)
                Panels.toggle("overview");
            else
                Panels.toggle("launcher");
        }
    }

    Tip {
        text: "Launcher · right-click settings · middle-click overview"
        show: ma.containsMouse
    }

    Component.onCompleted: Cava.consumers++
    Component.onDestruction: Cava.consumers--
}
