#!/usr/bin/env python3
"""Install the optimized Aero outline for the current user, or restore its setting."""
import argparse
import configparser
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


QML_PATH = "aerothemeplasma/outline/outline.qml"


def copy_atomic(source, destination):
    """Copy via a temp file in the destination directory, then rename over it."""
    handle, name = tempfile.mkstemp(dir=destination.parent, prefix=destination.name + ".")
    temporary = Path(name)
    try:
        with os.fdopen(handle, "wb") as stream, open(source, "rb") as original:
            shutil.copyfileobj(original, stream)
        shutil.copystat(source, temporary)
        os.replace(temporary, destination)
    except BaseException:
        temporary.unlink(missing_ok=True)  # the mkstemp file created above
        raise


def system_default(name):
    """The Outline QmlPath a system-wide kwinrc (e.g. the theme's) sets, if any."""
    dirs = os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg"
    for directory in dirs.split(":"):
        if not directory:
            continue
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        parser.read(Path(directory) / "kwinrc")
        value = parser.get("Outline", name, fallback=None)
        if value is not None:
            return value
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--disable", action="store_true")
    args = parser.parse_args()
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    backup = state_home / "aerothemeplasma/snap-preview.json"
    config = configparser.ConfigParser(interpolation=None, strict=False)
    config.optionxform = str
    config.read(config_home / "kwinrc")
    previous = config.get("Outline", "QmlPath", fallback=None)
    command = ["kwriteconfig6", "--file", "kwinrc", "--group", "Outline", "--key", "QmlPath"]

    if args.disable:
        if not backup.exists():
            raise SystemExit("No saved outline setting; nothing was changed.")
        saved = json.loads(backup.read_text())["qml_path"]
        if previous != QML_PATH:
            backup.unlink()
            print("The outline setting was changed since installation; left as it is.")
            return
        subprocess.run(command + (["--delete"] if saved is None else [saved]), check=True)
        backup.unlink()
        if saved is None and system_default("QmlPath") == QML_PATH:
            print("Removed the user override, but the system default kwinrc (the theme's "
                  "install) still selects the Aero outline, so it stays active.")
            print("To use KWin's stock outline, set [Outline] QmlPath in ~/.config/kwinrc "
                  "or remove the theme's default.")
        else:
            print("Restored the previous outline setting. Log out and back in to apply it.")
        return

    source = Path(__file__).resolve().parents[1] / "plasma/outline"
    destination = data_home / "aerothemeplasma/outline"
    (destination / "res").mkdir(parents=True, exist_ok=True)
    for name in ("outline.qml", "SnapPreview.qml", "res/frame.png", "res/shadow.png"):
        copy_atomic(source / name, destination / name)
    if not backup.exists():
        backup.parent.mkdir(parents=True, exist_ok=True)
        with backup.open("x") as stream:
            json.dump({"qml_path": previous}, stream, indent=2)
    subprocess.run(command + [QML_PATH], check=True)
    print("Installed the optimized Aero snap preview. Log out and back in to apply it.")


if __name__ == "__main__":
    main()
