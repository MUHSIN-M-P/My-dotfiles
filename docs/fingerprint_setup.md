# Elan Match-on-Chip (MOC) 2 Fingerprint Setup Guide
This document details the reverse-engineering, diagnostics, and customized compilation required to get the **Elan Match-on-Chip 2 Fingerprint Sensor (`04f3:0c90`)** working perfectly on Fedora with PAM and Hyprland.

> [!NOTE]
> This setup is specific to the hardware device `04f3:0c90` (USB ID `04f3:0c90` - Elan Microelectronics Corp. ELAN:ARM-M4). The default `elanmoc` driver does not support this protocol, so we utilize Davide Depau's experimental `elanmoc2` driver branch with custom patches.

---

## 🛠️ Summary of Custom Fixes Implemented

1. **Protocol Compatibility (`elanmoc2`):** Migrated from `elanmoc` to Davide Depau's `elanmoc2` driver which implements the modern ARM-M4 Match-on-Chip command protocol.
2. **USB Transfer Buffer Expansion:** Increased the input buffer size for the finger info command (`cmd_finger_info.in_len`) from `64` to `256` bytes to prevent low-level `LIBUSB_TRANSFER_OVERFLOW` errors caused by the hardware returning larger packets.
3. **Suppressed Short Read Errors:** Changed `transfer_in->short_is_error` to `FALSE` in `elanmoc2_cmd_transceive` to accept variable-length packets (like `70` bytes) from the device without triggering fatal aborts.
4. **The Hex-Dump Breakthrough (The Truncated Prefix):**
   When enrolling a print, `libfprint` registers a user signature formatted as:
   `FP1-20260518-7-78CE5BB3-ldzbeta`
   
   However, on verification, the device repeatedly returned `verify-no-match`. By injecting diagnostic hooks to read the raw hex bytes directly from the Match-on-Chip (MOC) response frames, we discovered the breakthrough:
   ```text
   Finger Info Response hex dump [70 bytes]: 
   40 00 31 2d 32 30 32 36 30 35 31 38 2d 37 2d 37 38 43 45 35 42 42 33 2d 6c 64 7a 62 65 74 61 ...
   ```
   Analyzing the bytes starting at index `2`:
   - `31 2d 32 30 32 36 ...` matches `"1-20260518-7-..."`
   
   This proved that the device's internal MOC firmware **ignores or overwrites the first 2 characters (`"FP"`)** of the signature when saving the enrollment in flash! Because the returned string did not start with `"FP1-"`, `libfprint` rejected it as an invalid signature.
   
   **The Patch:** We patched `elanmoc2.c` to automatically detect a `"1-"` prefix and prepend `"FP"` back to cleanly reconstruct `"FP1-..."`, making it instantly authorized by `libfprint`!
5. **Wrong Fingerprint Auto-Deletion Fix:**
   Normally, when you touched the sensor with an unregistered/wrong finger, the driver returned `ELANMOC2_RESP_NOT_ENROLLED` which was mapped to a fatal `FP_DEVICE_ERROR_DATA_NOT_FOUND` error. This caused `fprintd` to believe the fingerprint template was completely missing from the chip, triggering an automatic "cleanup" that wiped the stored enrollment database!
   
   **The Patch:** We updated `elanmoc2.c` to map `ELANMOC2_RESP_NOT_ENROLLED` to a recoverable `FP_DEVICE_RETRY_GENERAL` retry event with the message `"Fingerprint not recognized"`. Wrong touches now fail cleanly with a normal retry/mismatch rather than deleting your database!

---

## 🚀 Quick Restore Guide (Only for this Computer)

If you ever reinstall Fedora or need to rebuild the custom driver from scratch, follow these exact step-by-step commands to get it working again instantly.

### Step 1: Install Build Dependencies
```bash
sudo dnf install -y meson ninja-build glib2-devel libusb1-devel pixman-devel \
                    gobject-introspection-devel polkit-devel nss-devel \
                    python3-gobject pybind11-devel
```

### Step 2: Clone and Apply Patches
We cloned Davide Depau's experimental repository and applied our custom hardware support patches.

```bash
# 1. Create builds directory and clone the elanmoc2 branch
mkdir -p ~/builds
git clone --depth 1 -b elanmoc2-working https://gitlab.freedesktop.org/Depau/libfprint.git ~/builds/libfprint-elanmoc2
cd ~/builds/libfprint-elanmoc2

# 2. Save the patch to a file and apply it
cat << 'EOF' > fingerprint_0c90.patch
diff --git a/data/autosuspend.hwdb b/data/autosuspend.hwdb
index 43e996d..0ea2082 100644
--- a/data/autosuspend.hwdb
+++ b/data/autosuspend.hwdb
@@ -162,6 +162,7 @@ usb:v04F3p0C99*
 # Supported by libfprint driver elanmoc2
 usb:v04F3p0C00*
 usb:v04F3p0C4C*
+usb:v04F3p0C90*
 usb:v04F3p0C5E*
  ID_AUTOSUSPEND=1
  ID_PERSIST=0
diff --git a/libfprint/drivers/elanmoc2/elanmoc2.c b/libfprint/drivers/elanmoc2/elanmoc2.c
index ee42219..1f7c9cc 100644
--- a/libfprint/drivers/elanmoc2/elanmoc2.c
+++ b/libfprint/drivers/elanmoc2/elanmoc2.c
@@ -119,7 +119,7 @@ elanmoc2_cmd_transceive (FpDevice *device, FpiSsm *ssm, const struct elanmoc2_cm
 
   FpiUsbTransfer *transfer_in = fpi_usb_transfer_new (device);
 
-  transfer_in->short_is_error = TRUE;
+  transfer_in->short_is_error = FALSE;
 
   fpi_usb_transfer_fill_bulk (transfer_in, cmd->ep_in, cmd->in_len);
   fpi_usb_transfer_submit (transfer_in,
@@ -195,6 +195,14 @@ elanmoc2_get_user_id_string (FpiDeviceElanMoC2 *self, const guint8 *finger_info_
 static FpPrint *
 elanmoc2_print_new_from_finger_info (FpiDeviceElanMoC2 *self, guint8 finger_id, const guint8 *finger_info_response)
 {
+  {
+    GString *hex = g_string_new ("");
+    for (int i = 0; i < self->buffer_in_len; i++)
+      g_string_append_printf (hex, "%02x ", finger_info_response[i]);
+    fp_info ("Finger Info Response hex dump [%d bytes]: %s", (int)self->buffer_in_len, hex->str);
+    g_string_free (hex, TRUE);
+  }
+
   g_autofree guint8 *user_id = g_malloc (ELANMOC2_USER_ID_MAX_LEN + 1);
   guint user_id_max_len = self->dev_type == ELANMOC2_DEV_0C5E ?
                           ELANMOC2_USER_ID_MAX_LEN_0C5E :
@@ -202,21 +210,42 @@ elanmoc2_print_new_from_finger_info (FpiDeviceElanMoC2 *self, guint8 finger_id,
 
   elanmoc2_get_user_id_string (self, finger_info_response, user_id, user_id_max_len);
 
-  guint8 user_id_len = user_id_max_len;
+  {
+    GString *hex = g_string_new ("");
+    for (int i = 0; i < user_id_max_len; i++)
+      g_string_append_printf (hex, "%02x ", user_id[i]);
+    fp_info ("Parsed user_id hex dump [%d bytes]: %s", (int)user_id_max_len, hex->str);
+    g_string_free (hex, TRUE);
+  }
 
+  g_autofree gchar *user_id_str = NULL;
   if (g_str_has_prefix ((const gchar *) user_id, "FP1-"))
     {
-      user_id_len = strnlen ((const char *) user_id, user_id_max_len);
-      fp_info ("Creating new print: finger %d, user id[%d]: %s", finger_id, user_id_len, user_id);
+      user_id_str = g_strdup ((const gchar *) user_id);
+    }
+  else if (g_str_has_prefix ((const gchar *) user_id, "1-"))
+    {
+      user_id_str = g_strconcat ("FP", (const gchar *) user_id, NULL);
+    }
+  else
+    {
+      user_id_str = g_strdup ((const gchar *) user_id);
+    }
+
+  guint8 user_id_len = strlen (user_id_str);
+
+  if (g_str_has_prefix (user_id_str, "FP1-"))
+    {
+      fp_info ("Creating new print: finger %d, user id[%d]: %s", finger_id, user_id_len, user_id_str);
     }
   else
     {
       fp_info ("Creating new print: finger %d, user id[%d]: raw data", finger_id, user_id_len);
     }
 
-  FpPrint *print = elanmoc2_print_new_with_user_id (self, finger_id, user_id_len, user_id);
+  FpPrint *print = elanmoc2_print_new_with_user_id (self, finger_id, user_id_len, (const guchar *) user_id_str);
 
-  if (!fpi_print_fill_from_user_id (print, (const char *) user_id))
+  if (!fpi_print_fill_from_user_id (print, user_id_str))
     {
       // Fingerprint matched with on-sensor print, but the on-sensor print was not added by libfprint.
       // Wipe it and report a failure.
@@ -239,7 +268,7 @@ elanmoc2_finger_info_is_present (FpiDeviceElanMoC2 *self, const guint8 *finger_i
                          (gchar *) &finger_info_response[3] :
                          (gchar *) &finger_info_response[2];
 
-  return memcmp (user_id, "FP1-", 4) == 0;
+  return memcmp (user_id, "FP1-", 4) == 0 || memcmp (user_id, "1-", 2) == 0;
 }
 
 
@@ -362,9 +391,9 @@ elanmoc2_get_finger_error (FpiDeviceElanMoC2 *self, GError **error)
       return TRUE;
 
     case ELANMOC2_RESP_NOT_ENROLLED:
-      *error = fpi_device_error_new_msg (FP_DEVICE_ERROR_DATA_NOT_FOUND,
-                                         "Finger not recognized");
-      return FALSE;
+      *error = fpi_device_retry_new_msg (FP_DEVICE_RETRY_GENERAL,
+                                         "Fingerprint not recognized");
+      return TRUE;
 
     case ELANMOC2_RESP_MAX_ENROLLED_REACHED:
       *error = fpi_device_error_new_msg (FP_DEVICE_ERROR_DATA_FULL,
diff --git a/libfprint/drivers/elanmoc2/elanmoc2.h b/libfprint/drivers/elanmoc2/elanmoc2.h
index 8ec1851..ef92147 100644
--- a/libfprint/drivers/elanmoc2/elanmoc2.h
+++ b/libfprint/drivers/elanmoc2/elanmoc2.h
@@ -64,8 +64,8 @@
 #define ELANMOC2_DEV_0C5E (2 << 0)
 
 // Subtract the 2-byte header
-#define ELANMOC2_USER_ID_MAX_LEN (cmd_finger_info.in_len - 2)
-#define ELANMOC2_USER_ID_MAX_LEN_0C5E (cmd_finger_info.in_len - 3)
+#define ELANMOC2_USER_ID_MAX_LEN 62
+#define ELANMOC2_USER_ID_MAX_LEN_0C5E 61
 
 G_DECLARE_FINAL_TYPE (FpiDeviceElanMoC2, fpi_device_elanmoc2, FPI, DEVICE_ELANMOC2, FpDevice)
 
@@ -113,7 +113,7 @@ static const struct elanmoc2_cmd cmd_get_fw_ver = {
 static const struct elanmoc2_cmd cmd_finger_info = {
   .cmd = {0xff, 0x12},
   .out_len = 4,
-  .in_len = 64,
+  .in_len = 256,
   .ep_in = ELANMOC2_EP_CMD_IN,
 };
 
@@ -210,6 +210,7 @@ enum clear_storage_states {
 static const FpIdEntry elanmoc2_id_table[] = {
   {.vid = ELANMOC2_VEND_ID, .pid = 0x0c00, .driver_data = ELANMOC2_ALL_DEV},
   {.vid = ELANMOC2_VEND_ID, .pid = 0x0c4c, .driver_data = ELANMOC2_ALL_DEV},
+  {.vid = ELANMOC2_VEND_ID, .pid = 0x0c90, .driver_data = ELANMOC2_ALL_DEV},
   {.vid = ELANMOC2_VEND_ID, .pid = 0x0c5e, .driver_data = ELANMOC2_DEV_0C5E},
   {.vid = 0, .pid = 0, .driver_data = ELANMOC2_DEV_0C4C}
 };
EOF

git apply fingerprint_0c90.patch
```

### Step 3: Compile and Build
```bash
meson setup _build
ninja -C _build
```

### Step 4: Install to the System
Copy the newly built `.so` library to override Fedora's standard `libfprint` package:
```bash
sudo systemctl stop fprintd.service
sudo cp ~/builds/libfprint-elanmoc2/_build/libfprint/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0
sudo systemctl restart fprintd.service
```

---

## 🧹 Maintenance and Diagnostics

### Wiping the Sensor Memory (Onboard Storage)
Because the Match-on-Chip (MOC) sensor stores fingerprint templates on a physical flash chip, sometimes you must wipe its storage to avoid duplicate enrollments. 

Create and run this custom script (`clear_prints.py`):
```python
#!/usr/bin/python3
import gi
gi.require_version('FPrint', '2.0')
from gi.repository import FPrint

ctx = FPrint.Context()
devices = ctx.get_devices()

for dev in devices:
    print(f"Wiping on-chip storage for device: {dev.props.device_id}")
    dev.open_sync()
    dev.clear_storage_sync()
    dev.close_sync()
    print("Storage successfully wiped.")
```
Run it with root permissions:
```bash
sudo python3 clear_prints.py && sudo systemctl restart fprintd.service
```

### Enrolling Fingers
```bash
sudo fprintd-enroll ldzbeta
```
*(Always run with `sudo` to avoid Polkit permission hangouts under standalone window managers like Hyprland).*

### Verifying
```bash
fprintd-verify
```

---

## 🔐 Dual-Auth Configuration (Password & Fingerprint Coexistence)

To ensure that you can use **either** your fingerprint **or** your password seamlessly across all system contexts, follow these configurations:

### 1. Terminal / Sudo Fallback (Instant Fallback with Zero Delay)
By default, `fprintd` allows 3 attempts before timing out or failing, causing a 4-5 second lag when you press Enter in the terminal to bypass it. 

To eliminate this delay completely, we configure `pam_fprintd.so` to use `max_tries=1`. This makes it so a single mis-scan or **pressing `Enter` once** instantly bypasses the fingerprint and drops you directly to the password prompt with **zero lag!**

To apply this system-wide on Fedora:
```bash
sudo sed -i 's/pam_fprintd.so/pam_fprintd.so max_tries=1/' /etc/authselect/system-auth
```

*   **To use fingerprint:** Simply scan your finger on the reader.
*   **To bypass and type password instead:** Press **`Enter`** once. It will immediately open the password input without any wait time!

### 2. Lockscreen Fallback (Noctalia QML Lockscreen)
The custom Noctalia QML lockscreen has a built-in sensor-locking feature to gracefully abort `fprintd` and switch to password verification as soon as you type. 

I have automatically enabled this for you in `/home/ldzbeta/.config/noctalia/settings.json` and `/home/ldzbeta/dotfiles/home/.config/noctalia/settings.json`:
*   `"general.allowPasswordWithFprintd"` is set to `true`.
*   `"general.autoStartAuth"` is set to `true`.

This means the fingerprint sensor is active immediately when the lockscreen appears, but **typing a single character** will instantly switch the screen to password entry!

### 3. Login Screen (SDDM) Coexistence (Instant Auto-Fingerprint)
To configure SDDM so that the fingerprint scanner is **automatically active** as soon as the screen turns on, while allowing you to type your password at any time:

Run this command in your terminal to update `/etc/pam.d/sddm`:
```bash
sudo tee /etc/pam.d/sddm << 'EOF'
auth     [success=done ignore=ignore default=bad] pam_selinux_permit.so
auth     [success=2 default=ignore]                   pam_unix.so try_first_pass nullok
auth     sufficient                                   pam_fprintd.so max-tries=1
auth     substack                                     password-auth
-auth    optional                                     pam_gnome_keyring.so
auth     include                                      postlogin

account     required      pam_nologin.so
account     include       password-auth

password    include       password-auth

session     required      pam_selinux.so close
session     required      pam_loginuid.so
-session    optional      pam_ck_connector.so
session     required      pam_selinux.so open
session     optional      pam_keyinit.so force revoke
session     required      pam_namespace.so
session     include       password-auth
-session    optional      pam_gnome_keyring.so auto_start
-session    optional      pam_kwallet5.so auto_start
-session    optional      pam_kwallet.so auto_start
session     include       postlogin
EOF
```

*   **How to log in on SDDM:** 
    *   **To use fingerprint:** Simply touch the scanner immediately—no keys required!
    *   **To use password:** Just start typing your password and press **`Enter`**. SDDM will cancel the fingerprint scan and authenticate you.
