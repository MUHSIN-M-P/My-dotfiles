#!/bin/bash
# Extract bind lines, format them and pipe to fuzzel -d

translate_action() {
    local act="$1"
    act=$(echo "$act" | sed "s/,\s*$//g" | xargs)
    
    if [[ "$act" == *"killactive"* ]]; then
        if [[ "$act" == *"1"* ]]; then
            echo "Force Close Window"
        else
            echo "Close Window"
        fi
    elif [[ "$act" == "togglefloating" ]]; then
        echo "Toggle Floating Mode"
    elif [[ "$act" == "pseudo" ]]; then
        echo "Toggle Pseudo Tiling"
    elif [[ "$act" == *"togglesplit"* ]]; then
        echo "Toggle Split Layout Direction"
    elif [[ "$act" == *"fullscreen"* ]]; then
        if [[ "$act" == *"1"* ]]; then
            echo "Toggle Fullscreen (Keep Status Bar)"
        else
            echo "Toggle Fullscreen Mode"
        fi
    elif [[ "$act" == *"togglespecialworkspace"* ]]; then
        echo "Toggle Special Workspace (Scratchpad)"
    elif [[ "$act" == *"movetoworkspace"* && "$act" == *"special"* ]]; then
        echo "Move Active Window to Special Workspace"
    elif [[ "$act" == "pin" ]]; then
        echo "Pin Window (Always on Top)"
    elif [[ "$act" == "togglegroup" ]]; then
        echo "Toggle Window Grouping"
    elif [[ "$act" == *"lockactivegroup"* ]]; then
        echo "Lock/Unlock Active Group"
    elif [[ "$act" == *"changegroupactive"* ]]; then
        if [[ "$act" == *", f" || "$act" == *",f" ]]; then
            echo "Next Tab in Group"
        else
            echo "Previous Tab in Group"
        fi
    elif [[ "$act" == *"moveintogroup"* ]]; then
        if [[ "$act" == *", l" || "$act" == *",l" ]]; then
            echo "Merge Group Left"
        elif [[ "$act" == *", r" || "$act" == *",r" ]]; then
            echo "Merge Group Right"
        elif [[ "$act" == *", u" || "$act" == *",u" ]]; then
            echo "Merge Group Up"
        else
            echo "Merge Group Down"
        fi
    elif [[ "$act" == "moveoutofgroup" ]]; then
        echo "Remove Window from Group"
    elif [[ "$act" == *"\$terminal"* ]]; then
        echo "Launch Terminal"
    elif [[ "$act" == *"\$fileManager"* ]]; then
        echo "Launch File Manager"
    elif [[ "$act" == *"\$menu"* ]]; then
        echo "Launch App Launcher (Fuzzel)"
    elif [[ "$act" == *"\$altMenu"* ]]; then
        echo "Launch Desktop Overview Launcher"
    elif [[ "$act" == *"\$browser"* ]]; then
        echo "Launch Web Browser (Brave)"
    elif [[ "$act" == *"lockScreen"* ]]; then
        echo "Lock Screen"
    elif [[ "$act" == *"hyprpicker"* ]]; then
        echo "Launch Color Picker (Hyprpicker)"
    elif [[ "$act" == *"wallcards"* ]]; then
        echo "Toggle Wallpaper Selector"
    elif [[ "$act" == *"HyprQuickFrame"* ]]; then
        echo "Take Screenshot (Select Region)"
    elif [[ "$act" == *"screen-toolkit"* ]]; then
        echo "Launch Screen Annotation Tool"
    elif [[ "$act" == *"ocr"* ]]; then
        echo "OCR Screenshot (Screen Text to Clipboard)"
    elif [[ "$act" == *"launcher clipboard"* ]]; then
        echo "Open Clipboard History"
    elif [[ "$act" == *"cliphist wipe"* ]]; then
        echo "Clear Clipboard History"
    elif [[ "$act" == *"launcher emoji"* ]]; then
        echo "Open Emoji Picker"
    elif [[ "$act" == *"sessionMenu"* ]]; then
        echo "Open Power/Session Menu"
    elif [[ "$act" == *"bar toggle"* ]]; then
        echo "Toggle Top Status Bar Visibility"
    elif [[ "$act" == *"volume increase"* ]]; then
        echo "Increase Audio Volume"
    elif [[ "$act" == *"volume decrease"* ]]; then
        echo "Decrease Audio Volume"
    elif [[ "$act" == *"volume muteOutput"* ]]; then
        echo "Mute/Unmute Audio Output"
    elif [[ "$act" == *"brightness increase"* ]]; then
        echo "Increase Screen Brightness"
    elif [[ "$act" == *"brightness decrease"* ]]; then
        echo "Decrease Screen Brightness"
    elif [[ "$act" == *"movefocus"* ]]; then
        if [[ "$act" == *", u" || "$act" == *",u" ]]; then
            echo "Focus Window Up"
        elif [[ "$act" == *", r" || "$act" == *",r" ]]; then
            echo "Focus Window Right"
        elif [[ "$act" == *", l" || "$act" == *",l" ]]; then
            echo "Focus Window Left"
        else
            echo "Focus Window Down"
        fi
    elif [[ "$act" == *"resizeactive"* ]]; then
        if [[ "$act" == *"-70 0"* ]]; then
            echo "Shrink Window Horizontally"
        elif [[ "$act" == *"70 0"* ]]; then
            echo "Expand Window Horizontally"
        elif [[ "$act" == *"0 -70"* ]]; then
            echo "Shrink Window Vertically"
        else
            echo "Expand Window Vertically"
        fi
    elif [[ "$act" == *"movewindow"* ]]; then
        if [[ "$act" == *", u" || "$act" == *",u" ]]; then
            echo "Move Window Up"
        elif [[ "$act" == *", r" || "$act" == *",r" ]]; then
            echo "Move Window Right"
        elif [[ "$act" == *", l" || "$act" == *",l" ]]; then
            echo "Move Window Left"
        else
            echo "Move Window Down"
        fi
    elif [[ "$act" =~ ^workspace,\ ([0-9]+)$ || "$act" =~ ^workspace\ ([0-9]+)$ ]]; then
        echo "Switch to Workspace ${BASH_REMATCH[1]}"
    elif [[ "$act" =~ ^movetoworkspace,\ ([0-9]+)$ || "$act" =~ ^movetoworkspace\ ([0-9]+)$ ]]; then
        echo "Move Active Window to Workspace ${BASH_REMATCH[1]}"
    elif [[ "$act" =~ ^movetoworkspacesilent,\ ([0-9]+)$ || "$act" =~ ^movetoworkspacesilent\ ([0-9]+)$ ]]; then
        echo "Move Window to Workspace ${BASH_REMATCH[1]} (Silently)"
    elif [[ "$act" == *"overview toggle"* ]]; then
        echo "Toggle Desktop Overview"
    elif [[ "$act" == *"show_binds.sh"* ]]; then
        echo "Search/Show Keybindings"
    elif [[ "$act" == *"dpms off"* ]]; then
        echo "Lock & Sleep System (Lid Close)"
    elif [[ "$act" == *"dpms on"* ]]; then
        echo "Wake Display (Lid Open)"
    elif [[ "$act" == *"toggle-anim"* ]]; then
        echo "Toggle Desktop Animations"
    else
        echo "$act"
    fi
}

formatted=$(grep -h -E "^\s*bind[a-z]*\s*=" ~/.config/hypr/configs/keybinds.conf ~/.config/hypr/configs/user-overrides.conf 2>/dev/null | tr -d "\r" | while read -r line; do
    if [ -z "$line" ]; then continue; fi
    
    # Remove the bind prefix (e.g., 'bind = ' or 'bindel = ')
    parts=$(echo "$line" | sed -E "s/^bind[a-z]*\s*=\s*//")
    
    # Parse CSV fields safely
    mod=$(echo "$parts" | cut -d"," -f1 | xargs)
    key=$(echo "$parts" | cut -d"," -f2 | xargs)
    action=$(echo "$parts" | cut -d"," -f3- | xargs)
    
    # Substitute mod variables with readable names
    mod=$(echo "$mod" | sed "s/\$mainMod/SUPER/g" \
                     | sed "s/\$altMod/ALT/g" \
                     | sed "s/\$shift/SHIFT/g" \
                     | sed "s/\$ctrl/CTRL/g")
                     
    # Format modifier keys nicely (e.g. "SUPER + SHIFT" instead of "SUPERSHIFT")
    if [ -n "$mod" ]; then
        # Replace spaces between multiple modifiers with " + "
        mod_formatted=$(echo "$mod" | sed "s/\s\+/ + /g")
        mod_key="$mod_formatted + $key"
    else
        mod_key="$key"
    fi
    
    # Translate cryptic key names to human-readable names
    mod_key=$(echo "$mod_key" | sed "s/XF86AudioRaiseVolume/Volume Up/g" \
                             | sed "s/XF86AudioLowerVolume/Volume Down/g" \
                             | sed "s/XF86AudioMute/Mute/g" \
                             | sed "s/XF86MonBrightnessUp/Brightness Up/g" \
                             | sed "s/XF86MonBrightnessDown/Brightness Down/g" \
                             | sed "s/PRINT/PrintScreen/g" \
                             | sed "s/grave/\`/g" \
                             | sed "s/slash/\//g" \
                             | sed "s/period/./g" \
                             | sed "s/Return/Enter/g" \
                             | sed "s/left/Left/g" \
                             | sed "s/right/Right/g" \
                             | sed "s/up/Up/g" \
                             | sed "s/down/Down/g")
                             
    translated_act=$(translate_action "$action")
    # Print formatted row
    printf "%-35s | %s\n" "$mod_key" "$translated_act"
done)

# Use fuzzel as a beautiful dmenu replacement
echo "$formatted" | fuzzel --dmenu -l 25 -w 90 -p "Keybinds ⌨: "
