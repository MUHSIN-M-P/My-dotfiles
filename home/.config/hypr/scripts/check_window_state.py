import json
import subprocess

try:
    result = subprocess.run(['hyprctl', 'activewindow', '-j'], capture_output=True, text=True)
    window = json.loads(result.stdout)
    print(f"Floating: {window.get('floating', False)}")
    print(f"Fullscreen: {window.get('fullscreen', False)}")
    print(f"XWayland: {window.get('xwayland', False)}")
    print(f"Pinned: {window.get('pinned', False)}")
except Exception as e:
    print(f"Error checking window state: {e}")
