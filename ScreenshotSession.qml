pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: capture

    readonly property string script: Quickshell.shellDir + "/scripts/screenshot.sh"
    property ShellScreen output: null
    property string directory: ""
    property string mode: "region"
    property string defaultAction: "both"
    property bool open: false
    property bool pending: false
    readonly property bool pickingColor: colorPicker.running

    onOutputChanged: if (output === null && open) cancel()

    function begin(initialMode: string, action: string, waitSeconds: real): void {
        if (open || pending || freeze.running)
            return;

        const focused = Hyprland.focusedMonitor?.name;
        output = Quickshell.screens.find(screen => screen.name === focused) ?? Quickshell.screens[0] ?? null;
        if (output === null)
            return;

        mode = initialMode;
        defaultAction = action;
        pending = true;
        Hyprland.refreshToplevels();
        delay.interval = 90 + Math.round(Math.max(0, waitSeconds) * 1000);
        delay.start();
    }

    function cancel(): void {
        delay.stop();
        pending = false;
        open = false;
        if (directory) {
            Quickshell.execDetached(["sh", script, "discard", directory]);
            directory = "";
        }
    }

    function finish(geometry: string, action: string): void {
        if (!directory)
            return;

        const savedFrame = directory;
        open = false;
        directory = "";
        Quickshell.execDetached(["sh", script, "finalize", savedFrame, geometry, action]);
    }

    function color(): void {
        cancel();
        if (!colorPicker.running)
            colorPicker.running = true;
    }

    Process {
        id: colorPicker
        command: ["sh", "-c", "sleep 0.08; exec hyprpicker -a"]
    }

    Timer {
        id: delay
        interval: 70
        onTriggered: {
            if (capture.output !== null)
                freeze.exec(["sh", capture.script, "freeze", capture.output.name]);
            else
                capture.pending = false;
        }
    }

    Process {
        id: freeze
        stdout: StdioCollector { id: frame }

        onExited: exitCode => {
            const folder = frame.text.trim();
            if (exitCode === 0 && folder && capture.pending && capture.output !== null) {
                capture.directory = folder;
                if (capture.mode === "full")
                    capture.finish("", capture.defaultAction);
                else
                    capture.open = true;
            } else if (folder) {
                Quickshell.execDetached(["sh", capture.script, "discard", folder]);
            }
            capture.pending = false;
        }
    }
}
