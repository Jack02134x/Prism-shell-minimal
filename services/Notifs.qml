pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    readonly property var entries: Array.from(server.trackedNotifications.values).reverse()
    readonly property int count: entries.length

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true
        onNotification: notification => {
            notification.tracked = true;
            if (root.count > 100)
                root.entries[root.count - 1]?.dismiss();
        }
    }

    function clear(): void {
        for (const notification of entries)
            notification.dismiss();
    }

    function local(summary, body, glyph, urgency, image, actions) {
        if (dnd && urgency !== 2)
            return;

        const choices = actions ?? [];
        const level = urgency === 2 ? "critical" : urgency === 0 ? "low" : "normal";
        const command = ["notify-send", "--app-name=Prism", "--urgency=" + level];
        if (image)
            command.push("--icon=" + String(image).replace(/^file:\/\//, ""));
        for (let i = 0; i < choices.length; i++)
            command.push("--action=" + i + "=" + choices[i].text);
        command.push("--", summary, body ?? "");

        if (choices.length === 0)
            Quickshell.execDetached(command);
        else
            sender.createObject(root, { command: ["timeout", "60s", ...command], callbacks: choices, running: true });
    }

    Component {
        id: sender

        Process {
            id: worker

            required property var callbacks
            stdout: StdioCollector { id: selection }
            onExited: {
                const answer = selection.text.trim();
                const callback = /^\d+$/.test(answer) ? worker.callbacks[Number(answer)] : null;
                callback?.run?.();
                worker.destroy();
            }
        }
    }
}
