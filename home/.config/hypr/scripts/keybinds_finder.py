#!/usr/bin/env python3
import os
import re
import json
import sys
import subprocess
import shutil

# Paths
HOME = os.path.expanduser("~")
KEYBINDS_CONF = os.path.join(HOME, ".config/hypr/configs/keybinds.conf")
USER_OVERRIDES_CONF = os.path.join(HOME, ".config/hypr/configs/user-overrides.conf")
MANUAL_BINDS_JSON = os.path.join(HOME, ".config/noctalia/manual-keybinds.json")
USER_BINDS_JSON = os.path.join(HOME, ".config/noctalia/user-keybinds.json")
TERMINAL_COMMANDS_JSON = os.path.join(HOME, ".config/noctalia/terminal-commands.json")

variables = {}

def parse_variables(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if line.startswith('#') or not line:
                continue
            m = re.match(r'^\s*(\$[a-zA-Z0-9_]+)\s*=\s*(.+)$', line)
            if m:
                var_name = m.group(1)
                var_val = m.group(2).strip()
                if '#' in var_val:
                    var_val = var_val.split('#', 1)[0].strip()
                variables[var_name] = var_val

def resolve_variables(text):
    for _ in range(5):
        changed = False
        for var_name, var_val in list(variables.items()):
            if var_name in text:
                text = text.replace(var_name, var_val)
                changed = True
        if not changed:
            break
    return text

friendly_keys = {
    "XF86AudioRaiseVolume": "Volume Up",
    "XF86AudioLowerVolume": "Volume Down",
    "XF86AudioMute": "Mute",
    "XF86MonBrightnessUp": "Brightness Up",
    "XF86MonBrightnessDown": "Brightness Down",
    "PRINT": "PrintScreen",
    "grave": "`",
    "slash": "/",
    "period": ".",
    "Return": "Enter",
    "left": "Left",
    "right": "Right",
    "up": "Up",
    "down": "Down"
}

def format_keys(mod, key):
    mod = resolve_variables(mod).strip()
    key = resolve_variables(key).strip()

    mod = mod.upper()
    mod_parts = []
    if "SUPER" in mod or "WIN" in mod or "MOD" in mod:
        mod_parts.append("Super")
    if "CTRL" in mod or "CONTROL" in mod:
        mod_parts.append("Ctrl")
    if "ALT" in mod:
        mod_parts.append("Alt")
    if "SHIFT" in mod:
        mod_parts.append("Shift")

    key_friendly = friendly_keys.get(key, key)
    if len(key_friendly) > 1 and key_friendly[0].islower():
        key_friendly = key_friendly.capitalize()

    if mod_parts:
        return " + ".join(mod_parts) + " + " + key_friendly
    else:
        return key_friendly

def translate_action(dispatcher, args):
    dispatcher = dispatcher.strip()
    args = args.strip()
    act = f"{dispatcher} {args}".strip()

    if "killactive" in act:
        if "1" in act:
            return "Force Close Window", "Force closes the active window by sending SIGKILL."
        else:
            return "Close Window", "Closes the active window gracefully."
    elif act == "togglefloating":
        return "Toggle Floating Mode", "Toggles the active window between floating and tiled mode."
    elif act == "pseudo":
        return "Toggle Pseudo Tiling", "Toggles pseudotiling for the active window."
    elif "togglesplit" in act:
        return "Toggle Split Layout Direction", "Toggles between vertical and horizontal splitting layout."
    elif "fullscreen" in act:
        if "1" in act:
            return "Toggle Fullscreen (Keep Status Bar)", "Toggles fullscreen mode while keeping status bar."
        else:
            return "Toggle Fullscreen Mode", "Toggles true fullscreen mode for the active window."
    elif "togglespecialworkspace" in act:
        return "Toggle Special Workspace (Scratchpad)", "Toggles the visibility of the scratchpad."
    elif "movetoworkspace" in act and "special" in act:
        return "Move Active Window to Special Workspace", "Moves window to special scratchpad workspace."
    elif act == "pin":
        return "Pin Window (Always on Top)", "Pins the active window to remain visible across all workspaces."
    elif act == "togglegroup":
        return "Toggle Window Grouping", "Toggles grouping/ungrouping of the active window."
    elif "lockactivegroup" in act:
        return "Lock/Unlock Active Group", "Locks or unlocks the active window tab group."
    elif "changegroupactive" in act:
        if ", f" in act or ",f" in act:
            return "Next Tab in Group", "Switches focus to next window/tab in the active group."
        else:
            return "Previous Tab in Group", "Switches focus to previous window/tab in active group."
    elif "moveintogroup" in act:
        if ", l" in act or ",l" in act:
            return "Merge Group Left", "Merges the active window into the group to the left."
        elif ", r" in act or ",r" in act:
            return "Merge Group Right", "Merges the active window into the group to the right."
        elif ", u" in act or ",u" in act:
            return "Merge Group Up", "Merges the active window into the group above."
        else:
            return "Merge Group Down", "Merges the active window into the group below."
    elif act == "moveoutofgroup":
        return "Remove Window from Group", "Removes active window from current group."
    elif "$terminal" in act or "kitty" in act:
        return "Launch Terminal", "Opens a new terminal instance."
    elif "$fileManager" in act or "nautilus" in act:
        return "Launch File Manager", "Opens the Nautilus file manager."
    elif "$menu" in act or "fuzzel" in act:
        return "Launch App Launcher", "Opens the application launcher."
    elif "$altMenu" in act or "rofi" in act:
        return "Launch Desktop Overview Launcher", "Opens the application overview."
    elif "$browser" in act or "brave" in act:
        return "Launch Web Browser", "Opens the Brave web browser."
    elif "lockScreen" in act or "hyprlock" in act:
        return "Lock Screen", "Locks the session immediately."
    elif "hyprpicker" in act:
        return "Launch Color Picker", "Runs color picker tool to copy hex to clipboard."
    elif "wallcards" in act or "wallpaper" in act:
        return "Wallpaper Controls", "Wallpaper panel / switcher."
    elif "HyprQuickFrame" in act or "screenshot" in act:
        return "Take Screenshot", "Invokes screenshot utility."
    elif "screen-toolkit" in act:
        return "Launch Screen Annotation Tool", "Opens screen annotation tool."
    elif "ocr" in act:
        return "OCR Screenshot", "Captures a region, performs OCR, and copies text."
    elif "launcher clipboard" in act or "cliphist" in act:
        return "Open Clipboard History", "Opens clipboard history manager."
    elif "launcher emoji" in act:
        return "Open Emoji Picker", "Opens emoji selection launcher."
    elif "sessionMenu" in act:
        return "Open Power/Session Menu", "Opens log out/suspend/shutdown session menu."
    elif "bar toggle" in act:
        return "Toggle Status Bar Visibility", "Toggles status bar visibility."
    elif "volume increase" in act or "volume-up" in act:
        return "Increase Audio Volume", "Raises audio output volume."
    elif "volume decrease" in act or "volume-down" in act:
        return "Decrease Audio Volume", "Lowers audio output volume."
    elif "volume muteOutput" in act or "volume-mute" in act:
        return "Mute/Unmute Audio", "Mutes or unmutes system audio."
    elif "brightness increase" in act:
        return "Increase Screen Brightness", "Raises screen backlight brightness."
    elif "brightness decrease" in act:
        return "Decrease Screen Brightness", "Lowers screen backlight brightness."
    elif "movefocus" in act:
        if ", u" in act or ",u" in act:
            return "Focus Window Up", "Moves window focus upwards."
        elif ", r" in act or ",r" in act:
            return "Focus Window Right", "Moves window focus to the right."
        elif ", l" in act or ",l" in act:
            return "Focus Window Left", "Moves window focus to the left."
        else:
            return "Focus Window Down", "Moves window focus downwards."
    elif "resizeactive" in act:
        return "Resize Active Window", "Adjusts the dimensions of the active window."
    elif "movewindow" in act:
        return "Move Active Window", "Moves the active window position."
    elif "workspace" in act:
        m = re.search(r'\d+', act)
        if m:
            return f"Switch to Workspace {m.group(0)}", f"Switches active workspace to workspace {m.group(0)}."
        return "Switch Workspace", "Switches the active workspace."
    elif "movetoworkspace" in act:
        m = re.search(r'\d+', act)
        if m:
            return f"Move Window to Workspace {m.group(0)}", f"Moves active window to workspace {m.group(0)}."
        return "Move Window to Workspace", "Moves active window to another workspace."
    elif "show_binds" in act or "keybinds" in act:
        return "Search / Show Keybindings", "Opens this keybindings finder."
    else:
        return act, f"Dispatcher: {act}"

def parse_keybinds_file(file_path):
    binds = []
    if not os.path.exists(file_path):
        return binds
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line.startswith("bind"):
                continue
            if '=' not in line:
                continue
            parts_str = line.split("=", 1)[1].strip()

            description = ""
            if '#' in parts_str:
                parts_str, comment = parts_str.split('#', 1)
                parts_str = parts_str.strip()
                comment = comment.strip()
                if (comment.startswith('"') and comment.endswith('"')) or (comment.startswith("'") and comment.endswith("'")):
                    description = comment[1:-1].strip()
                else:
                    description = comment

            fields = [f.strip() for f in parts_str.split(',')]
            if len(fields) < 3:
                continue

            mod = fields[0]
            key = fields[1]
            dispatcher = fields[2]
            args = ",".join(fields[3:]) if len(fields) > 3 else ""

            formatted_keys = format_keys(mod, key)
            trans_desc, trans_exp = translate_action(dispatcher, args)
            if description:
                trans_desc = description

            binds.append({
                "keys": formatted_keys,
                "desc": trans_desc,
                "explanation": trans_exp,
                "command": f"{dispatcher} {args}".strip()
            })
    return binds

def load_json_binds(path):
    if os.path.exists(path):
        try:
            with open(path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            pass
    return []

def notify(summary, body=""):
    # Try Noctalia native notification first
    try:
        subprocess.run(["noctalia", "msg", "notification-show", summary, body], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    except Exception:
        pass
    # Fallback to notify-send
    try:
        subprocess.run(["notify-send", summary, body], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def main():
    parse_variables(KEYBINDS_CONF)
    parse_variables(USER_OVERRIDES_CONF)

    config_binds = []
    config_binds.extend(parse_keybinds_file(KEYBINDS_CONF))
    config_binds.extend(parse_keybinds_file(USER_OVERRIDES_CONF))

    seen_keys = set()
    manual_binds = load_json_binds(MANUAL_BINDS_JSON)
    user_binds = load_json_binds(USER_BINDS_JSON)
    terminal_commands = load_json_binds(TERMINAL_COMMANDS_JSON)

    items = []

    # Manual Binds
    for b in manual_binds:
        k = b.get("keys", "").strip()
        desc = b.get("desc", "").strip()
        if k and k not in seen_keys:
            seen_keys.add(k)
            items.append((k, desc, "User", b.get("command", "")))

    # User Binds
    for b in user_binds:
        k = b.get("keys", "").strip()
        desc = b.get("desc", "").strip()
        if k and k not in seen_keys:
            seen_keys.add(k)
            items.append((k, desc, "Custom", b.get("command", "")))

    # Config Binds
    for b in config_binds:
        k = b.get("keys", "").strip()
        desc = b.get("desc", "").strip()
        if k and k not in seen_keys:
            seen_keys.add(k)
            items.append((k, desc, "Hyprland", b.get("command", "")))

    # Terminal Commands
    for b in terminal_commands:
        k = b.get("keys", b.get("command", "")).strip()
        desc = b.get("desc", "").strip()
        if k and k not in seen_keys:
            seen_keys.add(k)
            items.append((k, desc, "Terminal", b.get("command", "")))

    # Format lines for dmenu
    lines = []
    line_map = {}
    for k, desc, section, cmd in items:
        # Format: Keys (left aligned) │ Description (middle aligned) │ Section
        display_line = f"{k:<26} │ {desc:<38} │ [{section}]"
        lines.append(display_line)
        line_map[display_line] = (k, desc, cmd)

    menu_payload = "\n".join(lines)

    selected = None
    # 1. Try Noctalia Dmenu
    if shutil.which("noctalia"):
        try:
            proc = subprocess.run(
                ["noctalia", "dmenu", "-p", "Search Keybinds"],
                input=menu_payload,
                capture_output=True,
                text=True,
                check=False
            )
            if proc.returncode == 0 and proc.stdout.strip():
                selected = proc.stdout.strip()
        except Exception:
            pass

    # 2. Fallback to fuzzel if noctalia dmenu didn't return a selection
    if not selected and shutil.which("fuzzel"):
        try:
            proc = subprocess.run(
                ["fuzzel", "--dmenu", "-p", "Keybinds: ", "--width", "75"],
                input=menu_payload,
                capture_output=True,
                text=True,
                check=False
            )
            if proc.returncode == 0 and proc.stdout.strip():
                selected = proc.stdout.strip()
        except Exception:
            pass

    if not selected:
        return

    # User selected an item!
    entry_info = line_map.get(selected)
    if entry_info:
        k, desc, cmd = entry_info
    else:
        parts = [p.strip() for p in selected.split("│")]
        k = parts[0] if parts else selected
        desc = parts[1] if len(parts) > 1 else ""

    # Copy keys to clipboard
    try:
        subprocess.run(["wl-copy", k], check=True)
        notify("Shortcut Copied to Clipboard", f"{k} ({desc})")
    except Exception:
        pass

if __name__ == "__main__":
    main()
