#!/usr/bin/env python3
"""Opt-in parallel preview staging. Never installs the upstream package identity."""
import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ID = "local.win7.seventasks.preview"
LIBRARY = "lib" + ID + ".so"


def replace_with_backup(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        backup = destination.with_name(destination.name + ".backup-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
        destination.rename(backup)
        print("Backup:", backup)
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
    if destination == ROOT or destination in ROOT.parents or str(destination).startswith(("/usr", "/etc", "/opt")):
        parser.error("choose an isolated, user-owned directory, not a source/global prefix")
    package = destination / "share/plasma/plasmoids" / ID
    plugin = destination / "plugins/plasma/applets" / LIBRARY
    if args.action == "stage":
        if not args.native_build:
            parser.error("--native-build is required; the QML package alone is not this native applet")
        source_plugin = args.native_build.resolve() / "plugins/plasma/applets" / LIBRARY
        if not source_plugin.is_file():
            parser.error("native preview plugin has not been built")
        source = ROOT / "plasma/plasmoids/io.gitgud.wackyideas.seventasks"
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
        source = args.from_stage.resolve()
        source_package = source / "share/plasma/plasmoids" / ID
        source_plugin = source / "plugins/plasma/applets" / LIBRARY
        if not source_plugin.is_file() or not (source_package / "metadata.json").is_file():
            parser.error("incomplete source stage")
        if json.loads((source_package / "metadata.json").read_text())["KPlugin"]["Id"] != ID:
            parser.error("source stage is not the independent preview identity")
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
