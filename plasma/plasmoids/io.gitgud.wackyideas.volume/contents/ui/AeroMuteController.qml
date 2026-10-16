/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQml
import org.kde.plasma.plasma5support as Plasma5Support

QtObject {
    id: controller

    property QtObject target: null
    property string kind: "sink"
    property bool muted: target ? target.muted : false
    readonly property bool reportedMuted: target ? target.muted : false
    readonly property bool busy: activeCommand.length > 0
    property var runner: executable

    signal failed(string message)

    property var jobs: []
    property int revision: 0
    property string activeCommand: ""
    property int activeRevision: -1
    property bool gestureUnmuteRequested: false

    Component.onCompleted: enqueue("refresh")

    onReportedMutedChanged: {
        if (!busy && jobs.length === 0) {
            muted = reportedMuted;
        }
        if (reportedMuted) {
            gestureUnmuteRequested = false;
        }
    }

    function quote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    function enqueue(action) {
        if (!target || target.index < 0) {
            return;
        }
        revision++;
        // A mutating action already performs its own authoritative read.
        if (action !== "refresh" && jobs.length && jobs[jobs.length - 1].action === "refresh") {
            jobs.pop();
        }
        var job = {action: action, revision: revision};
        // Preserve every toggle, but collapse redundant queued read/unmute work.
        if (action !== "toggle" && jobs.length && jobs[jobs.length - 1].action === action) {
            jobs[jobs.length - 1] = job;
        } else {
            jobs.push(job);
        }
        if (!busy) {
            dispatchTimer.restart();
        }
    }

    function toggle() {
        muted = !muted;
        gestureUnmuteRequested = false;
        enqueue("toggle");
    }

    function beginVolumeGesture() {
        gestureUnmuteRequested = false;
    }

    function ensureUnmuted(force) {
        if (!force && gestureUnmuteRequested) {
            return;
        }
        gestureUnmuteRequested = true;
        muted = false;
        enqueue("unmute-positive");
    }

    function followGlobalMute() {
        gestureUnmuteRequested = false;
        enqueue("global-mute");
    }

    function reportFailure(message) {
        if (activeRevision === revision) {
            muted = reportedMuted;
            gestureUnmuteRequested = false;
        }
        failed(message);
    }

    function dispatch() {
        if (busy || !jobs.length || !target) {
            return;
        }
        var job = jobs.shift();
        var helper = decodeURIComponent(String(Qt.resolvedUrl("../code/aero_mute_control.py"))).replace(/^file:\/\//, "");
        activeRevision = job.revision;
        activeCommand = "python3 " + quote(helper) + " " + quote(kind)
            + " " + Math.floor(target.index) + " " + quote(job.action);
        runner.connectSource(activeCommand);
    }

    property Timer dispatchTimer: Timer {
        interval: 60
        onTriggered: controller.dispatch()
    }

    property Plasma5Support.DataSource executable: Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: []
    }

    property Connections receiver: Connections {
        target: controller.runner
        function onNewData(sourceName, data) {
            if (sourceName !== controller.activeCommand) {
                return;
            }
            controller.runner.disconnectSource(sourceName);
            if (data["exit code"] === 0) {
                try {
                    var result = JSON.parse(data.stdout);
                    if (controller.activeRevision === controller.revision) {
                        controller.muted = result.muted;
                        if (result.muted) {
                            controller.gestureUnmuteRequested = false;
                        }
                    }
                } catch (error) {
                    controller.reportFailure(String(error));
                }
            } else {
                controller.reportFailure(String(data.stderr || "Audio mute command failed."));
            }
            controller.activeCommand = "";
            if (controller.jobs.length) {
                controller.dispatchTimer.restart();
            }
        }
    }
}
