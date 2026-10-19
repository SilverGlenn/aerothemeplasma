#!/usr/bin/env python3
"""Opt-in parallel preview staging. Never installs the upstream package identity."""
import argparse
import json
import os
import re
import shutil
import stat
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ID = "local.win7.seventasks.preview"
LIBRARY = "lib" + ID + ".so"


def reject_overlapping_paths(parser, pairs):
    # Validate the whole operation before moving any existing preview to backup.
    # Same-prefix, symlink-alias and nested copies can otherwise consume their
    # own source or recursively copy a package into itself.
    for source, destination in pairs:
        source, destination = source.resolve(), destination.resolve()
        if source == destination or source in destination.parents or destination in source.parents:
            parser.error("source and destination preview paths must not overlap")


KEEP_BACKUPS = 3
SYSTEM_PREFIXES = (Path("/usr"), Path("/etc"), Path("/opt"))


def unsafe_destination(destination):
    """Why a resolved destination must be refused, or None."""
    if destination == ROOT or destination in ROOT.parents:
        return "choose an isolated, user-owned directory, not a source/global prefix"
    if any(destination.is_relative_to(prefix) for prefix in SYSTEM_PREFIXES):
        return "choose an isolated, user-owned directory, not a source/global prefix"
    # The nearest existing component decides who can create files there: it must
    # be ours, or a sticky shared directory such as /tmp.
    anchor = destination
    while not anchor.exists():
        anchor = anchor.parent
    info = anchor.stat()
    sticky_shared = bool(info.st_mode & stat.S_ISVTX) and bool(info.st_mode & stat.S_IWOTH)
    if info.st_uid != os.getuid() and not sticky_shared:
        return f"{anchor} is not owned by you; choose a user-owned directory"
    return None


def prune_backups(destination):
    """Keep the newest KEEP_BACKUPS backups of this destination, delete older ones.

    Only entries this script created (same parent, exact name + timestamp
    pattern) are considered; symlinks are never followed or removed.
    """
    pattern = re.compile(re.escape(destination.name) + r"\.backup-\d{8}T\d{12}Z")
    backups = sorted(path for path in destination.parent.iterdir()
                     if pattern.fullmatch(path.name) and path.parent == destination.parent)
    for old in backups[:-KEEP_BACKUPS]:
        if old.is_symlink():
            continue
        if old.is_dir():
            shutil.rmtree(old)
        else:
            old.unlink()
        print("Removed old backup:", old)


def replace_with_backup(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        backup = destination.with_name(destination.name + ".backup-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
        destination.rename(backup)
        print("Backup:", backup)
        prune_backups(destination)
    if source.is_dir():
        shutil.copytree(source, destination)
    else:
        shutil.copy2(source, destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["stage", "install", "uninstall"])
    parser.add_argument("directory", type=Path, help="explicit staging directory or user-owned install prefix")
    parser.add_argument("--native-build", type=Path)
    parser.add_argument("--from-stage", type=Path)
    parser.add_argument("--confirm", action="store_true", help="required for optional prefix install/uninstall")
    args = parser.parse_args()
    destination = args.directory.expanduser().resolve()
    problem = unsafe_destination(destination)
    if problem:
        parser.error(problem)
    package = destination / "share/plasma/plasmoids" / ID
    plugin = destination / "plugins/plasma/applets" / LIBRARY
    if args.action == "stage":
        if not args.native_build:
            parser.error("--native-build is required; the QML package alone is not this native applet")
        source_plugin = args.native_build.resolve() / "plugins/plasma/applets" / LIBRARY
        if not source_plugin.is_file():
            parser.error("native preview plugin has not been built")
        source = ROOT / "plasma/plasmoids/io.gitgud.wackyideas.seventasks"
        reject_overlapping_paths(parser, ((source, package), (source_plugin, plugin)))
        replace_with_backup(source, package)
        metadata = json.loads((package / "metadata.json").read_text())
        for key in list(metadata["KPlugin"]):
            if key.startswith(("Name[", "Description[")):
                del metadata["KPlugin"][key]
        metadata["KPlugin"].update(Id=ID, Name="SevenTasks (Windows 7 private preview)",
            Description="Independent experimental Windows 7 fidelity fork; not upstream SevenTasks",
            EnabledByDefault=False)
        (package / "metadata.json").write_text(json.dumps(metadata, indent=4) + "\n")
        replace_with_backup(source_plugin, plugin)
    elif args.action == "install":
        if not args.confirm or not args.from_stage:
            parser.error("install requires --confirm and --from-stage (never run by staging/tests)")
        source = args.from_stage.expanduser().resolve()
        source_package = source / "share/plasma/plasmoids" / ID
        source_plugin = source / "plugins/plasma/applets" / LIBRARY
        if not source_plugin.is_file() or not (source_package / "metadata.json").is_file():
            parser.error("incomplete source stage")
        if json.loads((source_package / "metadata.json").read_text())["KPlugin"]["Id"] != ID:
            parser.error("source stage is not the independent preview identity")
        reject_overlapping_paths(parser, ((source_package, package), (source_plugin, plugin)))
        replace_with_backup(source / "share/plasma/plasmoids" / ID, package)
        replace_with_backup(source / "plugins/plasma/applets" / LIBRARY, plugin)
    else:
        if not args.confirm:
            parser.error("uninstall requires --confirm")
        if package.exists():
            shutil.rmtree(package)
        if plugin.exists():
            plugin.unlink()
        print("Removed only preview identity; backups are retained for manual restoration.")
    print("Prefix:", destination)
    print("Native loading requires an explicit QT_PLUGIN_PATH; normal Plasma discovery is untested.")


if __name__ == "__main__":
    main()
