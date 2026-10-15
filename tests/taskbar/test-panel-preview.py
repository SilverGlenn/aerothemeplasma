#!/usr/bin/env python3
"""Real controller tests: temporary files and mocked platform/process operations only.

No test stops/starts systemd or launches Plasma. The only subprocess recovery test
uses a prepare-only state, for which production recovery makes no platform calls.
"""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shlex
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("panel_preview", ROOT / "scripts/panel-preview.py")
p = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(p)


def identity(pid=12345, ticks=54321, uid=None):
    return {"pid": pid, "ticks": ticks, "uid": os.getuid() if uid is None else uid, "dead": False}


def marker(panel_id=2, **updates):
    data = dict(panelId=panel_id, panelWidth=1920, panelHeight=40,
                x=900, y=10, width=120, height=20, text="Exit preview", centered=True)
    data.update(updates)
    return "qml: WIN7_PANEL_EXIT_READY " + json.dumps(data)


class FakePlatform:
    qdbus = "/fake/qdbus6"

    def __init__(self, test):
        self.test = test
        self.original = identity()
        self.kwin = identity(22222, 33333)
        self.shell_owner = self.original
        self.alive = True
        self.stops = 0
        self.starts = 0
        self.flushed = b"flushed original\x00\xff\n"

    def managed(self):
        return self.original

    def desktop(self):
        return p.SHELL, 2, self.shell_owner

    def owner(self, name):
        return self.kwin if name == "org.kde.KWin" else self.shell_owner

    def session_alive(self, state):
        return self.alive

    def stop_original(self, expected):
        self.test.assertEqual(expected, self.original)
        self.stops += 1
        self.test.layout.write_bytes(self.flushed)

    def start_original(self):
        self.starts += 1


class ControllerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="panel-preview-test-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.home = self.base / "home"
        self.config = self.home / ".config"
        self.config.mkdir(parents=True)
        self.data = self.home / ".local/share"
        self.data.mkdir(parents=True)
        self.env = p.environment({"HOME": str(self.home), "XDG_CONFIG_HOME": str(self.config),
                                  "XDG_DATA_HOME": str(self.data), "XDG_RUNTIME_DIR": str(self.base / "runtime"),
                                  "DISPLAY": ":1", "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus",
                                  "TOKEN": "do-not-record", "AWS_SECRET_ACCESS_KEY": "do-not-record"})
        self.state_root = self.home / ".local/state/preview"
        self.repo = self.base / "repo"
        self.installed = self.base / "installed"
        panel_ui = self.installed / p.PANEL / "contents/ui"
        panel_ui.mkdir(parents=True)
        self.installed_main = panel_ui / "main.qml"
        self.installed_main.write_text("import QtQuick\nContainmentItem {\n id: root\n // installed, not repo\n}\n  \n")
        (panel_ui / "keep.qml").write_bytes(b"other installed panel code")
        (self.installed / p.PANEL / "metadata.json").write_text('{"KPlugin":{"Id":"' + p.PANEL + '"}}')
        tasks = self.repo / "plasma/plasmoids" / p.TASKS
        tasks.mkdir(parents=True)
        (tasks / "fork.qml").write_bytes(b"fork Task package")
        exit_qml = self.repo / "scripts/panel-preview/PreviewExit.qml"
        exit_qml.parent.mkdir(parents=True)
        exit_qml.write_bytes((ROOT / "scripts/panel-preview/PreviewExit.qml").read_bytes())
        self.layout = self.config / ("plasma-" + p.SHELL + "-appletsrc")
        self.layout.write_bytes(b"pre-stop config\x00\xfe")
        self.layout.chmod(0o640)
        self.rc = self.config / "plasmashellrc"
        self.rc.write_bytes(b"rc-original\r\n")
        self.rc.chmod(0o604)
        self.stock = self.config / "plasma-org.kde.plasma.desktop-appletsrc"
        self.stock.write_bytes(b"unrelated stock config")
        self.platform = FakePlatform(self)
        self.session = None
        # Any accidentally unmocked controller command is a test failure, never a
        # real systemd/D-Bus invocation. The frozen subprocess test has no live calls.
        self.commands = patch.object(p, "command", side_effect=AssertionError("unmocked platform command"))
        self.commands.start()
        self.addCleanup(self.commands.stop)

    def prepare(self):
        self.session = p.prepare(self.state_root, self.platform, self.env, repo=self.repo, installed=self.installed)
        return self.session

    def state(self):
        return p.load(self.session)

    def snapshot(self):
        if self.session is None:
            self.prepare()
        state = self.state()
        state.update(stop_requested=True, phase="stopping-original")
        p.save(self.session, state)
        self.platform.stop_original(state["original"])
        p.snapshot_flushed(self.session, state)
        return state

    def recover(self):
        return p.recover(self.session, self.platform)

    def test_prepare_is_private_and_does_not_edit_any_original(self):
        before = {path: (path.read_bytes(), stat.S_IMODE(path.stat().st_mode))
                  for path in [self.layout, self.rc, self.stock, self.installed_main]}
        self.prepare()
        self.assertEqual(before, {path: (path.read_bytes(), stat.S_IMODE(path.stat().st_mode)) for path in before})
        self.assertEqual((self.platform.stops, self.platform.starts), (0, 0))
        self.assertEqual(self.state()["phase"], "prepared")
        self.assertFalse(self.state()["restore_needed"])
        self.assertEqual(stat.S_IMODE(self.session.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((self.session / "state.json").stat().st_mode), 0o600)
        self.assertEqual((self.session / "recovery.py").read_bytes(), Path(p.__file__).read_bytes())
        self.assertNotIn("do-not-record", (self.session / "state.json").read_text())
        ui = self.session / "shadow/share/plasma/plasmoids" / p.PANEL / "contents/ui"
        self.assertIn("installed, not repo", (ui / "main.qml").read_text())
        self.assertEqual((ui / "keep.qml").read_bytes(), b"other installed panel code")
        self.assertEqual((ui / "Win7PanelPreviewExit.qml").read_bytes(),
                         (ROOT / "scripts/panel-preview/PreviewExit.qml").read_bytes())
        self.assertIn("anchors.centerIn: parent", (ui / "Win7PanelPreviewExit.qml").read_text())
        line = next(line for line in (ui / "main.qml").read_text().splitlines() if "restoreCommand:" in line)
        quoted = line.split("restoreCommand: ", 1)[1].rsplit(" }", 1)[0]
        self.assertEqual(shlex.split(json.loads(quoted)),
                         [p.SYSTEMCTL, "--user", "--no-block", "stop", self.state()["unit"]])
        task = self.session / "shadow/share/plasma/plasmoids" / p.TASKS / "fork.qml"
        self.assertEqual(task.read_bytes(), b"fork Task package")

    def test_shell_specific_filename_and_rejection(self):
        self.assertEqual(p.config_names(p.SHELL), (self.layout.name, "plasmashellrc"))
        for shell in ("org.kde.plasma.desktop", "../../escape", p.SHELL + "/bad", "", p.SHELL + "\n"):
            with self.subTest(shell=shell), self.assertRaises(p.Unsafe):
                p.config_names(shell)

    def test_overlapping_prepared_session_is_not_overwritten(self):
        self.prepare()
        pointer = (self.state_root / "active").read_bytes()
        with self.assertRaises(p.Unsafe):
            self.prepare()
        self.assertEqual((self.state_root / "active").read_bytes(), pointer)
        self.recover()
        previous = self.session
        self.prepare()
        self.assertNotEqual(previous, self.session)
        self.assertTrue((previous / "state.json").exists())

    def test_prepare_rejects_home_override_including_dangling_symlink(self):
        package = self.data / "plasma/plasmoids" / p.TASKS
        package.parent.mkdir(parents=True)
        package.symlink_to(self.base / "absent")
        with self.assertRaisesRegex(p.Unsafe, "home package override"):
            self.prepare()
        self.assertEqual(self.platform.stops, 0)

    def test_prepare_rejects_critical_config_and_state_symlinks(self):
        target = self.base / "real"
        target.write_bytes(self.layout.read_bytes())
        self.layout.unlink()
        self.layout.symlink_to(target)
        with self.assertRaisesRegex(p.Unsafe, "symlink"):
            self.prepare()
        self.assertEqual(self.platform.stops, 0)
        self.layout.unlink()
        self.layout.write_bytes(b"normal")
        alias = self.base / "alias"
        alias.symlink_to(self.home, target_is_directory=True)
        with self.assertRaisesRegex(p.Unsafe, "symlink"):
            p.private_dir(alias / "state")

    def test_copy_rejects_overlap_alias_and_nested_symlinks(self):
        source = self.installed / p.PANEL
        with self.assertRaisesRegex(p.Unsafe, "overlap"):
            p.independent_copy(source, source / "nested")
        alias = self.base / "alias"
        alias.symlink_to(source, target_is_directory=True)
        with self.assertRaisesRegex(p.Unsafe, "symlink"):
            p.independent_copy(alias, self.base / "copy")
        (source / "alias").symlink_to(self.base / "missing")
        with self.assertRaisesRegex(p.Unsafe, "unsupported package entry"):
            p.independent_copy(source, self.base / "copy")

    def test_injection_rejects_trailing_nonwhitespace_and_uses_json_quoting(self):
        with self.assertRaises(p.Unsafe):
            p.inject_exit("ContainmentItem {}\n// trailing content", "command")
        text = p.inject_exit("ContainmentItem { id: root } \n", 'a"b\\c\n')
        self.assertTrue(text.endswith("} \n"))
        self.assertIn(json.dumps('a"b\\c\n'), text)

    def test_poststop_bytes_modes_and_only_two_configs_restored(self):
        self.snapshot()
        self.layout.write_bytes(b"preview changes")
        self.layout.chmod(0o600)
        self.rc.write_bytes(b"preview rc")
        self.rc.chmod(0o644)
        state = self.recover()
        self.assertEqual(self.layout.read_bytes(), self.platform.flushed)
        self.assertEqual(stat.S_IMODE(self.layout.stat().st_mode), 0o640)
        self.assertEqual(self.rc.read_bytes(), b"rc-original\r\n")
        self.assertEqual(stat.S_IMODE(self.rc.stat().st_mode), 0o604)
        self.assertEqual(self.stock.read_bytes(), b"unrelated stock config")
        self.assertEqual(state["phase"], p.FINAL)
        self.assertFalse(state["restore_needed"])
        self.assertEqual(self.platform.starts, 1)
        self.recover()
        self.assertEqual(self.platform.starts, 1)

    def test_absent_poststop_config_is_removed_if_preview_creates_it(self):
        self.rc.unlink()
        state = self.snapshot()
        self.assertEqual(state["snapshots"]["plasmashellrc"], {"exists": False})
        self.rc.write_bytes(b"preview-created")
        self.recover()
        self.assertFalse(self.rc.exists())

    def test_crash_phases_before_snapshot_never_restore_prestop_data(self):
        self.prepare()
        for phase in ("preparing", "prepared", "prepare-failed", "armed", "stopping-original"):
            with self.subTest(phase=phase):
                state = self.state()
                state.update(phase=phase, stop_requested=(phase == "stopping-original"), restore_needed=False)
                p.save(self.session, state)
                self.layout.write_bytes(b"newly flushed, no authoritative snapshot")
                self.recover()
                self.assertEqual(self.layout.read_bytes(), b"newly flushed, no authoritative snapshot")
        self.assertEqual(self.platform.starts, 1)

    def test_crash_phases_after_snapshot_restore_then_start(self):
        self.snapshot()
        original_state = self.state()
        for phase in ("snapshotted", "launching", "starting", "ready", "restoring"):
            with self.subTest(phase=phase):
                state = copy.deepcopy(original_state)
                state["phase"] = phase
                p.save(self.session, state)
                self.layout.write_bytes(b"preview")
                self.recover()
                self.assertEqual(self.layout.read_bytes(), self.platform.flushed)
        self.assertEqual(self.platform.starts, 5)

    def test_crash_while_committing_snapshot_does_not_authorize_partial_backup(self):
        self.prepare()
        state = self.state()
        state.update(phase="stopping-original", stop_requested=True)
        p.save(self.session, state)
        self.layout.write_bytes(b"flushed after original stop")
        with patch.object(p, "save", side_effect=RuntimeError("simulated crash")):
            with self.assertRaises(RuntimeError):
                p.snapshot_flushed(self.session, state)
        self.assertFalse(self.state()["restore_needed"])
        self.recover()
        self.assertEqual(self.layout.read_bytes(), b"flushed after original stop")

    def test_partial_atomic_file_restore_can_be_repeated(self):
        self.snapshot()
        self.layout.write_bytes(b"changed")
        self.rc.write_bytes(b"changed rc")
        real_atomic = p.atomic_bytes
        def crash(path, data, mode=0o600):
            if path == self.rc:
                raise RuntimeError("power loss between restored files")
            return real_atomic(path, data, mode)
        with patch.object(p, "atomic_bytes", side_effect=crash):
            with self.assertRaises(RuntimeError):
                self.recover()
        self.assertEqual(self.platform.starts, 0)
        self.assertTrue(self.state()["restore_needed"])
        self.recover()
        self.assertEqual(self.rc.read_bytes(), b"rc-original\r\n")
        self.assertEqual(self.platform.starts, 1)

    def test_crash_after_normal_shell_restart_does_not_restore_again(self):
        self.snapshot()
        real_save = p.save
        def crash_final(session, state):
            if state["phase"] == p.FINAL:
                raise RuntimeError("crash after original restarted")
            return real_save(session, state)
        def start_and_flush():
            self.platform.starts += 1
            self.layout.write_bytes(b"newly restarted normal shell config")
        with patch.object(p, "save", side_effect=crash_final), \
                patch.object(self.platform, "start_original", side_effect=start_and_flush):
            with self.assertRaises(RuntimeError):
                self.recover()
        self.assertFalse(self.state()["restore_needed"])
        self.recover()
        self.assertEqual(self.layout.read_bytes(), b"newly restarted normal shell config")

    def test_logout_restores_files_without_resurrecting_shell(self):
        self.snapshot()
        self.platform.alive = False
        self.layout.write_bytes(b"preview")
        state = self.recover()
        self.assertEqual(self.layout.read_bytes(), self.platform.flushed)
        self.assertEqual(self.platform.starts, 0)
        self.assertFalse(state["original_restarted"])

    def test_corrupt_snapshot_and_new_config_symlink_fail_closed(self):
        self.snapshot()
        self.layout.write_bytes(b"preview")
        snapshot = self.session / "snapshots/plasmashellrc"
        good = snapshot.read_bytes()
        snapshot.write_bytes(b"corrupt")
        with self.assertRaisesRegex(p.Unsafe, "checksum"):
            self.recover()
        self.assertEqual(self.layout.read_bytes(), b"preview")
        snapshot.write_bytes(good)
        self.layout.unlink()
        self.layout.symlink_to(self.stock)
        with self.assertRaisesRegex(p.Unsafe, "symlink"):
            self.recover()
        self.assertEqual(self.stock.read_bytes(), b"unrelated stock config")
        self.assertEqual(self.platform.starts, 0)

    def test_recovery_never_writes_until_recorded_preview_is_dead(self):
        state = self.snapshot()
        state["preview"] = identity(44444)
        p.save(self.session, state)
        self.layout.write_bytes(b"preview still writing")
        with patch.object(p, "terminate_preview", side_effect=p.Unsafe("still writing")):
            with self.assertRaises(p.Unsafe):
                self.recover()
        self.assertEqual(self.layout.read_bytes(), b"preview still writing")
        self.assertEqual(self.platform.starts, 0)

    def test_early_guardian_spawn_failure_uses_authoritative_snapshot(self):
        self.prepare()
        state = self.state()
        state["phase"] = "armed"
        p.save(self.session, state)
        with patch.object(p.subprocess, "Popen", side_effect=OSError("failed launch")):
            with self.assertRaises(OSError):
                p.guardian(self.session, self.platform)
        self.assertTrue(self.state()["restore_needed"])
        self.recover()
        self.assertEqual(self.layout.read_bytes(), self.platform.flushed)
        self.assertEqual((self.platform.stops, self.platform.starts), (1, 1))

    def test_guardian_entry_automatically_recovers_on_startup_marker_failure(self):
        self.prepare()
        state = self.state()
        state["phase"] = "armed"
        p.save(self.session, state)
        with patch.object(sys, "argv", [p.__file__, "_guardian", str(self.session)]), \
                patch.dict(os.environ), patch.object(p, "Platform", return_value=self.platform), \
                patch.object(p.subprocess, "Popen"), patch.object(p, "STARTUP_SECONDS", 0), \
                patch.object(p, "frozen_recover", side_effect=lambda session: self.recover()) as recovery:
            with self.assertRaisesRegex(p.Unsafe, "centered Exit marker"):
                p.main()
            recovery.assert_called_once_with(self.session)
        self.assertEqual(self.state()["phase"], p.FINAL)
        self.assertEqual(self.layout.read_bytes(), self.platform.flushed)
        self.assertEqual((self.platform.stops, self.platform.starts), (1, 1))

    def test_guardian_marks_ready_only_after_owned_real_panel_and_marker(self):
        self.prepare()
        state = self.state()
        state["phase"] = "armed"
        p.save(self.session, state)
        preview = identity(44444)
        observed_ready = []
        def fake_launch(args, **kwargs):
            state = self.state()
            state.update(preview=preview, phase="starting")
            p.save(self.session, state)
            self.platform.shell_owner = preview
            kwargs["stdout"].write(marker().encode())
            return Mock()
        def monitor(seconds):
            self.assertEqual(seconds, 0.5)
            state = self.state()
            observed_ready.append(state["phase"])
            state["phase"] = "restoring"  # unit stop requested after ready
            p.save(self.session, state)
        with patch.object(p.subprocess, "Popen", side_effect=fake_launch), \
                patch.object(p, "proc_identity", return_value=preview), patch.object(p.time, "sleep", side_effect=monitor):
            p.guardian(self.session, self.platform)
        self.assertEqual(observed_ready, ["ready"])
        self.assertEqual(self.platform.stops, 1)

    def test_home_override_appearing_after_prepare_blocks_original_stop(self):
        self.prepare()
        state = self.state()
        state["phase"] = "armed"
        p.save(self.session, state)
        (self.data / "plasma/plasmoids" / p.PANEL).mkdir(parents=True)
        with self.assertRaisesRegex(p.Unsafe, "home package override"):
            p.guardian(self.session, self.platform)
        self.recover()
        self.assertEqual((self.platform.stops, self.platform.starts), (0, 0))

    def test_missing_exit_marker_times_out_and_late_helper_is_cancelled(self):
        self.prepare()
        state = self.state()
        state["phase"] = "armed"
        p.save(self.session, state)
        with patch.object(p.subprocess, "Popen") as spawn, patch.object(p, "STARTUP_SECONDS", 0):
            with self.assertRaisesRegex(p.Unsafe, "centered Exit marker"):
                p.guardian(self.session, self.platform)
        self.assertEqual(spawn.call_args.args[0][2], "_launch")
        self.assertEqual(spawn.call_args.kwargs["close_fds"], True)
        self.recover()
        with patch.object(p.os, "execve") as execute:
            p.launch_shim(self.session)
            execute.assert_not_called()
        self.assertEqual(self.state()["phase"], p.FINAL)

    def test_preexec_shim_records_identity_and_preserves_normal_home_config_data(self):
        self.snapshot()
        state = self.state()
        state["phase"] = "launching"
        p.save(self.session, state)
        class Executed(Exception):
            pass
        def execute(binary, argv, env):
            stored = self.state()
            self.assertEqual(stored["preview"], p.proc_identity(os.getpid()))
            self.assertEqual(stored["phase"], "starting")
            self.assertEqual(binary, p.PLASMA)
            self.assertEqual(argv, [p.PLASMA, "--no-respawn", "--shell-plugin", p.SHELL])
            for key in ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS"):
                self.assertEqual(env[key], self.env[key])
            self.assertEqual(env["XDG_DATA_DIRS"], str(self.session / "shadow/share") + ":" + self.env["XDG_DATA_DIRS"])
            raise Executed()
        with patch.object(p.os, "execve", side_effect=execute):
            with self.assertRaises(Executed):
                p.launch_shim(self.session)

    def test_recovery_and_late_helper_lock_order(self):
        self.snapshot()
        state = self.state()
        state["phase"] = "launching"
        p.save(self.session, state)
        helper_waiting = threading.Event()
        release_helper = threading.Event()
        errors = []
        def delayed_helper():
            helper_waiting.set()  # Popen happened, but no PID has yet been recorded.
            release_helper.wait(3)
            try:
                p.launch_shim(self.session)
            except BaseException as error:
                errors.append(error)
        with patch.object(p.os, "execve") as execute:
            thread = threading.Thread(target=delayed_helper)
            thread.start()
            self.assertTrue(helper_waiting.wait(3))
            self.recover()
            release_helper.set()
            thread.join(3)
            self.assertFalse(thread.is_alive())
            execute.assert_not_called()
        self.assertEqual(errors, [])
        self.assertEqual(self.state()["phase"], p.FINAL)

    def test_recorded_shim_is_terminated_before_restoration_in_reverse_race(self):
        self.snapshot()
        state = self.state()
        state["phase"] = "launching"
        p.save(self.session, state)
        entered_exec = threading.Event()
        release_exec = threading.Event()
        recovered = threading.Event()
        errors = []
        def execute(*args):
            entered_exec.set()
            if not release_exec.wait(3):
                raise RuntimeError("test exec wait timed out")
            raise OSError("test fake exec")
        def helper():
            try:
                p.launch_shim(self.session)
            except OSError:
                pass
            except BaseException as error:
                errors.append(error)
        def restore():
            try:
                self.recover()
                recovered.set()
            except BaseException as error:
                errors.append(error)
        def terminate(expected):
            self.assertEqual(expected["pid"], os.getpid())
            self.assertTrue(entered_exec.is_set())
            self.assertTrue(release_exec.is_set())
        with patch.object(p.os, "execve", side_effect=execute), patch.object(p, "terminate_preview", side_effect=terminate):
            first = threading.Thread(target=helper)
            first.start()
            self.assertTrue(entered_exec.wait(3))
            second = threading.Thread(target=restore)
            second.start()
            self.assertFalse(recovered.wait(0.05))
            release_exec.set()
            first.join(3)
            second.join(3)
            self.assertFalse(first.is_alive() or second.is_alive())
        self.assertTrue(recovered.is_set())
        self.assertEqual(errors, [])

    def test_ready_requires_owned_dbus_shell_real_panel_and_centered_marker(self):
        self.snapshot()
        state = self.state()
        state.update(preview=identity(44444), phase="starting")
        log = self.session / "shell.log"
        log.write_text(marker())
        self.platform.shell_owner = state["preview"]
        with patch.object(p, "proc_identity", return_value=state["preview"]):
            self.assertTrue(p.ready(self.session, state, self.platform))
            self.platform.shell_owner = identity(44444, ticks=999)
            self.assertFalse(p.ready(self.session, state, self.platform))
            self.platform.shell_owner = state["preview"]
            for text in ("", marker(centered=False), marker(x=901), marker(panel_id=3),
                         marker(width=0), marker(panelHeight=0), marker(text="other"),
                         marker(width=float("nan")), marker(height=50)):
                log.write_text(text)
                self.assertFalse(p.ready(self.session, state, self.platform), text)

    def test_unit_is_unique_bounded_process_only_with_frozen_execstoppost(self):
        self.prepare()
        state = self.state()
        args = p.unit_command(self.session, state)
        self.assertIn("--property=KillMode=process", args)
        self.assertIn("--property=RuntimeMaxSec=600", args)
        self.assertIn("--property=Restart=no", args)
        self.assertIn("--unit=" + state["unit"], args)
        self.assertIn("--property=ExecStopPost=" + p.frozen_command(self.session, "_recover"), args)
        self.assertTrue(all("shadow" not in value for value in args if value.startswith("--setenv=")))
        self.assertFalse(any("TOKEN" in value or "SECRET" in value for value in args))
        self.assertNotIn("--scope", args)
        self.assertNotIn("set-environment", args)
        self.assertNotIn("KillMode=control-group", " ".join(args))

    def test_unit_and_shell_quoting_for_spaces_quotes_dollars_percent_and_backslashes(self):
        self.prepare()
        weird = self.base / 'a space " quote $HOME %n \\ unicode-å'
        state = self.state()
        state["env"]["HOME"] = str(weird)
        args = p.unit_command(weird, state)
        self.assertFalse(any(arg.startswith("--setenv=") for arg in args))
        stop = next(arg for arg in args if arg.startswith("--property=ExecStopPost="))
        self.assertIn("%%n", stop)
        self.assertIn('\\"', stop)
        self.assertIn("\\\\", stop)
        self.assertTrue(stop.startswith('--property=ExecStopPost=:"/usr/bin/python3"'))
        code = args[-1]
        self.assertNotIn("%", code)
        self.assertNotIn("$", code)
        argv = sys.argv[:]
        try:
            with patch("runpy.run_path") as run:
                exec(code, {})
                self.assertEqual(sys.argv, [str(weird / "recovery.py"), "_guardian", str(weird)])
                run.assert_called_once_with(str(weird / "recovery.py"), run_name="__main__")
        finally:
            sys.argv = argv

    def test_public_restore_uses_unique_unit_without_holding_state_lock(self):
        self.snapshot()
        def stop(args, timeout):
            self.assertEqual(args, [p.SYSTEMCTL, "--user", "stop", self.state()["unit"]])
            self.recover()  # would deadlock if public_restore held the lock
        with patch.object(p, "command", side_effect=stop), patch.object(p, "frozen_recover", side_effect=lambda session: self.recover()):
            self.assertEqual(p.public_restore(self.session)["phase"], p.FINAL)
        self.assertEqual(self.platform.starts, 1)

    def test_absent_unit_uses_independent_frozen_recovery(self):
        self.snapshot()
        with patch.object(p, "command", side_effect=subprocess.CalledProcessError(5, ["systemctl"])), \
                patch.object(p, "frozen_recover", side_effect=lambda session: self.recover()) as frozen:
            p.public_restore(self.session)
            frozen.assert_called_once_with(self.session)
        self.assertEqual(self.platform.starts, 1)

    def test_failed_systemd_launch_recovers_without_stopping_original(self):
        self.prepare()
        with patch.object(p, "environment", return_value=self.env), \
                patch.object(p, "command", side_effect=subprocess.CalledProcessError(1, ["systemd-run"])), \
                patch.object(p, "frozen_recover", side_effect=lambda session: self.recover()):
            with self.assertRaises(subprocess.CalledProcessError):
                p.start(self.session)
        self.assertEqual(self.state()["phase"], p.FINAL)
        self.assertEqual((self.platform.stops, self.platform.starts), (0, 0))

    def test_concurrent_start_and_restore_cancels_late_guardian(self):
        self.prepare()
        def unit_creation(args, timeout):
            self.recover()  # restore won the race before systemd created the unit
            with self.assertRaisesRegex(p.Unsafe, "cancelled"):
                p.guardian(self.session, self.platform)
        with patch.object(p, "environment", return_value=self.env), patch.object(p, "command", side_effect=unit_creation), \
                patch.object(p, "frozen_recover", side_effect=lambda session: self.recover()):
            with self.assertRaises(p.Unsafe):
                p.start(self.session)
        self.assertEqual(self.platform.stops, 0)

    def test_frozen_recovery_runs_without_checkout_for_prepare_only_state(self):
        self.prepare()
        self.repo.rename(self.base / "repo-no-longer-present")
        # This is not live restore: stop_requested=False, preview=None and no
        # snapshots means production recovery cannot call any platform operation.
        result = subprocess.run([p.PYTHON, str(self.session / "recovery.py"), "_recover", str(self.session)],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state()["phase"], p.FINAL)
        self.assertIn("recovery complete: restored", (self.session / "recovery.log").read_text())
        self.assertEqual(self.layout.read_bytes(), b"pre-stop config\x00\xfe")

    def test_timeouts_are_bounded(self):
        for timeout in (-1, 0, 601):
            with self.subTest(timeout=timeout), self.assertRaises(p.Unsafe):
                p.prepare(self.state_root, self.platform, self.env, timeout=timeout, repo=self.repo, installed=self.installed)


class OwnershipAndPlatformTest(unittest.TestCase):
    def test_proc_identity_has_exact_start_ticks_and_handles_comm_parentheses(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            proc = base / "123"
            proc.mkdir()
            fields = ["S"] + ["0"] * 18 + ["456789"] + ["0"] * 5
            (proc / "stat").write_text("123 (shell with ) parentheses) " + " ".join(fields))
            with patch.object(p, "PROC_ROOT", base):
                found = p.proc_identity(123)
                self.assertEqual(found, identity(123, 456789))
                self.assertIsNone(p.proc_identity(124))

    def test_pid_reuse_foreign_uid_and_already_dead_are_never_signalled(self):
        expected = identity()
        for actual in (None, identity(ticks=99999), identity(uid=os.getuid() + 1), dict(expected, dead=True)):
            with self.subTest(actual=actual), patch.object(p, "proc_identity", return_value=actual), \
                    patch.object(p.os, "pidfd_open") as open_pid, patch.object(p.signal, "pidfd_send_signal") as send:
                p.terminate_preview(expected)
                open_pid.assert_not_called()
                send.assert_not_called()
        foreign = identity(uid=os.getuid() + 1)
        with patch.object(p, "proc_identity", return_value=foreign), self.assertRaisesRegex(p.Unsafe, "foreign"):
            p.terminate_preview(foreign)

    def test_pidfd_rechecks_identity_and_signals_only_exact_pid(self):
        expected = identity()
        with patch.object(p, "proc_identity", side_effect=[expected, identity(ticks=1)]), \
                patch.object(p.os, "pidfd_open", return_value=77) as open_pid, \
                patch.object(p.os, "close") as close, patch.object(p.signal, "pidfd_send_signal") as send:
            p.terminate_preview(expected)
            open_pid.assert_called_once_with(expected["pid"])
            send.assert_not_called()
            close.assert_called_once_with(77)
        with patch.object(p, "proc_identity", side_effect=[expected, expected, None, None, None, None]), \
                patch.object(p.os, "pidfd_open", return_value=77), patch.object(p.os, "close"), \
                patch.object(p.signal, "pidfd_send_signal") as send:
            p.terminate_preview(expected)
            send.assert_called_once_with(77, signal.SIGTERM)

    def test_exit_between_check_and_signal_is_harmless(self):
        with patch.object(p, "proc_identity", return_value=identity()), patch.object(p.os, "pidfd_open", return_value=77), \
                patch.object(p.os, "close"), patch.object(p.signal, "pidfd_send_signal", side_effect=ProcessLookupError):
            p.terminate_preview(identity())

    def test_stubborn_preview_is_killed_via_pidfd_not_process_group(self):
        expected = identity()
        with patch.object(p, "proc_identity", side_effect=[expected, expected, expected, expected, None, None]), \
                patch.object(p.os, "pidfd_open", return_value=77), patch.object(p.os, "close"), \
                patch.object(p.time, "monotonic", side_effect=[1, 2, 3]), patch.object(p.signal, "pidfd_send_signal") as send:
            p.terminate_preview(expected, grace=0)
            self.assertEqual(send.call_args_list[0].args, (77, signal.SIGTERM))
            self.assertEqual(send.call_args_list[1].args, (77, signal.SIGKILL))
            self.assertEqual(send.call_count, 2)

    def test_managed_service_and_recursive_cgroup_recheck_before_stop(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            proc = base / "proc/123"
            proc.mkdir(parents=True)
            (proc / "exe").symlink_to(p.PLASMA)
            (proc / "cmdline").write_bytes(p.PLASMA.encode() + b"\0--no-respawn\0")
            cg = base / "cgroup/session/plasma"
            cg.mkdir(parents=True)
            (cg / "cgroup.procs").write_text("123\n")
            properties = {"ActiveState": "active", "SubState": "running", "MainPID": "123", "ControlGroup": "/session/plasma",
                          "ExecStart": "{ path=/usr/bin/plasmashell ; argv[]=/usr/bin/plasmashell --no-respawn ; ignore_errors=no ; }"}
            platform = p.Platform("/fake/qdbus6")
            with patch.object(p, "PROC_ROOT", base / "proc"), patch.object(p, "CGROUP_ROOT", base / "cgroup"), \
                    patch.object(p, "proc_identity", return_value=identity(123)), patch.object(platform, "service", return_value=properties), \
                    patch.object(p, "command") as command:
                self.assertEqual(platform.managed(), identity(123))
                child = cg / "child"
                child.mkdir()
                (child / "cgroup.procs").write_text("999\n")
                with self.assertRaisesRegex(p.Unsafe, "unrelated"):
                    platform.stop_original(identity(123))
                command.assert_not_called()
                (child / "cgroup.procs").write_text("")
                properties["MainPID"] = "124"
                with self.assertRaises((p.Unsafe, FileNotFoundError)):
                    platform.stop_original(identity(123))
                command.assert_not_called()

    def test_managed_stop_waits_for_process_and_inactive_unit(self):
        platform = p.Platform("/fake/qdbus6")
        with patch.object(platform, "managed", return_value=identity()), patch.object(p, "command") as command, \
                patch.object(p, "proc_identity", return_value=None), patch.object(platform, "service", return_value={"ActiveState": "inactive"}):
            platform.stop_original(identity())
            command.assert_called_once_with([p.SYSTEMCTL, "--user", "stop", p.SERVICE], timeout=50)
        with patch.object(platform, "managed", return_value=identity()), patch.object(p, "command"), \
                patch.object(p, "proc_identity", return_value=identity()), self.assertRaisesRegex(p.Unsafe, "still writing"):
            platform.stop_original(identity())

    def test_kwin_identity_not_a_name_only_logout_check(self):
        platform = p.Platform("/fake/qdbus6")
        state = {"kwin": identity()}
        with patch.object(platform, "owner", return_value=identity()):
            self.assertTrue(platform.session_alive(state))
        with patch.object(platform, "owner", return_value=identity(ticks=1)):
            self.assertFalse(platform.session_alive(state))
        with patch.object(platform, "owner", side_effect=subprocess.CalledProcessError(1, ["fake"])):
            self.assertFalse(platform.session_alive(state))


if __name__ == "__main__":
    unittest.main(verbosity=2)
