pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: browser

    required property PaletteTheme theme
    required property DesktopTools desktop
    required property var entries
    required property int selectedIndex
    readonly property int columns: Math.max(1, Math.floor(gallery.width / 200))
    signal activated(index: int)

    spacing: 10

    RowLayout {
        Layout.fillWidth: true

        ToolButton { theme: browser.theme; label: "Dark"; selected: !theme.light; onClicked: browser.desktop.setThemeMode("dark") }
        ToolButton { theme: browser.theme; label: "Light"; selected: theme.light; onClicked: browser.desktop.setThemeMode("light") }
        Item { Layout.fillWidth: true }
        ToolButton {
            theme: browser.theme
            label: "Stop video"
            visible: browser.desktop.playingWallpaper
            onClicked: browser.desktop.stopLiveWallpaper()
        }
        ToolButton {
            theme: browser.theme
            label: "Transition · " + (theme.transitions.find(option => option.id === theme.transition)?.label ?? "Fade")
            onClicked: theme.cycleTransition()
        }
        ToolButton { theme: browser.theme; label: "Random"; onClicked: browser.desktop.refreshWallpapers(true) }
    }

    GridView {
        id: gallery

        readonly property int rows: Math.ceil(count / browser.columns)
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Math.max(rows, 1), 3) * cellHeight
        clip: true
        cellWidth: width / browser.columns
        cellHeight: 158
        cacheBuffer: 100
        model: browser.entries
        currentIndex: Math.min(browser.selectedIndex, count - 1)
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)

        delegate: Item {
            id: tile

            required property var modelData
            required property int index
            property string preview: ""
            width: gallery.cellWidth
            height: gallery.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: browser.theme.selection
                border.color: tile.GridView.isCurrentItem ? browser.theme.accent : browser.theme.line
                border.width: tile.GridView.isCurrentItem ? 2 : 1
                radius: 6

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    anchors.bottomMargin: 30
                    source: browser.theme.imageUrl(tile.modelData.video ? tile.preview : (tile.modelData.path ?? ""))
                    sourceSize.width: 300
                    sourceSize.height: 190
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                }

                Text {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                    text: tile.modelData.video ? tile.modelData.title + " · Video" : tile.modelData.title
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    color: tile.GridView.isCurrentItem ? browser.theme.accent : browser.theme.foreground
                    font.family: browser.theme.display
                    font.pixelSize: 13
                }
            }

            Process {
                running: Boolean(tile.modelData.video && tile.modelData.path)
                command: ["sh", Quickshell.shellDir + "/scripts/video-thumb.sh", tile.modelData.path ?? "", browser.desktop.videoThumbnail(tile.modelData.path ?? "")]
                stdout: StdioCollector { id: thumbnail }
                onExited: code => { if (code === 0) tile.preview = thumbnail.text.trim(); }
            }

            TapHandler { onTapped: browser.activated(tile.index) }
        }

        Text {
            anchors.centerIn: parent
            visible: gallery.count === 0
            text: browser.desktop.wallpapersLoading ? "Finding wallpapers…" : "No matching images"
            color: browser.theme.muted
            font.pixelSize: 15
        }
    }
}
