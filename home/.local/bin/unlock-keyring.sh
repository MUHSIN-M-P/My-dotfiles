#!/usr/bin/env bash
# Automatically decrypt the password from TPM and unlock the GNOME Keyring daemon

# Exit if keyring file does not exist
if [ ! -f "$HOME/.config/keyring-tpm/keyring.jwe" ]; then
    exit 0
fi

# Exit if clevis is not installed
if ! command -v clevis >/dev/null 2>&1; then
    exit 0
fi

# We use clevis decrypt to unseal the password, then pipe to gnome-keyring-daemon --unlock if non-empty
PASS=$(clevis decrypt < "$HOME/.config/keyring-tpm/keyring.jwe" 2>/dev/null)
if [ -n "$PASS" ]; then
    if echo -n "$PASS" | gnome-keyring-daemon --unlock; then
        logger -t unlock-keyring "GNOME Keyring successfully unlocked using TPM 2.0"
    else
        logger -t unlock-keyring "Failed to unlock GNOME Keyring using TPM 2.0"
    fi
else
    logger -t unlock-keyring "Failed to decrypt keyring password from TPM"
fi
