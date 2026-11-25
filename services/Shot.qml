pragma Singleton

import Quickshell

Singleton {
    signal requested(string mode, string action, real delay)
    signal cancelled()

    function capture(mode: string, action: string, delay: real): void {
        requested(mode, action, delay);
    }

    function pickColor(): void {
        requested("color", "both", 0);
    }

    function cancel(): void {
        cancelled();
    }
}
