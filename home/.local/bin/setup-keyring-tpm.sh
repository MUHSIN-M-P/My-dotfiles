#!/usr/bin/env bash

# GNOME Keyring TPM 2.0 Auto-Unlock Setup Script for Fedora
# Created by Antigravity AI assistant

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== GNOME Keyring TPM 2.0 Auto-Unlock Setup ===${NC}"
echo "This script configures your system to unlock your login keyring automatically using your motherboard's TPM 2.0 chip when you log in with fingerprint."
echo

# 1. Check for required packages
echo -e "${YELLOW}[1/5] Checking dependencies...${NC}"
for pkg in clevis tpm2-tools; do
    if ! rpm -q "$pkg" &>/dev/null; then
        echo -e "${RED}Error: $pkg is not installed. Installing...${NC}"
        sudo dnf install -y "$pkg"
    else
        echo -e "${GREEN}✓ $pkg is installed.${NC}"
    fi
done

# 2. Check group membership
echo -e "${YELLOW}[2/5] Checking TPM group membership...${NC}"
if ! groups | grep -q "\btss\b"; then
    echo -e "${YELLOW}User '$USER' is not in the 'tss' group. Adding now...${NC}"
    sudo usermod -aG tss "$USER"
    echo -e "${GREEN}✓ Added '$USER' to 'tss' group.${NC}"
    echo -e "${YELLOW}Note: You will need to log out and log back in (or reboot) for this to take effect.${NC}"
else
    echo -e "${GREEN}✓ User is in the 'tss' group.${NC}"
fi

# 3. Get the login password
echo -e "${YELLOW}[3/5] Requesting keyring password...${NC}"
echo "Please enter the password for your 'Login' keyring (usually your user password):"
read -rs -p "Password: " keyring_pass
echo
read -rs -p "Confirm Password: " keyring_pass_confirm
echo

if [ "$keyring_pass" != "$keyring_pass_confirm" ]; then
    echo -e "${RED}Error: Passwords do not match.${NC}"
    exit 1
fi

if [ -z "$keyring_pass" ]; then
    echo -e "${RED}Error: Password cannot be empty.${NC}"
    exit 1
fi

# 4. Seal the password to TPM
echo -e "${YELLOW}[4/5] Sealing password to TPM 2.0 (PCR 7)...${NC}"
mkdir -p "$HOME/.config/keyring-tpm"
# We run clevis with sudo during setup since group membership hasn't taken effect in the current session
if echo -n "$keyring_pass" | sudo clevis encrypt tpm2 '{"pcr_ids":"7"}' > "$HOME/.config/keyring-tpm/keyring.jwe"; then
    sudo chown "$USER:$USER" "$HOME/.config/keyring-tpm/keyring.jwe"
    chmod 600 "$HOME/.config/keyring-tpm/keyring.jwe"
    echo -e "${GREEN}✓ Password successfully sealed to TPM at ~/.config/keyring-tpm/keyring.jwe${NC}"
else
    echo -e "${RED}Error: Failed to seal password to TPM.${NC}"
    exit 1
fi

# 5. Create unlock script
echo -e "${YELLOW}[5/5] Creating unlock script...${NC}"
mkdir -p "$HOME/.local/bin"
unlock_script="$HOME/.local/bin/unlock-keyring.sh"

cat << 'EOF' > "$unlock_script"
#!/usr/bin/env bash
# Automatically decrypt the password from TPM and unlock the GNOME Keyring daemon

# Exit if keyring file does not exist
if [ ! -f "$HOME/.config/keyring-tpm/keyring.jwe" ]; then
    exit 0
fi

# We use clevis decrypt to unseal the password, then pipe to gnome-keyring-daemon --unlock
if clevis decrypt < "$HOME/.config/keyring-tpm/keyring.jwe" | gnome-keyring-daemon --unlock; then
    logger -t unlock-keyring "GNOME Keyring successfully unlocked using TPM 2.0"
else
    logger -t unlock-keyring "Failed to unlock GNOME Keyring using TPM 2.0"
fi
EOF

chmod +x "$unlock_script"
echo -e "${GREEN}✓ Unlock script created at $unlock_script${NC}"

# Add to autostart if not already there
autostart_file="$HOME/.config/hypr/configs/autostart.conf"
if [ -f "$autostart_file" ]; then
    if ! grep -q "unlock-keyring.sh" "$autostart_file"; then
        echo -e "${YELLOW}Adding unlock script to Hyprland autostart config...${NC}"
        sed -i '2a exec-once = ~/.local/bin/unlock-keyring.sh' "$autostart_file"
        echo -e "${GREEN}✓ Added to $autostart_file${NC}"
    else
        echo -e "${GREEN}✓ Unlock script is already configured in $autostart_file${NC}"
    fi
fi

echo
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo -e "${YELLOW}IMPORTANT:${NC} Please log out of your session and log back in (or reboot) for the TPM access group permissions to take effect."
echo "Once you reboot, logging in with your fingerprint will automatically unlock your keyring!"
