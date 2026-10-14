#!/usr/bin/env python3
"""Exercise the real staging CLI entirely in temporary prefixes."""
import hashlib
import json
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[2]
cli = root / "scripts/stage-taskbar-preview.py"
build = Path(sys.argv[1]).resolve()
identity = "local.win7.seventasks.preview"
plugin = "plugins/plasma/applets/lib" + identity + ".so"
package = "share/plasma/plasmoids/" + identity
checks = 0


def check(value):
    global checks
    assert value
    checks += 1


def run(*args):
    subprocess.run([sys.executable, str(cli), *map(str, args)], check=True)


def rejected(*args):
    result = subprocess.run([sys.executable, str(cli), *map(str, args)], capture_output=True, text=True)
    check(result.returncode == 2 and "must not overlap" in result.stderr)


def tree_digest(directory):
    return {str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in directory.rglob("*") if path.is_file()}


with tempfile.TemporaryDirectory(prefix="win7-preview-staging-") as temporary:
    stage = Path(temporary) / "stage"
    prefix = Path(temporary) / "prefix"
    run("stage", stage, "--native-build", build)
    metadata = json.loads((stage / package / "metadata.json").read_text())
    check(metadata["KPlugin"]["Id"] == identity)
    check(metadata["KPlugin"]["EnabledByDefault"] is False)
    check(metadata["KPlugin"]["Authors"][0]["Name"] == "WackyIdeas")
    check(hashlib.sha256((stage / plugin).read_bytes()).digest() == hashlib.sha256((build / plugin).read_bytes()).digest())
    run("stage", stage, "--native-build", build)
    check(len(list((stage / package).parent.glob(identity + ".backup-*"))) == 1)

    before = tree_digest(stage)
    rejected("install", stage, "--from-stage", stage, "--confirm")
    check(tree_digest(stage) == before and (stage / package).exists())

    alias = Path(temporary) / "stage-alias"
    alias.symlink_to(stage, target_is_directory=True)
    rejected("install", alias, "--from-stage", stage, "--confirm")
    check(tree_digest(stage) == before and (stage / package).exists())

    nested = stage / package / "recursive-stage"
    rejected("install", nested, "--from-stage", stage, "--confirm")
    check(not nested.exists() and tree_digest(stage) == before)

    native_copy = Path(temporary) / "native-copy"
    (native_copy / plugin).parent.mkdir(parents=True)
    shutil.copy2(build / plugin, native_copy / plugin)
    native_before = tree_digest(native_copy)
    rejected("stage", native_copy, "--native-build", native_copy)
    check(tree_digest(native_copy) == native_before and not (native_copy / package).exists())

    prefix.mkdir()
    (prefix / "keep.txt").write_text("Unrelated data")
    run("install", prefix, "--from-stage", stage, "--confirm")
    check((prefix / package / "metadata.json").exists() and (prefix / plugin).exists())
    run("uninstall", prefix, "--confirm")
    check(not (prefix / package).exists() and not (prefix / plugin).exists() and (prefix / "keep.txt").read_text() == "Unrelated data")
print(f"{checks} staging assertions passed; only temporary prefixes modified")
