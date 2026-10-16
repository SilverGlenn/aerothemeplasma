/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtTest
import org.kde.plasma.private.volume
import "../../plasma/plasmoids/io.gitgud.wackyideas.volume/contents/ui" as Aero

Item {
    width: 160
    height: 240

    QtObject { id: config; property bool raiseMaximumVolume: false }
    property real backendVolume: 0
    property real lastRequestedVolume: -1

    Aero.VolumeSlider {
        id: slider
        x: 40
        y: 20
        width: 30
        height: 170
        type: "sink-output"
        from: 0
        to: PulseAudio.NormalVolume
        stepSize: PulseAudio.NormalVolume / 100
        reportedVolume: backendVolume
        onMoved: lastRequestedVolume = value
    }

    SignalSpy { id: movedSpy; target: slider; signalName: "moved" }

    TestCase {
        name: "AeroVolumeSliderSync"
        when: windowShown

        function init() {
            slider.to = PulseAudio.NormalVolume;
            slider.enabled = true;
            backendVolume = 0;
            backendVolume = PulseAudio.NormalVolume * 0.4;
            lastRequestedVolume = -1;
            movedSpy.clear();
        }

        function dragTo(fraction) {
            var startX = slider.handle.x + slider.handle.width / 2;
            var startY = slider.handle.y + slider.handle.height / 2;
            var endX = slider.width / 2;
            var endY = slider.topPadding + slider.handle.height / 2
                + (1 - fraction) * (slider.availableHeight - slider.handle.height);
            mousePress(slider, startX, startY);
            mouseMove(slider, endX, endY, 30);
            verify(slider.pressed);
            return {x:endX, y:endY};
        }

        function releaseAt(position) {
            mouseRelease(slider, position.x, position.y);
            verify(!slider.pressed);
        }

        function test_initial_value_and_external_updates() {
            compare(slider.value, backendVolume);
            backendVolume = PulseAudio.NormalVolume * 0.72;
            compare(slider.value, backendVolume);
            compare(movedSpy.count, 0); // Readbacks must not write to the backend.
        }

        function test_stale_bluetooth_snapshot_does_not_reset_on_release() {
            var end = dragTo(0.65);
            var requested = slider.value;
            var handleY = slider.handle.y;
            verify(Math.abs(requested - backendVolume) > slider.stepSize);
            releaseAt(end);
            fuzzyCompare(slider.value, requested, slider.stepSize);
            fuzzyCompare(slider.handle.y, handleY, 1);
            wait(100);
            fuzzyCompare(slider.value, requested, slider.stepSize);
            verify(movedSpy.count > 0);
            compare(lastRequestedVolume, slider.value);
        }

        function test_delayed_speaker_ack_does_not_rewind_handle() {
            var end = dragTo(0.3);
            var requested = slider.value;
            releaseAt(end);
            fuzzyCompare(slider.value, requested, slider.stepSize);
            wait(50);
            fuzzyCompare(slider.value, requested, slider.stepSize);
            backendVolume = Math.round(requested);
            compare(slider.value, backendVolume);
        }

        function test_backend_updates_during_drag_do_not_fight_user() {
            var end = dragTo(0.65);
            var requested = slider.value;
            backendVolume = PulseAudio.NormalVolume * 0.5;
            compare(slider.value, requested);
            releaseAt(end);
            fuzzyCompare(slider.value, requested, slider.stepSize);
            // A fresh final report still reconciles hardware rounding.
            backendVolume = Math.round(requested) - 10;
            compare(slider.value, backendVolume);
        }

        function test_repeated_drags_with_missing_backend_notifications() {
            var end = dragTo(0.65);
            releaseAt(end);
            end = dragTo(0.25);
            var requested = slider.value;
            releaseAt(end);
            fuzzyCompare(slider.value, requested, slider.stepSize);
            backendVolume = PulseAudio.NormalVolume * 0.5;
            compare(slider.value, backendVolume);
        }

        function test_keyboard_adjustment_and_later_external_update() {
            slider.forceActiveFocus();
            var before = slider.value;
            keyClick(Qt.Key_Down);
            verify(slider.value < before);
            compare(lastRequestedVolume, slider.value);
            backendVolume = PulseAudio.NormalVolume * 0.8;
            compare(slider.value, backendVolume);
        }

        function test_wheel_adjustment_and_later_external_update() {
            var before = slider.value;
            mouseWheel(slider, slider.width / 2, slider.height / 2, 0, -120);
            verify(slider.value < before);
            compare(lastRequestedVolume, slider.value);
            backendVolume = PulseAudio.NormalVolume * 0.8;
            compare(slider.value, backendVolume);
        }

        function test_backend_rounding_and_rejection_reports() {
            var end = dragTo(0.65);
            releaseAt(end);
            backendVolume = PulseAudio.NormalVolume * 0.63;
            compare(slider.value, backendVolume);
            compare(lastRequestedVolume > 0, true);
        }

        function test_range_changes_remain_clamped() {
            slider.to = PulseAudio.NormalVolume * 1.5;
            backendVolume = PulseAudio.NormalVolume * 1.2;
            compare(slider.value, backendVolume);
            slider.to = PulseAudio.NormalVolume;
            compare(slider.value, PulseAudio.NormalVolume);
        }

        function test_disabled_slider_is_not_writable() {
            slider.enabled = false;
            mouseClick(slider, slider.width / 2, slider.height / 2);
            compare(movedSpy.count, 0);
            compare(lastRequestedVolume, -1);
        }
    }
}
