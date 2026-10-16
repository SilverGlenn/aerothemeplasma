/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtTest
import org.kde.plasma.workspace.dbus as DBus
import "../../plasma/plasmoids/io.gitgud.wackyideas.volume/contents/ui" as Aero

Item {
    QtObject {
        id: backend
        property bool muted: false
        property int index: 42
    }
    QtObject {
        id: mockRunner
        property int calls: 0
        property string lastCommand: ""
        signal newData(string sourceName, var data)
        function connectSource(command) { calls++; lastCommand = command; }
        function disconnectSource(command) {}
        function finish(muted, volume) {
            newData(lastCommand, {"exit code": 0, stdout: JSON.stringify({muted:muted, volume:volume, index:42})});
        }
    }
    Aero.AeroMuteController {
        id: state
        target: backend
        runner: mockRunner
    }
    Aero.AeroVolumeShortcutWatcher { id: shortcuts; enabled: false }
    SignalSpy { id: failureSpy; target: state; signalName: "failed" }
    SignalSpy { id: volumeSpy; target: shortcuts; signalName: "volumeAdjusted" }
    SignalSpy { id: muteSpy; target: shortcuts; signalName: "playbackMuteToggled" }

    TestCase {
        name: "AeroMuteBehavior"
        when: windowShown
        function init() {
            state.dispatchTimer.stop();
            state.jobs = [];
            state.activeCommand = "";
            state.revision = 0;
            state.activeRevision = -1;
            state.kind = "sink";
            state.gestureUnmuteRequested = false;
            backend.muted = false;
            state.muted = false;
            mockRunner.calls = 0;
            mockRunner.lastCommand = "";
            failureSpy.clear(); volumeSpy.clear(); muteSpy.clear();
        }
        function test_initial_refresh_corrects_stale_native_state() {
            state.enqueue("refresh");
            tryCompare(mockRunner, "calls", 1);
            mockRunner.finish(true, 32000);
            compare(backend.muted, false);
            compare(state.muted, true);
        }
        function test_toggles_both_directions_with_stale_backend() {
            state.toggle();
            compare(state.muted, true);
            compare(backend.muted, false);
            tryCompare(mockRunner, "calls", 1);
            mockRunner.finish(true, 32000);
            state.toggle();
            compare(state.muted, false);
            tryCompare(mockRunner, "calls", 2);
            mockRunner.finish(false, 32000);
            compare(state.muted, false);
        }
        function test_rapid_toggles_are_not_dropped_or_overwritten() {
            state.toggle(); state.toggle();
            compare(state.muted, false);
            tryCompare(mockRunner, "calls", 1);
            mockRunner.finish(true, 32000);
            compare(state.muted, false); // Ignore the earlier reply.
            tryCompare(mockRunner, "calls", 2);
            mockRunner.finish(false, 32000);
            compare(state.muted, false);
        }
        function test_positive_volume_unmutes_once_per_drag() {
            backend.muted = true;
            state.beginVolumeGesture();
            for (var i=0; i<10; ++i) state.ensureUnmuted(false);
            compare(state.muted, false);
            tryCompare(mockRunner, "calls", 1);
            verify(mockRunner.lastCommand.indexOf("unmute-positive") !== -1);
            mockRunner.finish(false, 32000);
            wait(80);
            compare(mockRunner.calls, 1);
            state.beginVolumeGesture(); state.ensureUnmuted(false);
            tryCompare(mockRunner, "calls", 2);
            mockRunner.finish(false, 32000);
        }
        function test_zero_volume_does_not_force_unmute() {
            backend.muted = true;
            state.ensureUnmuted(true);
            tryCompare(mockRunner, "calls", 1);
            mockRunner.finish(true, 0);
            compare(state.muted, true);
        }
        function test_late_backend_snapshot_does_not_override_pending_toggle() {
            state.toggle();
            backend.muted = true;
            backend.muted = false;
            compare(state.muted, true);
            tryCompare(mockRunner, "calls", 1);
            mockRunner.finish(true, 32000);
            compare(state.muted, true);
        }
        function test_fresh_backend_reports_still_update_state() {
            backend.muted = true;
            compare(state.muted, true);
            backend.muted = false;
            compare(state.muted, false);
            compare(mockRunner.calls, 0);
        }
        function test_failed_command_is_reported_and_reverts_pending_ui() {
            state.toggle();
            tryCompare(mockRunner, "calls", 1);
            mockRunner.newData(mockRunner.lastCommand, {"exit code":1, stderr:"Audio device disappeared"});
            compare(failureSpy.count, 1);
            compare(state.muted, false);
            compare(state.busy, false);
        }
        function test_command_path_is_shell_quoted() {
            compare(state.quote("/path/a'b/file.py"), "'/path/a'\\''b/file.py'");
        }
        function test_volume_shortcuts_include_both_directions_and_fine_steps() {
            var names = ["increase_volume", "decrease_volume", "increase_volume_small", "decrease_volume_small"];
            for (var i=0; i<names.length; ++i) shortcuts.dispatchShortcut("kmix", names[i]);
            compare(volumeSpy.count, 4);
        }
        function test_real_dbus_typed_string_arguments() {
            shortcuts.dispatchShortcut(new DBus.string("kmix"), new DBus.string("decrease_volume_small"));
            shortcuts.dbusglobalShortcutRepeated(new DBus.string("kmix"), new DBus.string("mute"), 1);
            compare(volumeSpy.count, 1);
            compare(muteSpy.count, 0);
        }
        function test_shortcuts_do_not_unmute_microphones_or_other_components() {
            shortcuts.dispatchShortcut("kmix", "mic_mute");
            shortcuts.dispatchShortcut("kmix", "increase_microphone_volume");
            shortcuts.dispatchShortcut("kmix", "decrease_microphone_volume");
            shortcuts.dispatchShortcut("other", "increase_volume");
            compare(volumeSpy.count, 0);
            compare(muteSpy.count, 0);
        }
        function test_playback_mute_and_repeated_volume_shortcuts() {
            shortcuts.dbusglobalShortcutPressed("kmix", "mute", 1);
            shortcuts.dbusglobalShortcutRepeated("kmix", "mute", 2);
            shortcuts.dbusglobalShortcutRepeated("kmix", "increase_volume", 3);
            compare(muteSpy.count, 1);
            compare(volumeSpy.count, 1);
        }
    }
}
