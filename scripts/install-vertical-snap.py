#!/usr/bin/env python3
"""Install Aero vertical snap, preserving and restoring the user's shortcuts."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

import dbus


PLUGIN = "aeroverticalsnap"
ACTIONS = {
    "Window Quick Tile Top": "Aero Vertical Snap Up",
    "Window Quick Tile Bottom": "Aero Vertical Snap Down",
}


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def action(name):
    return dbus.Array(["kwin", name, "KWin", name], signature="s")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--disable", action="store_true")
    args = parser.parse_args()
    bus = dbus.SessionBus()
    accel = dbus.Interface(bus.get_object("org.kde.kglobalaccel", "/kglobalaccel"),
                           "org.kde.KGlobalAccel")
    scripting = dbus.Interface(bus.get_object("org.kde.KWin", "/Scripting"),
                               "org.kde.kwin.Scripting")
    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    backup = state / "aerothemeplasma/vertical-snap-shortcuts.json"

    def get_keys(name):
        return [[int(key) for key in sequence[0]]
                for sequence in accel.shortcutKeys(action(name))]

    def set_keys(name, keys):
        sequences = dbus.Array([dbus.Struct([dbus.Array(seq, signature="i")])
                                for seq in keys], signature="(ai)")
        accel.setForeignShortcutKeys(action(name), sequences)
        if get_keys(name) != keys:
            raise RuntimeError(f"Could not apply shortcut: {name}")

    def enable_plugin(enabled):
        if scripting.isScriptLoaded(PLUGIN):
            scripting.unloadScript(PLUGIN)
        run("kwriteconfig6", "--file", "kwinrc", "--group", "Plugins", "--key",
            PLUGIN + "Enabled", str(enabled).lower())
        run("qdbus6", "org.kde.KWin", "/KWin", "org.kde.KWin.reconfigure")
        for _ in range(40):
            if bool(scripting.isScriptLoaded(PLUGIN)) == enabled:
                return
            time.sleep(0.1)
        raise RuntimeError("KWin did not apply the vertical snap setting")

    def restore(saved):
        """Undo the install step by step; one failure must not skip the rest."""
        failures = []

        def attempt(description, function, *arguments):
            try:
                function(*arguments)
            except Exception as error:
                failures.append(description)
                print(f"Could not {description}: {error}", file=sys.stderr)

        for custom in ACTIONS.values():
            attempt(f"clear {custom}", set_keys, custom, [])
        attempt("disable the vertical snap script", enable_plugin, False)
        for native in ACTIONS:
            if native in saved:
                attempt(f"restore {native}", set_keys, native, saved[native])
        return failures

    if args.disable:
        if not backup.exists():
            raise RuntimeError("No saved shortcuts found; nothing was changed")
        saved = json.loads(backup.read_text())
        # Release the script's keys before restoring the native actions.
        failures = restore(saved)
        for native in ACTIONS:
            if native not in saved:
                print(f"Saved backup has no shortcuts for {native}; left unchanged.", file=sys.stderr)
        if failures:
            print(f"Backup kept at {backup}; rerun with --disable after fixing the problem.", file=sys.stderr)
            raise SystemExit(1)
        backup.unlink()
        print("Disabled Aero vertical snap and restored the original shortcuts.")
        return

    root = Path(__file__).resolve().parents[1]
    package = root / "plasma/kwin-scripts" / PLUGIN
    data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    operation = "--upgrade" if (data / "kwin/scripts" / PLUGIN).exists() else "--install"
    run("kpackagetool6", "--type", "KWin/Script", operation, str(package))
    if backup.exists():
        saved = json.loads(backup.read_text())
    else:
        saved = {native: get_keys(native) for native in ACTIONS}
        backup.parent.mkdir(parents=True, exist_ok=True)
        with backup.open("x") as stream:
            json.dump(saved, stream, indent=2)
    def terminate(signum, frame):
        raise KeyboardInterrupt(f"terminated by signal {signum}")

    signal.signal(signal.SIGTERM, terminate)
    try:
        for native in ACTIONS:
            set_keys(native, [])
        enable_plugin(True)
        for native, custom in ACTIONS.items():
            set_keys(custom, saved[native])
    except BaseException:
        # Ctrl-C and SIGTERM land here too; the native shortcuts must not stay cleared.
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        failed = restore(saved)
        print(("Rollback incomplete. " if failed else "Rolled back. ")
              + f"If shortcuts look wrong, run: python3 {Path(__file__).resolve()} --disable",
              file=sys.stderr)
        raise
    print("Enabled Aero vertical snap using the existing Up/Down tiling shortcuts.")


if __name__ == "__main__":
    main()
