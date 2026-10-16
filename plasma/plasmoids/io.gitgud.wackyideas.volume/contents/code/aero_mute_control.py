#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""One-shot mute control with an authoritative, fresh PulseAudio connection."""
import argparse
import configparser
import json
import os
from pathlib import Path
import subprocess

KINDS = {
    "sink": "sinks",
    "source": "sources",
    "sink-input": "sink-inputs",
    "source-output": "source-outputs",
}


def call(*arguments):
    result = subprocess.run(arguments, check=True, capture_output=True, text=True, timeout=4)
    return result.stdout


def snapshot(kind, index):
    devices = json.loads(call("pactl", "--format=json", "list", KINDS[kind]))
    device = next((device for device in devices if device["index"] == index), None)
    if device is None:
        raise RuntimeError("The audio device is no longer available.")
    volume = max((channel["value"] for channel in device.get("volume", {}).values()), default=0)
    return {"muted": bool(device["mute"]), "volume": volume, "index": index}


def global_output_muted():
    config = configparser.RawConfigParser(strict=False)
    config.read(Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "plasmaparc")
    return config.getboolean("General", "GlobalMuteSinks", fallback=False)


def release_global_output_mute(kind):
    # Let KDE update its own global-mute bookkeeping, rather than editing its
    # settings behind the shortcut service's back.
    if kind == "sink" and global_output_muted():
        call("qdbus6", "org.kde.kglobalaccel", "/component/kmix",
             "org.kde.kglobalaccel.Component.invokeShortcut", "mute", "default")


def control(kind, index, action):
    current = snapshot(kind, index)
    if action == "refresh":
        return current
    if action == "toggle":
        requested = not current["muted"]
        if not requested:
            release_global_output_mute(kind)
    elif action == "unmute-positive":
        if current["volume"] <= 0:
            return current
        requested = False
        release_global_output_mute(kind)
    elif action == "global-mute":
        if kind != "sink":
            raise RuntimeError("Playback mute shortcuts must not affect a microphone.")
        requested = global_output_muted()
    else:
        raise RuntimeError("Unsupported mute action.")
    # A new client is deliberate: a long-lived client can retain stale Bluetooth
    # state and suppress an apparently redundant unmute request.
    call("pactl", "set-" + kind + "-mute", str(index), "1" if requested else "0")
    return snapshot(kind, index)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=KINDS)
    parser.add_argument("index", type=int)
    parser.add_argument("action", choices=("toggle", "unmute-positive", "refresh", "global-mute"))
    args = parser.parse_args()
    if args.index < 0:
        parser.error("The audio-device index must be nonnegative.")
    try:
        print(json.dumps(control(args.kind, args.index, args.action)))
    except (RuntimeError, OSError, ValueError, configparser.Error, subprocess.SubprocessError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
