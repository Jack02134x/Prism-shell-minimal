pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.common

// Small system toggles: caffeine, study noise, glava, game mode, screen
// recording, warm screen.
Singleton {
    id: root

    // ---- caffeine (the IdleInhibitor lives in the bar window) ----
    property bool caffeine: false
    function toggleCaffeine() {
        caffeine = !caffeine;
        Osd.show("toggle", caffeine ? "coffee" : "coffee_outline", caffeine ? "Caffeine on · staying awake" : "Caffeine off", -1);
    }

    // ---- study noise (ffplay, no window) ----
    readonly property var noiseKinds: ["off", "brown", "pink", "white"]
    property string noise: "off"
    property real noiseVolume: 0.35
    function cycleNoise() {
        const i = noiseKinds.indexOf(noise);
        setNoise(noiseKinds[(i + 1) % noiseKinds.length]);
    }
    function setNoise(kind) {
        noise = kind;
        Osd.show("toggle", kind === "off" ? "volume_off" : "waves", kind === "off" ? "Noise off" : Utils.capitalize(kind) + " noise", -1);
    }
    Process {
        running: root.noise !== "off"
        command: ["ffplay", "-nodisp", "-loglevel", "quiet", "-f", "lavfi", "-i", "anoisesrc=c=" + root.noise + ":a=" + root.noiseVolume.toFixed(2)]
    }

    // ---- EasyEffects: on = running in the background, off = fully killed ----
    // state comes from PipeWire (its virtual sink exists only while it runs)
    readonly property bool easyEffects: (Pipewire.nodes?.values ?? []).some(n => n?.name === "easyeffects_sink")
    function toggleEasyEffects() {
        if (easyEffects) {
            Quickshell.execDetached(["sh", "-c", "easyeffects -q; sleep 2; pkill -x easyeffects; pkill -f '^easyeffects'"]);
            Osd.show("toggle", "tune_variant", "EasyEffects off", -1);
        } else {
            Quickshell.execDetached(["sh", "-c", "setsid -f easyeffects -w >/dev/null 2>&1"]);
            Osd.show("toggle", "tune_variant", "EasyEffects on", -1);
        }
    }

    // ---- glava visualizer ----
    property bool glava: false
    function toggleGlava() {
        if (glava) {
            Quickshell.execDetached(["pkill", "glava"]);
            glava = false;
        } else {
            Quickshell.execDetached(["sh", "-c", "pkill glava; exec glava"]);
            glava = true;
        }
    }

    // ---- game mode: strip Hyprland eye-candy + pause ambient effects ----
    property bool gameMode: false
    onGameModeChanged: Motion.calm = gameMode
    function toggleGameMode() {
        gameMode = !gameMode;
        if (gameMode)
            Hypr.evalLua("hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0, dim_inactive = false }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })");
        else
            Quickshell.execDetached(["hyprctl", "reload"]);
        Osd.show("toggle", "gamepad_variant", gameMode ? "Game mode on" : "Game mode off", -1);
    }

    // ---- warm screen (overlay tint; there is no hyprsunset here) ----
    property bool warm: false
    property real warmStrength: 0.16
    function toggleWarm() {
        warm = !warm;
        Osd.show("toggle", "weather_night", warm ? "Warm screen on" : "Warm screen off", -1);
    }

    // ---- screen recording (wf-recorder) ----
    property bool recording: false
    property bool recordSelecting: false
    property bool recordAudio: false
    property string recordFile: ""
    property real recordStart: 0
    property bool recordHasStarted: false
    property bool stopRequested: false

    Process {
        id: rec
        stdout: SplitParser {
            onRead: line => {
                if (line === "PRISM_RECORD_STARTED") {
                    root.recordHasStarted = true;
                    root.recordSelecting = false;
                    root.recordStart = Date.now();
                }
            }
        }
        stderr: StdioCollector { id: recordErrors }
        onExited: code => {
            const output = root.recordFile;
            root.recording = false;
            root.recordSelecting = false;
            if (code === 0 && root.recordHasStarted) {
                Notifs.local("Recording saved", output, "video", 1, "", [
                    { text: "Open folder", run: () => Quickshell.execDetached(["xdg-open", Config.paths.recordings]) },
                    { text: "Play", run: () => Quickshell.execDetached(["xdg-open", output]) }
                ]);
            } else if (!root.stopRequested && code !== 2) {
                const details = recordErrors.text.trim().split("\n").filter(line => line).slice(-1)[0];
                Notifs.local("Recording failed", details || "Check that wf-recorder is installed.", "video", 1);
            }
        }
    }

    function startRecording(mode) {
        if (recording)
            return;
        if (mode === true)
            mode = "region";
        else if (mode === false || mode === undefined)
            mode = "full";

        Panels.closeAll();
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss-zzz");
        recordFile = Config.paths.recordings + "/recording_" + ts + ".mp4";
        const monitor = Hypr.focusedWorkspace?.monitor?.name ?? "";
        recording = true;
        recordSelecting = mode === "region";
        recordStart = Date.now();
        recordHasStarted = false;
        stopRequested = false;
        rec.exec(["sh", Config.shellDir + "/scripts/record.sh", mode, recordFile, monitor, recordAudio ? "audio" : "silent"]);
    }

    function stopRecording() {
        if (recording) {
            stopRequested = true;
            rec.signal(15);
        }
    }
    function toggleRecording() {
        if (recording)
            stopRecording();
        else
            Panels.show("record");
    }

    Process {
        running: true
        command: ["pgrep", "-x", "glava"]
        onExited: code => root.glava = code === 0
    }
}
