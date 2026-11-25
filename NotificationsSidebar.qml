pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

Overlay {
    id: sidebar

    name: "notifications"
    open: Panels.notifications
    requestedScreen: Panels.popupScreen
    margins.top: Config.barExtent
    scrimOpacity: 0
    openDuration: 0
    closeDuration: 0
    onDismiss: Panels.notifications = false
    onOpened: history.forceActiveFocus()

    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right; margins: 8 }
        width: Math.min(375, parent.width - 16)
        color: Theme.surface
        border.color: Theme.outlineVariant
        radius: 9

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                SectionTitle {
                    Layout.fillWidth: true
                    icon: "bell_outline"
                    text: "Notifications"
                }

                Btn {
                    text: "Clear all"
                    filled: false
                    radius: 5
                    visible: Notifs.count > 0
                    onClicked: Notifs.clear()
                }

                IconBtn {
                    icon: "close"
                    tooltip: "Close notifications"
                    onClicked: sidebar.dismiss()
                }
            }

            ListView {
                id: history
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                keyNavigationEnabled: true
                spacing: 6
                model: Notifs.entries
                Keys.onDeletePressed: currentItem?.modelData?.dismiss()

                delegate: Rectangle {
                    id: row
                    required property var modelData

                    width: history.width
                    height: message.implicitHeight + 20
                    radius: 5
                    color: Theme.surfaceContainer
                    border.color: history.activeFocus && ListView.isCurrentItem ? Theme.primary : Theme.outlineVariant
                    border.width: 1

                    ColumnLayout {
                        id: message
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Txt {
                                Layout.fillWidth: true
                                text: row.modelData?.appName || "Notification"
                                textFormat: Text.PlainText
                                color: Theme.fgDim
                            }

                            IconBtn {
                                size: 26
                                icon: "close"
                                tooltip: "Dismiss notification"
                                onClicked: row.modelData?.dismiss()
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            text: row.modelData?.summary ?? ""
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            font.weight: Font.DemiBold
                        }

                        Txt {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: row.modelData?.body ?? ""
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: childrenRect.height > 0
                            spacing: 4

                            Repeater {
                                model: row.modelData?.actions ?? []
                                Btn {
                                    required property var modelData
                                    text: modelData.text
                                    filled: false
                                    radius: 5
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }
                }

                Txt {
                    anchors.centerIn: parent
                    visible: history.count === 0
                    text: "No notifications"
                    color: Theme.fgDim
                }
            }
        }
    }
}
