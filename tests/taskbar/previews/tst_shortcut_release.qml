import QtQuick
import QtTest
import "../ui" as UI

TestCase {
    id: test
    name: "ShortcutPreviewRelease"
    when: windowShown
    visible: true
    property bool held: false
    UI.ShortcutPreviewController { id: controller; metaPressed: test.held }
    QtObject { id: sharedPreview; property QtObject parentTask: null; property string shortcutWindowId: "" }
    Component {
        id: taskComponent
        QtObject {
            property QtObject taskThumbnail: sharedPreview
            property bool showPreviews: true
            property bool toolTipShown: false
            property int shown: 0
            property int hidden: 0
            function updateToolTipBindings() { taskThumbnail.parentTask = this; }
            function showToolTip() { toolTipShown = true; ++shown; }
            function hideImmediately() { toolTipShown = false; ++hidden; }
        }
    }
    property var first: null
    property var second: null
    function setMeta(pressed) {
        // Inject modifier notifications; offscreen has no global keyboard backend.
        held = pressed;
        compare(controller.metaPressed, pressed);
    }
    function init() {
        controller.dismiss();
        sharedPreview.parentTask = null;
        first = taskComponent.createObject(test);
        second = taskComponent.createObject(test);
        setMeta(true);
    }
    function cleanup() {
        setMeta(false);
        first.destroy(); second.destroy();
        first = null; second = null;
        wait(20);
    }
    function test_releaseClosesPreviewWithoutTakingFocus() {
        controller.showForTask(first);
        tryCompare(first, "shown", 1);
        setMeta(false);
        compare(first.hidden, 1);
        compare(first.toolTipShown, false);
        compare(controller.previewTask, null);
    }
    function test_repeatedShortcutReusesOpenPreview() {
        controller.showForTask(first);
        tryCompare(first, "shown", 1);
        for (var i=0;i<8;++i) { controller.showForTask(first); wait(1); }
        compare(first.shown, 1); compare(first.hidden, 0);
        setMeta(false);
        compare(first.hidden, 1);
    }
    function test_releaseCancelsDeferredShow() {
        controller.showForTask(first);
        setMeta(false);
        wait(30);
        compare(first.shown, 0);
        compare(controller.previewTask, null);
    }
    function test_releaseThenRepressDoesNotReviveOldRequest() {
        controller.showForTask(first);
        setMeta(false); setMeta(true);
        wait(30);
        compare(first.shown, 0);
        controller.showForTask(second);
        tryCompare(second, "shown", 1);
    }
    function test_switchAppWhileHeld() {
        controller.showForTask(first);
        tryCompare(first, "shown", 1);
        controller.showForTask(second);
        compare(first.hidden, 1);
        tryCompare(second, "shown", 1);
        setMeta(false);
        compare(second.hidden, 1);
    }
    function test_onlyLatestQueuedRequestShows() {
        controller.showForTask(first);
        controller.showForTask(second);
        tryCompare(second, "shown", 1);
        compare(first.shown, 0);
    }
    function test_releasePreservesDifferentHoverPreview() {
        controller.showForTask(first);
        tryCompare(first, "shown", 1);
        second.updateToolTipBindings(); second.showToolTip();
        setMeta(false);
        compare(second.hidden, 0); compare(second.toolTipShown, true);
    }
    function test_withoutMetaDoesNotShowPreview() {
        setMeta(false);
        controller.showForTask(first);
        wait(30);
        compare(first.shown, 0); compare(controller.previewTask, null);
    }
    function test_disabledPreviewsStayHidden() {
        first.showPreviews = false;
        controller.showForTask(first);
        wait(30);
        compare(first.shown, 0);
    }
    function test_launcherBecomingWindowCanShowPreview() {
        first.showPreviews = false;
        controller.showForTask(first);
        first.showPreviews = true;
        tryCompare(first, "shown", 1);
    }
}
