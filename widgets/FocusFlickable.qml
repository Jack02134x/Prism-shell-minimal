import QtQuick
import QtQuick.Window

Flickable {
    id: view

    readonly property Item focusedItem: Window.window?.activeFocusItem ?? null
    boundsBehavior: Flickable.StopAtBounds

    onFocusedItemChanged: {
        const focused = view.focusedItem;
        for (let item = focused; item; item = item.parent) {
            if (item === contentItem) {
                const y = focused.mapToItem(contentItem, 0, 0).y;
                const bottom = y + focused.height;
                if (y < contentY)
                    contentY = Math.max(0, y - 6);
                else if (bottom > contentY + height)
                    contentY = Math.min(Math.max(0, contentHeight - height), bottom - height + 6);
                break;
            }
        }
    }
}
