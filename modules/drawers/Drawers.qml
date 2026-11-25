import QtQuick
import Quickshell
import qs.common
import qs.services

// Quick controls on the left edge of each output.
Scope {
    id: root

    required property var modelData
    readonly property bool focused: modelData === Panels.focusedScreen

    Drawer {
        id: left
        modelData: root.modelData
        visible: Config.drawers.left && !Panels.capturing
        leftSide: true
        panelWidth: 420
        accent: Theme.accent(0)
        open: Panels.controls && root.focused
        onRequestOpen: value => value ? Panels.show("controls") : (Panels.controls = false)

        DrawerBody {
            shown: left.shown
            sourceComponent: ControlsContent {
                active: Panels.controls && root.focused
            }
        }
    }

}
