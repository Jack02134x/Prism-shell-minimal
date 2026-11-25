pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.services
import qs.widgets

Overlay {
    id: win

    name: "edit"
    open: Panels.edit
    scrimOpacity: 0.18
    onDismiss: {
        if (adding)
            stopAdding();
        else
            Panels.edit = false;
    }
    onOpened: {
        stopAdding();
        list.currentIndex = folders.length ? 0 : -1;
    }

    property bool adding: false
    property string folderError: ""
    readonly property var folders: Config.apps.editFolders

    function label(path: string): string {
        return path === Config.home || path.startsWith(Config.home + "/") ? "~" + path.slice(Config.home.length) : path;
    }
    function normalizedPath(path: string): string {
        if (path === "~" || path.startsWith("~/"))
            path = Config.home + path.slice(1);
        if (!path.startsWith("/"))
            return "";
        return path.replace(/\/{2,}/g, "/").replace(/\/+$/, "") || "/";
    }
    function startAdding(): void {
        folderError = "";
        adding = true;
        folderPath.focusInput();
    }
    function stopAdding(): void {
        adding = false;
        folderCheck.candidate = "";
        folderPath.text = "";
        folderError = "";
        keys.forceActiveFocus();
    }
    function addFolder(path: string): void {
        if (folderCheck.running)
            return;

        const folder = normalizedPath(path);
        if (folder === "") {
            folderError = "Enter an absolute folder path or start with ~/.";
        } else if (folders.some(saved => normalizedPath(saved) === folder)) {
            folderError = "That folder is already in Quick Edit.";
        } else {
            folderError = "";
            folderCheck.candidate = folder;
            folderCheck.running = true;
        }
    }
    function removeAt(index: int): void {
        if (index < 0 || index >= folders.length)
            return;

        const remaining = folders.filter((_, i) => i !== index);
        Config.apps.editFolders = remaining;
        list.currentIndex = Math.min(index, remaining.length - 1);
        keys.forceActiveFocus();
    }
    function iconFor(path) {
        const p = String(path);
        if (p.endsWith("/hypr"))
            return "view_grid";
        if (p.endsWith("/quickshell"))
            return "creation";
        if (p.endsWith("/.scripts"))
            return "script_text_outline";
        if (p.endsWith("/Projects"))
            return "folder_star";
        return "code_braces";
    }
    function openAt(i) {
        const p = folders[i];
        if (!p)
            return;
        Panels.edit = false;
        Quickshell.execDetached([Config.apps.editor, p]);
    }

    Process {
        id: folderCheck
        property string candidate: ""
        command: ["test", "-d", candidate]
        onExited: exitCode => {
            if (!win.open || !win.adding || candidate === "")
                return;

            if (exitCode !== 0) {
                win.folderError = "Folder not found.";
                folderPath.focusInput();
                return;
            }

            const all = [...win.folders, candidate];
            Config.apps.editFolders = all;
            win.stopAdding();
            list.currentIndex = all.length - 1;
        }
    }

    Binding {
        target: card.Window.window
        property: "palette"
        value: Palette {
            window: Theme.surface
            windowText: Theme.fg
            base: Theme.surfaceLow
            alternateBase: Theme.surfaceContainer
            text: Theme.fg
            button: Theme.surfaceHigh
            buttonText: Theme.fg
            light: Theme.surfaceContainer
            dark: Theme.outlineVariant
            highlight: Theme.surfaceHighest
            highlightedText: Theme.fg
        }
    }

    FolderDialog {
        id: picker
        parentWindow: card.Window.window
        options: FolderDialog.DontUseNativeDialog
        popupType: Controls.Popup.Item
        title: "Add a folder to Quick Edit"
        acceptLabel: "Add folder"
        currentFolder: "file://" + Config.home
        onAccepted: {
            folderPath.text = decodeURIComponent(String(selectedFolder).replace(/^file:\/\//, ""));
            folderPath.focusInput();
            win.addFolder(folderPath.text);
        }
        onRejected: if (win.adding) folderPath.focusInput()
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            if (win.adding)
                return;

            if (event.key === Qt.Key_A && event.modifiers === Qt.NoModifier)
                win.startAdding();
            else if (event.key === Qt.Key_Delete)
                win.removeAt(list.currentIndex);
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
                win.openAt(event.key - Qt.Key_1);
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_J)
                list.incrementCurrentIndex();
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || event.key === Qt.Key_K)
                list.decrementCurrentIndex();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                win.openAt(list.currentIndex);
            else
                return;
            event.accepted = true;
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.min(parent.height * 0.18, (parent.height - height) / 2) - (1 - win.progress) * 30
        width: Math.min(540, parent.width - 32)
        height: Math.min(col.implicitHeight + 36, parent.height - 40)
        radius: 9
        color: Theme.surface
        border.color: Theme.outlineVariant
        opacity: win.progress
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            RowLayout {
                SectionTitle {
                    Layout.fillWidth: true
                    icon: "code_braces"
                    text: "Quick edit"
                    accent: Theme.accent(2)
                }
                Txt {
                    visible: !win.adding
                    text: "opens in " + Config.apps.editor
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
                Btn {
                    text: win.adding ? "Cancel" : "Add folder"
                    radius: 5
                    icon: win.adding ? "close" : "plus"
                    filled: !win.adding
                    accent: Theme.accent(2)
                    onClicked: win.adding ? win.stopAdding() : win.startAdding()
                }
            }

            RowLayout {
                visible: win.adding
                Layout.fillWidth: true

                InputField {
                    id: folderPath
                    Layout.fillWidth: true
                    implicitHeight: 36
                    icon: ""
                    placeholder: "/path/to/folder or ~/folder"
                    fontSize: 13
                    accent: Theme.accent(2)
                    input.Accessible.name: "Folder path"
                    onTextChanged: win.folderError = ""
                    onAccepted: win.addFolder(text)
                    onNavigate: (delta, vertical) => {
                        if (!vertical)
                            (delta > 0 ? browse : add).forceActiveFocus();
                    }
                }
                Btn {
                    id: browse
                    radius: 5
                    text: "Browse…"
                    filled: false
                    onClicked: picker.open()
                }
                Btn {
                    id: add
                    radius: 5
                    text: "Add"
                    accent: Theme.accent(2)
                    enabled: !folderCheck.running
                    onClicked: win.addFolder(folderPath.text)
                }
            }
            Txt {
                visible: win.adding && win.folderError !== ""
                Layout.fillWidth: true
                text: win.folderError
                color: Theme.error
            }

            Txt {
                visible: list.count === 0 && !win.adding
                text: "No folders in Quick Edit"
                color: Theme.fgDim
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: count * 52 + Math.max(0, count - 1) * spacing
                visible: count > 0
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: true
                model: win.folders

                delegate: Rectangle {
                    id: row
                    required property string modelData
                    required property int index
                    readonly property bool sel: list.currentIndex === index
                    readonly property color accent: Theme.accent(index * 2)
                    width: list.width
                    height: 52
                    radius: 5
                    color: sel ? Theme.alpha(accent, 0.14) : "transparent"
                    border.width: sel ? 1 : 0
                    border.color: Theme.alpha(accent, 0.7)
                    Behavior on color { ColAnim {} }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: win.openAt(row.index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12
                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 5
                            color: Theme.alpha(row.accent, 0.18)
                            Icon {
                                anchors.centerIn: parent
                                icon: win.iconFor(row.modelData)
                                size: 18
                                color: row.accent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Txt {
                                Layout.fillWidth: true
                                text: Utils.fileName(row.modelData.replace(/\/+$/, "")) || row.modelData
                                textFormat: Text.PlainText
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: win.label(row.modelData)
                                textFormat: Text.PlainText
                                font.pixelSize: 11
                                font.family: Theme.mono
                                color: Theme.fgDim
                            }
                        }
                        Keycap {
                            visible: row.index < 9
                            text: String(row.index + 1)
                            accent: row.accent
                        }
                        IconBtn {
                            visible: !win.adding
                            icon: "trash_can_outline"
                            size: 30
                            tooltip: "Remove from Quick Edit"
                            accent: Theme.error
                            onClicked: win.removeAt(row.index)
                        }
                    }
                }
            }

            Txt {
                visible: !win.adding
                Layout.fillWidth: true
                text: "A · Add folder     Delete · Remove selected     Enter · Open"
                font.pixelSize: 11
                color: Theme.fgDim
            }
        }
    }
}
