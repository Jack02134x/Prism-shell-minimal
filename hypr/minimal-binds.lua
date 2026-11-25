-- Load after your main binds. Start the shell with `qs --no-duplicate`.
local function bind(key, target, command)
    hl.unbind(key)
    hl.bind(key, hl.dsp.exec_cmd("qs ipc call " .. target .. " " .. command))
end

bind("SUPER + S", "launcher", "toggle")
bind("SUPER + SHIFT + TAB", "switcher", "toggle")
bind("SUPER + O", "overview", "toggle")
bind("SUPER + V", "clipboard", "toggle")
bind("SUPER + Space", "minimal", "openMode commands")
bind("SUPER + L", "lock", "lock")

bind("SUPER + N", "notifications", "toggle")
