#!/usr/bin/env python3
"""
Hyprland Sleep & Resume Handler with Systemd Sleep Inhibitor
Prevents screen content leakage by ensuring the session is locked and the display
is turned off BEFORE the system enters suspend, and restoring cleanly on resume.
"""

import os
import sys
import time
import fcntl
import subprocess
import signal
import dbus
import dbus.mainloop.glib
from gi.repository import GLib

LOG_FILE = os.path.join(os.path.expanduser("~"), ".local/state/sys-stats-lock.log")
LOCK_FILE = "/tmp/hypr-resume-handler.lock"

def ensure_single_instance():
    global lock_fd
    lock_fd = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        sys.exit(0)

def log_event(event_type: str):
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as f:
            f.write(f"{int(time.time())} {event_type}\n")
    except Exception as e:
        sys.stderr.write(f"Error logging event: {e}\n")

class SleepHandler:
    def __init__(self, loop):
        self.loop = loop
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        self.login1 = self.bus.get_object("org.freedesktop.login1", "/org/freedesktop/login1")
        self.manager = dbus.Interface(self.login1, "org.freedesktop.login1.Manager")
        self.inhibitor_fd = None

        self.acquire_inhibitor()

        self.bus.add_signal_receiver(
            self.on_prepare_for_sleep,
            signal_name="PrepareForSleep",
            dbus_interface="org.freedesktop.login1.Manager"
        )

        # Idle-lock visibility for sys-stats: hypridle locks via
        # `loginctl lock-session`, which never fires Noctalia's
        # screenLock/screenUnlock hooks (its lockscreen + idle handling are
        # disabled in favour of hyprlock).  Without this, every idle lock is
        # invisible and "active" time is inflated towards full awake time.
        # logind emits Lock/Unlock on each graphical session object;
        # duplicates with Noctalia's hooks are harmless (the stats parser
        # ignores nested lock/unlock pairs).
        # NOTE: this service itself is not part of any logind session
        # (GetSessionByPID fails), so discover graphical sessions via
        # ListSessions.  The service may start before login, therefore
        # (re)resolve on every SessionNew signal too.
        self.lock_paths = set()
        self.bus.add_signal_receiver(
            self.on_session_new,
            signal_name="SessionNew",
            dbus_interface="org.freedesktop.login1.Manager"
        )
        self.bus.add_signal_receiver(
            self.on_session_removed,
            signal_name="SessionRemoved",
            dbus_interface="org.freedesktop.login1.Manager"
        )
        self.subscribe_session_locks()

    def subscribe_session_locks(self):
        try:
            sessions = self.manager.ListSessions()
        except Exception as e:
            sys.stderr.write(f"ListSessions failed: {e}\n")
            return
        uid = os.getuid()
        for entry in sessions:
            try:
                _sid, s_uid, _user, seat, sess_path = entry[:5]
            except (ValueError, TypeError):
                continue
            if int(s_uid) != uid or str(sess_path) in self.lock_paths:
                continue
            if not seat:  # skip non-graphical (manager) sessions
                continue
            try:
                self.bus.add_signal_receiver(
                    self.on_session_lock,
                    signal_name="Lock",
                    dbus_interface="org.freedesktop.login1.Session",
                    path=str(sess_path)
                )
                self.bus.add_signal_receiver(
                    self.on_session_unlock,
                    signal_name="Unlock",
                    dbus_interface="org.freedesktop.login1.Session",
                    path=str(sess_path)
                )
                self.lock_paths.add(str(sess_path))
            except Exception as e:
                sys.stderr.write(f"Lock-signal subscribe failed: {e}\n")

    def on_session_new(self, _session_id, _object_path):
        self.subscribe_session_locks()

    def on_session_removed(self, _session_id, object_path):
        self.lock_paths.discard(str(object_path))

    def acquire_inhibitor(self):
        if self.inhibitor_fd is not None:
            return
        try:
            raw_fd = self.manager.Inhibit(
                "sleep",
                "hypr-resume-handler",
                "Lock screen before sleep and prevent display flicker",
                "delay"
            )
            self.inhibitor_fd = raw_fd.take()
        except Exception as e:
            sys.stderr.write(f"Error acquiring sleep inhibitor: {e}\n")

    def release_inhibitor(self):
        if self.inhibitor_fd is not None:
            try:
                os.close(self.inhibitor_fd)
            except Exception as e:
                sys.stderr.write(f"Error closing inhibitor: {e}\n")
            self.inhibitor_fd = None

    def on_session_lock(self):
        log_event("lock")

    def on_session_unlock(self):
        log_event("unlock")

    def on_prepare_for_sleep(self, going_to_sleep: bool):
        if going_to_sleep:
            # 1. Log suspend event
            log_event("suspend")

            # 2. Blank display and trigger session lock immediately
            subprocess.run(["hyprctl", "dispatch", "dpms", "off", "eDP-1"], check=False)
            subprocess.run([os.path.join(os.path.expanduser("~"), ".local/bin/noctalia-ipc"), "lockScreen", "lock"], check=False)

            # 3. Wait briefly (350ms) to allow compositor & shell to commit lock surface
            time.sleep(0.35)

            # 4. Release inhibitor so systemd can proceed to suspend
            self.release_inhibitor()
        else:
            # 1. Log resume event
            log_event("resume")

            # 2. Re-acquire inhibitor for next sleep
            self.acquire_inhibitor()

            # 3. Wake monitor
            for _ in range(2):
                subprocess.run(["hyprctl", "dispatch", "dpms", "on", "eDP-1"], check=False)
                time.sleep(0.1)

def main():
    ensure_single_instance()
    loop = GLib.MainLoop()

    def sig_handler(sig, frame):
        loop.quit()

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    _ = SleepHandler(loop)
    loop.run()

if __name__ == "__main__":
    main()
