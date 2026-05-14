#!/bin/bash
# Extract bind lines, format them and pipe to fuzzel -d

lines=""
for conf in ~/.config/hypr/configs/keybinds.conf ~/.config/hypr/configs/user-overrides.conf; do
    if [ -f "$conf" ]; then
        extracted=$(grep -E '^\s*bind' "$conf" | sed 's/^[ \t]*//')
        lines="$lines\n$extracted"
    fi
done

formatted=$(echo -e "$lines" | while read -r line; do
    if [ -z "$line" ]; then continue; fi
    parts=$(echo "$line" | sed -E 's/bind[a-z]*\s*=\s*//')
    parts=$(echo "$parts" | sed 's/$mainMod/SUPER/g' | sed 's/$altMod/ALT/g' | sed 's/$shift/SHIFT/g' | sed 's/$ctrl/CTRL/g')
    
    mod_key=$(echo "$parts" | awk -F, '{print $1 " + " $2}' | sed 's/ //g' | sed 's/+/ + /g')
    action=$(echo "$parts" | awk -F, '{print $3 " " $4}' | xargs)
    
    printf "%-30s | %s\n" "$mod_key" "$action"
done)

# Use fuzzel as a beautiful dmenu replacement
echo "$formatted" | fuzzel --dmenu -l 20 -w 80 -p "Keybinds ⌨: "
