#!/usr/bin/env python3
"""Temporary real-panel transaction. Only `start` switches the running desktop.

Recovery is frozen into each private session, independent of this checkout. The
transient unit's ExecStopPost is the recovery authority, including guardian death.
"""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import time
import uuid

SERVICE = "plasma-plasmashell.service"
SHELL = "io.gitgud.wackyideas.desktop"
PANEL = "io.gitgud.wackyideas.panel"
TASKS = "io.gitgud.wackyideas.seventasks"
PYTHON = "/usr/bin/python3"
PLASMA = "/usr/bin/plasmashell"
SYSTEMCTL = "/usr/bin/systemctl"
SYSTEMD_RUN = "/usr/bin/systemd-run"
INSTALLED = Path("/usr/share/plasma/plasmoids")
PROC_ROOT = Path("/proc")
CGROUP_ROOT = Path("/sys/fs/cgroup")
RUNTIME_BASE = Path("/run/user")
ROOT = Path(__file__).resolve().parents[1]
STARTUP_SECONDS = 30
ENV_KEYS = ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_DATA_DIRS",
            "XDG_RUNTIME_DIR", "DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS")
FINAL = "restored"


class Unsafe(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise Unsafe(message)


def no_symlinks(path):
    path = Path(path)
    require(path.is_absolute(), "absolute path required")
    for part in [*reversed(path.parents), path]:
        require(not part.is_symlink(), f"symlink not supported: {part}")
    return path


def private_dir(path):
    path = no_symlinks(path)
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = path.stat()
    require(stat.S_ISDIR(info.st_mode) and info.st_uid == os.getuid()
            and stat.S_IMODE(info.st_mode) == 0o700, f"not a private directory: {path}")
    return path


def fsync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def atomic_bytes(path, data, mode=0o600):
    path = no_symlinks(path)
    temporary = path.with_name("." + path.name + "." + uuid.uuid4().hex)
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fchmod(stream.fileno(), mode)
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        fsync_dir(path.parent)
    finally:
        if temporary.exists():
            temporary.unlink()


def save(session, state):
    atomic_bytes(session / "state.json", (json.dumps(state, indent=2) + "\n").encode())


def load(session):
    private_dir(session)
    path = no_symlinks(session / "state.json")
    require(stat.S_IMODE(path.stat().st_mode) == 0o600, "state must be private")
    state = json.loads(path.read_text())
    require(state["version"] == 1 and state["uid"] == os.getuid(), "invalid session owner/version")
    require(re.fullmatch(r"win7-panel-preview-[0-9a-f]{32}\.service", state["unit"]), "invalid unit")
    config_names(state["shell"])
    require(set(state["env"]) <= set(ENV_KEYS), "unexpected recorded environment")
    return state


@contextmanager
def locked(directory, name="lock"):
    private_dir(directory)
    fd = os.open(directory / name, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        require(stat.S_ISREG(os.fstat(fd).st_mode), "invalid lock")
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def config_names(shell):
    require(bool(re.fullmatch(r"[a-zA-Z0-9]+(?:[.-][a-zA-Z0-9]+)+", shell)) and shell == SHELL,
            "only the verified io.gitgud.wackyideas.desktop shell is supported")
    return (f"plasma-{shell}-appletsrc", "plasmashellrc")


def environment(source=None):
    source = os.environ if source is None else source
    result = {key: source[key] for key in ENV_KEYS if key in source}
    result.setdefault("HOME", str(Path.home()))
    result.setdefault("XDG_CONFIG_HOME", str(Path(result["HOME"]) / ".config"))
    result.setdefault("XDG_DATA_HOME", str(Path(result["HOME"]) / ".local/share"))
    result.setdefault("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    for value in result.values():
        require(not any(ord(c) < 32 for c in value), "control character in environment")
    for key in ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME"):
        no_symlinks(Path(result[key]))
    require(all(Path(p).is_absolute() for p in result["XDG_DATA_DIRS"].split(":")),
            "XDG_DATA_DIRS must contain absolute nonempty paths")
    return result


def state_root():
    # Deliberately not redirected through preview data/config variables.
    return Path.home() / ".local/state/aerothemeplasma-win7/panel-preview"


def proc_identity(pid):
    try:
        base = PROC_ROOT / str(int(pid))
        raw = (base / "stat").read_text()
        fields = raw[raw.rfind(")") + 2:].split()
        return {"pid": int(pid), "ticks": int(fields[19]), "uid": base.stat().st_uid,
                "dead": fields[0] in ("Z", "X")}
    except (FileNotFoundError, ProcessLookupError):
        return None


def same_process(expected, actual):
    return bool(actual and not actual["dead"] and all(actual[k] == expected[k]
                for k in ("pid", "ticks", "uid")))


def command(args, timeout=15):
    return subprocess.run(list(map(str, args)), check=True, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout).stdout.strip()


class Platform:
    """The sole supported platform: an active managed Plasma user service."""
    def __init__(self, qdbus=None):
        self.qdbus = qdbus or shutil.which("qdbus6") or shutil.which("qdbus")
        if not self.qdbus and Path("/usr/lib/qt6/bin/qdbus").is_file():
            self.qdbus = "/usr/lib/qt6/bin/qdbus"
        require(self.qdbus, "Qt D-Bus CLI (qdbus6) required")

    def bus(self, *args):
        return command([self.qdbus, *args], timeout=5)

    def owner(self, name):
        pid = int(self.bus("org.freedesktop.DBus", "/org/freedesktop/DBus",
                           "org.freedesktop.DBus.GetConnectionUnixProcessID", name))
        identity = proc_identity(pid)
        require(identity and identity["uid"] == os.getuid() and not identity["dead"], "invalid D-Bus owner")
        return identity

    def desktop(self):
        shell = self.bus("org.kde.plasmashell", "/PlasmaShell",
                         "org.freedesktop.DBus.Properties.Get", "org.kde.PlasmaShell", "shell")
        config_names(shell)
        panels = json.loads(self.bus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript",
                                    "print(JSON.stringify(panels().map(function(p) { return {id:p.id,type:p.type}; })));"))
        require(len(panels) == 1 and panels[0]["type"] == PANEL and isinstance(panels[0]["id"], int),
                "expected one real Aero panel")
        return shell, panels[0]["id"], self.owner("org.kde.plasmashell")

    def service(self):
        output = command([SYSTEMCTL, "--user", "show", SERVICE,
                          "--property=ActiveState,SubState,MainPID,ControlGroup,ExecStart,KillMode"])
        return dict(line.split("=", 1) for line in output.splitlines() if "=" in line)

    def managed(self):
        info = self.service()
        require(info.get("ActiveState") == "active" and info.get("SubState") == "running", "original service not active")
        pid = int(info["MainPID"])
        identity = proc_identity(pid)
        require(identity and identity["uid"] == os.getuid() and not identity["dead"], "invalid original PID")
        base = PROC_ROOT / str(pid)
        require((base / "exe").resolve() == Path(PLASMA).resolve(), "original is not plasmashell")
        argv = (base / "cmdline").read_bytes().rstrip(b"\0").split(b"\0")
        require(argv == [PLASMA.encode(), b"--no-respawn"], "unexpected original command")
        require("path=/usr/bin/plasmashell ;" in info.get("ExecStart", "")
                and "argv[]=/usr/bin/plasmashell --no-respawn ;" in info["ExecStart"], "unexpected service ExecStart")
        self.check_cgroup(info["ControlGroup"], pid)
        return identity

    def check_cgroup(self, group, pid):
        require(group.startswith("/") and ".." not in Path(group).parts and group != "/", "invalid cgroup")
        directory = no_symlinks(CGROUP_ROOT / group.lstrip("/"))
        require(directory.is_dir(), "original cgroup unavailable")
        members = set()
        for path in [directory / "cgroup.procs", *directory.glob("**/cgroup.procs")]:
            members.update(int(p) for p in path.read_text().split())
        require(pid in members, "original main PID missing from managed cgroup")
        return members

    def stop_original(self, expected, expected_cgroup):
        # Extra members are preserved, never signalled: stopping is permitted only
        # with the effective process-only policy, rechecked immediately before stop.
        require(same_process(expected, self.managed()), "original service changed")
        info = self.service()
        require(info.get("KillMode") == "process", "process-only stop policy not effective")
        require(info.get("ControlGroup") == expected_cgroup and int(info["MainPID"]) == expected["pid"],
                "original managed cgroup changed")
        command([SYSTEMCTL, "--user", "stop", SERVICE], timeout=50)
        require(not same_process(expected, proc_identity(expected["pid"])), "original still writing")
        require(self.service().get("ActiveState") == "inactive", "original did not stop cleanly")

    def session_alive(self, state):
        try:
            return same_process(state["kwin"], self.owner("org.kde.KWin"))
        except (Unsafe, OSError, subprocess.SubprocessError, ValueError):
            return False

    def start_original(self):
        # No preview environment is ever installed in the systemd manager.
        command([SYSTEMCTL, "--user", "start", SERVICE], timeout=50)


def no_home_override(env):
    for identity in (PANEL, TASKS):
        path = Path(env["XDG_DATA_HOME"]) / "plasma/plasmoids" / identity
        require(not path.exists() and not path.is_symlink(), f"home package override beats shadow: {path}")


def validate_configs(state):
    home = no_symlinks(Path(state["env"]["XDG_CONFIG_HOME"]))
    require(home.is_dir(), "config home missing")
    for name in config_names(state["shell"]):
        path = no_symlinks(home / name)
        if path.exists():
            require(path.is_file() and path.stat().st_uid == os.getuid(), f"invalid config: {path}")


def preflight(platform, env):
    no_home_override(env)
    original = platform.managed()
    info = platform.service()
    require(int(info["MainPID"]) == original["pid"], "original service changed during preflight")
    require(info["KillMode"] in ("control-group", "mixed", "process", "none"), "unknown original KillMode")
    shell, panel_id, owner = platform.desktop()
    require(same_process(original, owner), "D-Bus shell is not managed service")
    state = {"version": 1, "uid": os.getuid(), "env": env, "shell": shell,
             "panel_id": panel_id, "original": original, "kwin": platform.owner("org.kde.KWin"),
             "qdbus": platform.qdbus, "original_kill_mode": info["KillMode"],
             "original_cgroup": info["ControlGroup"], "stop_policy": None,
             "restart_complete": False}
    validate_configs(state)
    return state


def independent_copy(source, destination):
    source, destination = no_symlinks(source), no_symlinks(destination)
    a, b = source.resolve(), destination.resolve()
    require(a != b and a not in b.parents and b not in a.parents, "copy paths overlap")
    require(source.is_dir() and not destination.exists(), "invalid package copy")
    for path in source.rglob("*"):
        require(not path.is_symlink() and (path.is_dir() or path.is_file()), f"unsupported package entry: {path}")
    shutil.copytree(source, destination)


def inject_exit(main, restore_command):
    # The installed root is deliberately retained, not replaced by repository QML.
    match = re.search(r"}\s*\Z", main)
    require(match is not None, "installed panel must end with its root brace")
    return main[:match.start()] + ("\n    Win7PanelPreviewExit { panelId: Plasmoid.id; restoreCommand: "
                                    + json.dumps(restore_command) + " }\n") + main[match.start():]


def prepare(root, platform, env, timeout=600, repo=ROOT, installed=INSTALLED):
    require(1 <= timeout <= 600, "timeout must be between 1 and 600 seconds")
    private_dir(root)
    with locked(root):
        previous = active_session(root)
        if previous:
            require(load(previous)["phase"] == FINAL, "another session exists; restore it first")
        state = preflight(platform, env)
        token = uuid.uuid4().hex
        session = private_dir(root / token)
        # Reserve immediately; failures retain an explicitly recoverable private session.
        state.update(unit=f"win7-panel-preview-{token}.service", phase="preparing", timeout=timeout,
                     restore_needed=False, stop_requested=False, preview=None, snapshots={})
        save(session, state)
        private_dir(session / "snapshots")
        recovery = Path(__file__).resolve().read_bytes()
        atomic_bytes(session / "recovery.py", recovery)
        atomic_bytes(root / "active", token.encode())
        try:
            packages = session / "shadow/share/plasma/plasmoids"
            packages.mkdir(parents=True, mode=0o700)
            independent_copy(installed / PANEL, packages / PANEL)
            independent_copy(repo / "plasma/plasmoids" / TASKS, packages / TASKS)
            panel_ui = packages / PANEL / "contents/ui"
            shutil.copyfile(repo / "scripts/panel-preview/PreviewExit.qml", panel_ui / "Win7PanelPreviewExit.qml")
            restore_command = shlex.join([SYSTEMCTL, "--user", "--no-block", "stop", state["unit"]])
            main = panel_ui / "main.qml"
            main.write_text(inject_exit(main.read_text(), restore_command))
            state["phase"] = "prepared"
            save(session, state)
        except BaseException:
            state["phase"] = "prepare-failed"
            save(session, state)
            raise
        return session


def active_session(root):
    pointer = no_symlinks(root / "active")
    if not pointer.exists():
        return None
    name = pointer.read_text()
    require(re.fullmatch(r"[0-9a-f]{32}", name), "invalid active pointer")
    return no_symlinks(root / name)


def stop_policy_paths(state):
    runtime = no_symlinks(RUNTIME_BASE / str(state["uid"]))
    require(state["env"].get("XDG_RUNTIME_DIR") == str(runtime), "noncanonical user runtime directory")
    info = runtime.stat()
    require(info.st_uid == state["uid"] and stat.S_IMODE(info.st_mode) == 0o700
            and stat.S_ISDIR(info.st_mode), "unsafe user runtime directory")
    directory = no_symlinks(runtime / "systemd/user" / (SERVICE + ".d"))
    token = state["unit"].removesuffix(".service")
    return directory / ("zzzz-" + token + ".conf"), directory / ("." + token + ".payload")


def policy_content(state):
    return f"# Transaction-owned: {state['unit']}\n[Service]\nKillMode=process\n"


def validate_policy_record(state):
    record = state["stop_policy"]
    final, payload = stop_policy_paths(state)
    content = policy_content(state)
    require(record["path"] == str(final) and record["payload"] == str(payload)
            and record["content"] == content
            and record["sha256"] == hashlib.sha256(content.encode()).hexdigest()
            and record["uid"] == state["uid"] and record["mode"] == 0o600,
            "invalid runtime stop-policy ownership record")
    return final, payload


def owned_policy_file(path, record):
    # Missing links are normal after interrupted cleanup. Any present object must
    # prove identity AND unchanged contents; identical-content foreign files fail.
    try:
        fd = os.open(no_symlinks(path), os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except FileNotFoundError:
        return False
    try:
        info = os.fstat(fd)
        require(stat.S_ISREG(info.st_mode) and record.get("inode") == info.st_ino
                and record.get("device") == info.st_dev and info.st_uid == record["uid"]
                and stat.S_IMODE(info.st_mode) == record["mode"], "runtime stop-policy file is not owned")
        with os.fdopen(fd, "rb", closefd=False) as stream:
            data = stream.read()
        require(hashlib.sha256(data).hexdigest() == record["sha256"], "runtime stop-policy content changed")
        return True
    finally:
        os.close(fd)


def setup_stop_policy(session, state, platform):
    mode = platform.service().get("KillMode")
    require(mode == state["original_kill_mode"], "original KillMode changed since prepare")
    if mode == "process":
        return
    final, payload = stop_policy_paths(state)
    content = policy_content(state)
    record = {"path": str(final), "payload": str(payload), "content": content,
              "sha256": hashlib.sha256(content.encode()).hexdigest(), "uid": state["uid"],
              "mode": 0o600, "inode": None, "device": None, "needs_reload": False, "cleaned": False}
    state.update(stop_policy=record, phase="policy-planned")
    save(session, state)  # canonical paths and expected bytes precede all creation
    final.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory = final.parent.stat()
    require(directory.st_uid == state["uid"] and not directory.st_mode & 0o022, "unsafe runtime drop-in directory")
    fd = os.open(payload, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "wb", closefd=False) as stream:
            stream.write(content.encode())
            stream.flush()
            os.fchmod(fd, 0o600)
            os.fsync(fd)
        info = os.fstat(fd)
    finally:
        os.close(fd)
    fsync_dir(final.parent)
    record.update(inode=info.st_ino, device=info.st_dev)
    state["phase"] = "policy-staged"
    save(session, state)  # identity is durable BEFORE exclusive atomic publication
    os.link(payload, final, follow_symlinks=False)
    fsync_dir(final.parent)
    state["phase"] = "policy-published"
    record["needs_reload"] = True
    save(session, state)
    command([SYSTEMCTL, "--user", "daemon-reload"])
    require(owned_policy_file(final, record), "published stop-policy file disappeared")
    require(platform.service().get("KillMode") == "process", "process-only stop policy not effective")
    state["phase"] = "policy-applied"
    save(session, state)


def cleanup_stop_policy(session, state, platform):
    record = state.get("stop_policy")
    if not record or record["cleaned"]:
        return
    final, payload = validate_policy_record(state)
    if record["inode"] is None:
        # A crash before the inode commit can leave an inert .payload orphan.
        # Neither it nor any colliding final file has proven transaction ownership.
        require(not final.exists() and not final.is_symlink(), "unproven runtime drop-in; not removing")
        record["cleaned"] = True
        save(session, state)
        return
    final_owned = owned_policy_file(final, record)
    payload_owned = owned_policy_file(payload, record)
    record["needs_reload"] = record["needs_reload"] or final_owned
    state["phase"] = "policy-cleaning"
    save(session, state)  # recovery must reload even if it dies after unlink
    if final_owned:
        final.unlink()
    if payload_owned:
        payload.unlink()
    fsync_dir(final.parent)
    if record["needs_reload"]:
        command([SYSTEMCTL, "--user", "daemon-reload"])
        require(platform.service().get("KillMode") == state["original_kill_mode"], "original KillMode not restored")
    record.update(needs_reload=False, cleaned=True)
    save(session, state)


def snapshot_flushed(session, state):
    validate_configs(state)
    records = {}
    for name in config_names(state["shell"]):
        path = Path(state["env"]["XDG_CONFIG_HOME"]) / name
        if not path.exists():
            records[name] = {"exists": False}
            continue
        data = path.read_bytes()
        atomic_bytes(session / "snapshots" / name, data)
        records[name] = {"exists": True, "mode": stat.S_IMODE(path.stat().st_mode),
                         "sha256": hashlib.sha256(data).hexdigest()}
    # This single commit makes the complete post-stop snapshot authoritative.
    state.update(snapshots=records, restore_needed=True, phase="snapshotted")
    save(session, state)


def restore_files(session, state):
    validate_configs(state)
    require(set(state["snapshots"]) == set(config_names(state["shell"])), "incomplete snapshot")
    # Validate every snapshot before writing any config. Repeating a partial restore is safe.
    data = {}
    for name, record in state["snapshots"].items():
        if record["exists"]:
            data[name] = no_symlinks(session / "snapshots" / name).read_bytes()
            require(hashlib.sha256(data[name]).hexdigest() == record["sha256"], "snapshot checksum mismatch")
    home = Path(state["env"]["XDG_CONFIG_HOME"])
    for name, record in state["snapshots"].items():
        target = home / name
        if record["exists"]:
            atomic_bytes(target, data[name], record["mode"])
        elif target.exists():
            target.unlink()
            fsync_dir(home)


def terminate_preview(expected, grace=8):
    if not expected or not same_process(expected, proc_identity(expected["pid"])):
        return
    require(expected["uid"] == os.getuid(), "refusing foreign PID")
    # A pidfd closes the check/signal PID-reuse race; never signal a process group.
    try:
        fd = os.pidfd_open(expected["pid"])
    except ProcessLookupError:
        return
    try:
        if not same_process(expected, proc_identity(expected["pid"])):
            return
        try:
            signal.pidfd_send_signal(fd, signal.SIGTERM)
        except ProcessLookupError:
            return
        deadline = time.monotonic() + grace
        while same_process(expected, proc_identity(expected["pid"])) and time.monotonic() < deadline:
            time.sleep(0.05)
        if same_process(expected, proc_identity(expected["pid"])):
            try:
                signal.pidfd_send_signal(fd, signal.SIGKILL)
            except ProcessLookupError:
                return
        deadline = time.monotonic() + 5
        while same_process(expected, proc_identity(expected["pid"])) and time.monotonic() < deadline:
            time.sleep(0.05)
        require(not same_process(expected, proc_identity(expected["pid"])), "preview still writing; configs NOT restored")
    finally:
        os.close(fd)


def recover(session, platform=None):
    with locked(session):
        state = load(session)
        if state["phase"] == FINAL:
            return state
        # This phase cancels even a helper that has not yet acquired the lock.
        state["phase"] = "restoring"
        save(session, state)
        terminate_preview(state["preview"])
        if state["restore_needed"]:
            restore_files(session, state)
            # Commit before starting the normal shell: a second recovery must not
            # overwrite configs that a successfully restarted shell is writing.
            state["restore_needed"] = False
            state["phase"] = "configs-restored"
            save(session, state)
        platform = platform or Platform(state["qdbus"])
        if not state.get("restart_complete", False):
            state["original_restarted"] = False
            if state["stop_requested"] and platform.session_alive(state):
                require(platform.service().get("KillMode") == "process", "restart requires process-only policy")
                platform.start_original()
                state["original_restarted"] = True
            state["restart_complete"] = True
            state["phase"] = "original-restart-complete"
            save(session, state)
        cleanup_stop_policy(session, state, platform)
        state["phase"] = FINAL
        save(session, state)
        return state


def launch_shim(session):
    with locked(session):
        state = load(session)
        if state["phase"] != "launching" or state["preview"] is not None:
            return
        identity = proc_identity(os.getpid())
        require(identity and identity["uid"] == os.getuid(), "cannot record launcher ownership")
        state["preview"] = identity
        state["phase"] = "starting"
        save(session, state)
        env = os.environ.copy()
        env.update(state["env"])
        env["XDG_DATA_DIRS"] = str(session / "shadow/share") + ":" + state["env"]["XDG_DATA_DIRS"]
        # Keep the lock until exec: recovery must either cancel us before recording,
        # or see this exact PID/starttime. flock fd is close-on-exec.
        os.execve(PLASMA, [PLASMA, "--no-respawn", "--shell-plugin", state["shell"]], env)


def centered_marker(log, panel_id):
    for line in log.splitlines():
        if "WIN7_PANEL_EXIT_READY " not in line:
            continue
        try:
            marker, _ = json.JSONDecoder().raw_decode(line.split("WIN7_PANEL_EXIT_READY ", 1)[1])
            dimensions = [marker[k] for k in ("panelWidth", "panelHeight", "width", "height")]
            if not all(isinstance(v, (int, float)) and math.isfinite(v) and v > 0 for v in dimensions):
                continue
            if (marker["panelId"] == panel_id and marker["centered"] is True and marker["text"] == "Exit preview"
                    and marker["width"] <= marker["panelWidth"] and marker["height"] <= marker["panelHeight"]
                    and abs(marker["x"] + marker["width"] / 2 - marker["panelWidth"] / 2) < 0.5
                    and abs(marker["y"] + marker["height"] / 2 - marker["panelHeight"] / 2) < 0.5):
                return True
        except (ValueError, KeyError, TypeError):
            pass
    return False


def ready(session, state, platform):
    if not state["preview"] or not same_process(state["preview"], proc_identity(state["preview"]["pid"])):
        return False
    if not centered_marker((session / "shell.log").read_text(errors="replace"), state["panel_id"]):
        return False
    try:
        shell, panel_id, owner = platform.desktop()
        return (shell == state["shell"] and panel_id == state["panel_id"]
                and same_process(state["preview"], owner))
    except (Unsafe, subprocess.SubprocessError, ValueError):
        return False


def guardian(session, platform=None):
    state = load(session)
    platform = platform or Platform(state["qdbus"])
    with locked(session):
        state = load(session)
        require(state["phase"] == "armed", "guardian launch cancelled")
        no_home_override(state["env"])
        validate_configs(state)
        require(platform.session_alive(state), "desktop session ended")
        shell, panel_id, owner = platform.desktop()
        require(shell == state["shell"] and panel_id == state["panel_id"]
                and same_process(state["original"], owner), "desktop changed since prepare")
        setup_stop_policy(session, state, platform)
        state.update(phase="stopping-original", stop_requested=True)
        save(session, state)
        platform.stop_original(state["original"], state["original_cgroup"])
        snapshot_flushed(session, state)
        state["phase"] = "launching"
        save(session, state)
        with open(session / "shell.log", "ab", buffering=0) as log:
            subprocess.Popen([PYTHON, str(session / "recovery.py"), "_launch", str(session)],
                             stdout=log, stderr=subprocess.STDOUT, close_fds=True)
    deadline = time.monotonic() + STARTUP_SECONDS
    while time.monotonic() < deadline:
        with locked(session):
            state = load(session)
            if state["phase"] not in ("launching", "starting"):
                return
            if ready(session, state, platform):
                state["phase"] = "ready"
                save(session, state)
                break
            if state["preview"] and not same_process(state["preview"], proc_identity(state["preview"]["pid"])):
                raise Unsafe("preview exited before Exit control was ready")
        time.sleep(0.2)
    else:
        raise Unsafe("real panel/centered Exit marker not ready before startup deadline")
    while True:
        time.sleep(0.5)
        state = load(session)
        if (state["phase"] != "ready" or not same_process(state["preview"], proc_identity(state["preview"]["pid"]))
                or not platform.session_alive(state)):
            return


def systemd_word(value):
    # Exec command quoting, not shell quoting. ':' disables $ environment expansion.
    value = str(value)
    require(not any(ord(c) < 32 for c in value), "control character in unit argument")
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%") + '"'


def frozen_command(session, action):
    return ":" + " ".join(systemd_word(arg) for arg in (PYTHON, session / "recovery.py", action, session))


def unit_command(session, state):
    # Hex-encoded paths avoid systemd ExecStart specifiers and $ expansion entirely,
    # including when HOME contains quotes, spaces, dollar signs or percent signs.
    bootstrap = ("import runpy,sys;sys.argv=[bytes.fromhex('" + str(session / "recovery.py").encode().hex()
                 + "').decode(),'_guardian',bytes.fromhex('" + str(session).encode().hex()
                 + "').decode()];runpy.run_path(sys.argv[0],run_name='__main__')")
    args = [SYSTEMD_RUN, "--user", "--unit=" + state["unit"], "--property=Type=exec",
            "--property=KillMode=process", "--property=RuntimeMaxSec=" + str(state["timeout"]),
            "--property=TimeoutStopSec=90", "--property=Restart=no",
            "--property=ExecStopPost=" + frozen_command(session, "_recover")]
    # Set captured nonsecret values inside Python, not via systemd's Environment
    # parser (whose specifier handling differs from exec-command quoting).
    return [*args, PYTHON, "-c", bootstrap]


def recovery_entry(session):
    private_dir(session)
    fd = os.open(session / "recovery.log", os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "a", buffering=1) as log:
        print(f"{time.time():.3f} recovery begin", file=log)
        try:
            result = recover(session)
        except BaseException as error:
            print(f"{time.time():.3f} recovery failed: {error}", file=log)
            raise
        print(f"{time.time():.3f} recovery complete: {result['phase']}", file=log)
        os.fsync(log.fileno())


def frozen_recover(session):
    with open(session / "recovery.log", "ab", buffering=0) as log:
        subprocess.run([PYTHON, str(session / "recovery.py"), "_recover", str(session)],
                       check=True, stdout=log, stderr=subprocess.STDOUT, timeout=100)


def public_restore(session):
    state = load(session)
    if state["phase"] == FINAL:
        return state
    # Do not hold the state lock across systemctl: ExecStopPost needs that lock.
    try:
        command([SYSTEMCTL, "--user", "stop", state["unit"]], timeout=100)
    except subprocess.SubprocessError:
        pass
    # Even an absent/failed unit or a prepare-only session has independent recovery.
    frozen_recover(session)
    return load(session)


def start(session, timeout=None):
    with locked(session):
        state = load(session)
        require(state["phase"] == "prepared", "session is not prepared")
        require(environment() == state["env"], "environment changed since prepare")
        if timeout is not None:
            require(1 <= timeout <= 600, "timeout must be between 1 and 600 seconds")
            state["timeout"] = timeout
        state["phase"] = "armed"
        save(session, state)
    try:
        command(unit_command(session, state), timeout=15)
        deadline = time.monotonic() + STARTUP_SECONDS + 60
        while time.monotonic() < deadline:
            current = load(session)
            if current["phase"] == "ready":
                return current
            if current["phase"] == FINAL:
                raise Unsafe("preview startup failed and was restored; see session logs/journal")
            time.sleep(0.2)
        raise Unsafe("preview startup failed to report ready")
    except BaseException:
        public_restore(session)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("start", "prepare", "check", "status", "restore", "_guardian", "_recover", "_launch"))
    parser.add_argument("session", nargs="?", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--timeout", type=int, default=None, help="automatic return in 1–600 seconds (default 600)")
    args = parser.parse_args()
    if args.action.startswith("_"):
        require(args.session is not None, "internal action requires session")
        os.environ.update(load(args.session)["env"])
        if args.action == "_guardian":
            try:
                guardian(args.session)
            finally:
                # ExecStopPost also repeats this if the guardian cannot run finally.
                frozen_recover(args.session)
        elif args.action == "_launch":
            launch_shim(args.session)
        else:
            recovery_entry(args.session)
        return
    require(args.session is None, "public actions use the managed active session only")
    if args.action == "check":
        state = preflight(Platform(), environment())
        print(json.dumps({"shell": state["shell"], "panel_id": state["panel_id"], "managed": True}))
        return
    root = state_root()
    if args.action in ("prepare", "start"):
        private_dir(root)
        # Reserve/arm transitions are serialized again inside prepare/start.
        with locked(root):
            session = active_session(root)
            reuse = session is not None and load(session)["phase"] == "prepared"
        if args.action == "prepare" or not reuse:
            session = prepare(root, Platform(), environment(), 600 if args.timeout is None else args.timeout)
        if args.action == "start":
            start(session, args.timeout)
        state = load(session)
    else:
        if not root.exists():
            print("No panel preview session.")
            return
        session = active_session(root)
        if not session:
            print("No panel preview session.")
            return
        state = public_restore(session) if args.action == "restore" else load(session)
    print(json.dumps({"session": str(session), "phase": state["phase"], "unit": state["unit"],
                      "shell_log": str(session / "shell.log"), "automatic_return_seconds": state["timeout"]}, indent=2))
    print("Emergency restore (independent of panel): " + shlex.join([PYTHON, str(Path(__file__).resolve()), "restore"]))
    print("Automatic recovery begins within 10 minutes of service activation (or the shorter requested timeout).")
    print("Recovery diagnostics: " + shlex.join([SYSTEMCTL, "--user", "status", state["unit"]]))


if __name__ == "__main__":
    try:
        main()
    except (Unsafe, OSError, ValueError, subprocess.SubprocessError) as error:
        print("panel-preview: " + str(error), file=sys.stderr)
        sys.exit(1)
