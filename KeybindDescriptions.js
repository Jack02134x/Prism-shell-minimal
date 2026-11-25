.pragma library

const ipcActions = {
    "launcher toggle": "Launch apps",
    "switcher toggle": "Switch windows",
    "overview toggle": "Choose a workspace",
    "clipboard toggle": "Browse clipboard history",
    "wallpaper toggle": "Choose a wallpaper",
    "screenshot menu": "Open screenshot controls",
    "controls toggle": "Open quick controls",
    "dashboard toggle": "Open Settings, Networks and Audio",
    "cheatsheet toggle": "View keyboard shortcuts",
    "edit toggle": "Open a config folder",
    "emoji toggle": "Find an emoji",
    "sidebar toggle": "Open calendar",
    "clock toggle": "Open clocks",
    "power toggle": "Open power actions",
    "lock lock": "Lock the screen",
    "osd volumeUp": "Raise volume"
};

function keyId(shortcut) {
    const parts = shortcut.toLowerCase().split("+").map(part => part.trim());
    const key = parts.pop();
    const aliases = { ".": "period", "/": "slash", esc: "escape", control: "ctrl", mod4: "super", mod1: "alt" };
    return [...parts.map(part => aliases[part] ?? part).sort(), aliases[key] ?? key].join("+");
}

function commandLabel(command) {
    const ipc = /^qs\s+ipc\s+call\s+(.+)$/.exec(command);
    return ipc ? (ipcActions[ipc[1]] ?? command) : command;
}

function fromSource(source) {
    const variables = new Map();
    const commands = new Map();
    for (const line of source.split("\n")) {
        const assignment = /^\s*local\s+(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"/.exec(line);
        if (assignment)
            variables.set(assignment[1], assignment[2]);

        const bind = /^\s*hl\.bind\(([^,]+),\s*hl\.dsp\.exec_cmd\(\s*(?:"((?:[^"\\]|\\.)*)"|(\w+))/.exec(line);
        if (!bind)
            continue;

        const key = bind[1];
        const prefix = /^\s*(\w+)\s*\.\./.exec(key);
        const literals = (key.match(/"[^"]*"/g) ?? []).map(part => part.slice(1, -1)).join("");
        const shortcut = (prefix ? variables.get(prefix[1]) ?? "" : "") + literals;
        const command = bind[2] ?? variables.get(bind[3]);
        if (shortcut && command)
            commands.set(keyId(shortcut), commandLabel(command));
    }
    return commands;
}

function describe(binding, chords, commands) {
    if (binding.description)
        return binding.description;

    if (binding.dispatcher === "HL.Dispatcher(exec_cmd)")
        return commands.get(keyId(chords)) ?? "Run command";

    const action = binding.dispatcher?.replace(/^HL\.Dispatcher\((.*)\)$/, "$1").replace(/[_\.]/g, " ") ?? "";
    if (!action)
        return "Hyprland action";

    const argument = binding.arg && !/^\d+$/.test(binding.arg) ? " · " + binding.arg : "";
    return action[0].toUpperCase() + action.slice(1) + argument;
}
