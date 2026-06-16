#!/usr/bin/env python3
import os
import re
import json
import sys

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
            # Match variable definition: $name = value
            m = re.match(r'^\s*(\$[a-zA-Z0-9_]+)\s*=\s*(.+)$', line)
            if m:
                var_name = m.group(1)
                var_val = m.group(2).strip()
                # Remove trailing comments from variable value
                if '#' in var_val:
                    var_val = var_val.split('#', 1)[0].strip()
                variables[var_name] = var_val

def resolve_variables(text):
    for _ in range(5): # Limit recursion
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

    # Standardize modifier names
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

    # Standardize main key name
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
            return "Toggle Fullscreen (Keep Status Bar)", "Toggles fullscreen mode while keeping the top status bar visible."
        else:
            return "Toggle Fullscreen Mode", "Toggles true fullscreen mode for the active window."
    elif "togglespecialworkspace" in act:
        return "Toggle Special Workspace (Scratchpad)", "Toggles the visibility of the special scratchpad workspace."
    elif "movetoworkspace" in act and "special" in act:
        return "Move Active Window to Special Workspace", "Moves the currently active window to the special scratchpad workspace."
    elif act == "pin":
        return "Pin Window (Always on Top)", "Pins the active window to remain visible across all workspaces."
    elif act == "togglegroup":
        return "Toggle Window Grouping", "Toggles grouping/ungrouping of the active window."
    elif "lockactivegroup" in act:
        return "Lock/Unlock Active Group", "Locks or unlocks the active window tab group."
    elif "changegroupactive" in act:
        if ", f" in act or ",f" in act:
            return "Next Tab in Group", "Switches focus to the next window/tab in the active group."
        else:
            return "Previous Tab in Group", "Switches focus to the previous window/tab in the active group."
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
        return "Remove Window from Group", "Removes the active window from its current group."
    elif "$terminal" in act or "kitty" in act:
        return "Launch Terminal", "Opens a new kitty terminal instance."
    elif "$fileManager" in act or "nautilus" in act:
        return "Launch File Manager", "Opens the Nautilus file manager."
    elif "$menu" in act or "fuzzel" in act:
        return "Launch App Launcher (Fuzzel)", "Opens the Fuzzel application launcher."
    elif "$altMenu" in act or "rofi" in act:
        return "Launch Desktop Overview Launcher", "Opens the Rofi application overview."
    elif "$browser" in act or "brave" in act:
        return "Launch Web Browser (Brave)", "Opens the Brave web browser."
    elif "lockScreen" in act:
        return "Lock Screen", "Locks the session immediately."
    elif "hyprpicker" in act:
        return "Launch Color Picker (Hyprpicker)", "Runs the color picker tool to copy color hex to clipboard."
    elif "wallcards" in act:
        return "Toggle Wallpaper Selector", "Opens the Wallcards menu to change wallpapers."
    elif "HyprQuickFrame" in act:
        return "Take Screenshot (Select Region)", "Invokes HyprQuickFrame region screenshot tool."
    elif "screen-toolkit" in act:
        return "Launch Screen Annotation Tool", "Opens the screen annotation tool for presentation/drawing."
    elif "ocr" in act:
        return "OCR Screenshot (Screen Text to Clipboard)", "Captures a region, performs OCR, and copies text to clipboard."
    elif "launcher clipboard" in act:
        return "Open Clipboard History", "Opens the Noctalia clipboard history launcher."
    elif "cliphist wipe" in act:
        return "Clear Clipboard History", "Deletes all items from clipboard history."
    elif "launcher emoji" in act:
        return "Open Emoji Picker", "Opens the Noctalia emoji selection launcher."
    elif "sessionMenu" in act:
        return "Open Power/Session Menu", "Opens the log out/suspend/shutdown session menu."
    elif "bar toggle" in act:
        return "Toggle Top Status Bar Visibility", "Toggles the top status bar hide/show state."
    elif "volume increase" in act:
        return "Increase Audio Volume", "Raises system audio output volume."
    elif "volume decrease" in act:
        return "Decrease Audio Volume", "Lowers system audio output volume."
    elif "volume muteOutput" in act:
        return "Mute/Unmute Audio Output", "Mutes or unmutes system audio output."
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
        if "-70 0" in act:
            return "Shrink Window Horizontally", "Decreases the active window width."
        elif "70 0" in act:
            return "Expand Window Horizontally", "Increases the active window width."
        elif "0 -70" in act:
            return "Shrink Window Vertically", "Decreases the active window height."
        else:
            return "Expand Window Vertically", "Increases the active window height."
    elif "movewindow" in act:
        if ", u" in act or ",u" in act:
            return "Move Window Up", "Moves the active window upwards."
        elif ", r" in act or ",r" in act:
            return "Move Window Right", "Moves the active window to the right."
        elif ", l" in act or ",l" in act:
            return "Move Window Left", "Moves the active window to the left."
        else:
            return "Move Window Down", "Moves the active window downwards."
    elif "workspace" in act:
        m = re.search(r'\d+', act)
        if m:
            num = m.group(0)
            return f"Switch to Workspace {num}", f"Switches the active workspace to workspace {num}."
        else:
            return "Switch Workspace", "Switches the active workspace."
    elif "movetoworkspacesilent" in act:
        m = re.search(r'\d+', act)
        if m:
            num = m.group(0)
            return f"Move Window to Workspace {num} (Silently)", f"Moves the active window to workspace {num} without switching focus."
        else:
            return "Move Window Silently", "Moves the active window to another workspace silently."
    elif "movetoworkspace" in act:
        m = re.search(r'\d+', act)
        if m:
            num = m.group(0)
            return f"Move Active Window to Workspace {num}", f"Moves the active window to workspace {num} and switches focus."
        else:
            return "Move Window to Workspace", "Moves the active window to another workspace."
    elif "overview toggle" in act:
        return "Toggle Desktop Overview", "Toggles the workspaces grid overview overlay."
    elif "show_binds.sh" in act or "keybinds-viewer" in act:
        return "Search/Show Keybindings", "Opens this keybindings cheatsheet viewer."
    elif "dpms off" in act:
        return "Lock & Sleep System (Lid Close)", "Turns off the display and locks the session."
    elif "dpms on" in act:
        return "Wake Display (Lid Open)", "Turns on the display."
    elif "toggle-anim" in act:
        return "Toggle Desktop Animations", "Enables or disables Hyprland desktop window animations."
    else:
        return act, f"Executes compositor dispatcher: {act}"

def parse_keybinds_file(file_path):
    binds = []
    if not os.path.exists(file_path):
        return binds
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            # Must start with bind
            if not line.startswith("bind"):
                continue
            
            # Extract everything after the '='
            if '=' not in line:
                continue
            parts_str = line.split("=", 1)[1].strip()

            # Split by '#' to get the description comment if any
            description = ""
            if '#' in parts_str:
                parts_str, comment = parts_str.split('#', 1)
                parts_str = parts_str.strip()
                comment = comment.strip()
                # Strip quotes if any
                if (comment.startswith('"') and comment.endswith('"')) or (comment.startswith("'") and comment.endswith("'")):
                    description = comment[1:-1].strip()
                else:
                    description = comment

            # Now parse the CSV fields
            fields = [f.strip() for f in parts_str.split(',')]
            if len(fields) < 3:
                continue

            mod = fields[0]
            key = fields[1]
            dispatcher = fields[2]
            args = ",".join(fields[3:]) if len(fields) > 3 else ""

            formatted_keys = format_keys(mod, key)
            
            # Get default translation
            trans_desc, trans_exp = translate_action(dispatcher, args)
            
            # If a custom comment was provided, use it for desc
            if description:
                trans_desc = description

            binds.append({
                "keys": formatted_keys,
                "desc": trans_desc,
                "explanation": trans_exp,
                "command": f"{dispatcher} {args}".strip()
            })
    return binds

def main():
    # First parse variable definitions from both config files
    parse_variables(KEYBINDS_CONF)
    parse_variables(USER_OVERRIDES_CONF)

    # Parse binds from config files
    config_binds = []
    config_binds.extend(parse_keybinds_file(KEYBINDS_CONF))
    config_binds.extend(parse_keybinds_file(USER_OVERRIDES_CONF))

    # Remove duplicates from config_binds
    seen = set()
    unique_config_binds = []
    for b in config_binds:
        key = (b["keys"], b["command"])
        if key not in seen:
            seen.add(key)
            unique_config_binds.append(b)

    # Load manual binds
    manual_binds = []
    if os.path.exists(MANUAL_BINDS_JSON):
        try:
            with open(MANUAL_BINDS_JSON, 'r', encoding='utf-8') as f:
                manual_binds = json.load(f)
        except Exception as e:
            pass

    # Load user binds
    user_binds = []
    if os.path.exists(USER_BINDS_JSON):
        try:
            with open(USER_BINDS_JSON, 'r', encoding='utf-8') as f:
                user_binds = json.load(f)
        except Exception as e:
            pass

    # Load terminal commands
    terminal_commands = []
    if os.path.exists(TERMINAL_COMMANDS_JSON):
        try:
            with open(TERMINAL_COMMANDS_JSON, 'r', encoding='utf-8') as f:
                terminal_commands = json.load(f)
        except Exception as e:
            pass

    # Tag binds and commands to distinguish them in QML
    for b in unique_config_binds:
        b["is_cmd"] = False
    for b in manual_binds:
        b["is_cmd"] = False
    for b in user_binds:
        b["is_cmd"] = False
    for b in terminal_commands:
        b["is_cmd"] = True

    # Group into sections
    output = []
    if unique_config_binds:
        output.append({
            "section": "Active Config Binds",
            "binds": unique_config_binds
        })
    if manual_binds:
        output.append({
            "section": "User Manual Binds",
            "binds": manual_binds
        })
    if user_binds:
        output.append({
            "section": "Custom Commands",
            "binds": user_binds
        })
    if terminal_commands:
        output.append({
            "section": "Terminal Commands",
            "binds": terminal_commands
        })

    print(json.dumps(output, indent=2))

if __name__ == "__main__":
    main()
