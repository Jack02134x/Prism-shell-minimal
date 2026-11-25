pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history shared by every palette entry point.
Singleton {
    id: root

    property var entries: []    // [{ id, text, image, line }]
    property bool loading: false
    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    Process {
        id: listProc
        command: ["sh", "-c", "cliphist list | head -n 300"]
        onRunningChanged: root.loading = running
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const t = line.indexOf("\t");
                    if (t < 0)
                        continue;
                    const id = line.slice(0, t);
                    if (!/^\d+$/.test(id))
                        continue;
                    const body = line.slice(t + 1);
                    const image = /^\[\[ binary data .* (png|jpe?g|webp|bmp|gif|tiff?|avif|ico) /i.test(body);
                    out.push({ id: id, text: body, image: image, line: line });
                }
                root.entries = out;
            }
        }
    }

    function copy(e) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "clip", e.line]);
    }

    function remove(entry): void {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "clip", entry.line]);
        entries = entries.filter(item => item.id !== entry.id);
    }
}
