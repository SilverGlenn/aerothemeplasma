import QtQuick
import QtTest
import org.kde.taskmanager as TaskManager
import "../ui" as UI

TestCase {
    id: test
    name: "MinimizedGroupShortcutSelection"
    when: windowShown
    visible: true
    property bool held: false
    property var calls: []
    property var rows: []
    UI.ShortcutPreviewController { id: controller; taskModel: model; metaPressed: test.held }
    QtObject {
        id: model
        function makeModelIndex(i,j) { return j === undefined ? "parent" : String(j); }
        function rowCount(i) { return test.rows.length; }
        function data(i,role) {
            var row=test.rows[i === "parent" ? 0 : Number(i)];
            if (!row) return undefined;
            switch (role) {
            case TaskManager.AbstractTasksModel.WinIdList: return [row.id];
            case TaskManager.AbstractTasksModel.IsMinimized: return row.minimized;
            case TaskManager.AbstractTasksModel.IsActive: return row.active;
            case TaskManager.AbstractTasksModel.StackingOrder: return row.stacking;
            }
        }
        function requestActivate(i) { test.calls.push(i); }
    }
    QtObject { id: preview; property QtObject parentTask: null; property string shortcutWindowId: "" }
    QtObject {
        id: task
        property var model: ({IsGroupParent:true, IsWindow:true})
        property int index: 0
        property QtObject taskThumbnail: preview
        property bool showPreviews: true
        property bool toolTipShown: false
        function modelIndex() { return "parent"; }
        function updateToolTipBindings() { preview.parentTask = task; }
        function showToolTip() { toolTipShown = true; }
        function hideImmediately() { toolTipShown = false; }
    }
    function init() {
        controller.dismiss();
        held=true; calls=[];
        rows=[{id:"first",minimized:true,active:false,stacking:2},
              {id:"second",minimized:true,active:false,stacking:1},
              {id:"third",minimized:true,active:false,stacking:0}];
        task.model={IsGroupParent:true,IsWindow:true};
        task.showPreviews=true; task.toolTipShown=false;
        preview.parentTask=null;
    }
    function cleanup() { controller.dismiss(); held=false; wait(20); }
    function test_groupRemainsMinimizedUntilRelease() {
        verify(controller.cycleGroup(task));
        compare(controller.selectedWindowId,"first");
        tryCompare(task,"toolTipShown",true);
        compare(preview.shortcutWindowId,"first");
        compare(calls.length,0);
        verify(controller.cycleGroup(task));
        compare(controller.selectedWindowId,"second");
        compare(preview.shortcutWindowId,"second");
        compare(calls.length,0);
        held=false;
        compare(calls.length,1); compare(calls[0],"1");
        compare(task.toolTipShown,false); compare(preview.shortcutWindowId,"");
    }
    function test_cyclesAndWrapsWithoutActiveWindowChanging() {
        for (var expected of ["first","second","third","first"]) {
            verify(controller.cycleGroup(task));
            compare(controller.selectedWindowId,expected);
            compare(calls.length,0);
        }
        held=false;
        compare(calls.length,1); compare(calls[0],"0");
    }
    function test_singleWindowBypassesDeferredSelection() {
        task.model={IsGroupParent:false,IsWindow:true};
        rows=rows.slice(0,1);
        compare(controller.cycleGroup(task),false);
        task.model={IsGroupParent:true,IsWindow:true};
        compare(controller.cycleGroup(task),false);
        held=false; compare(calls.length,0);
    }
    function test_unminimizedWindowsCycleImmediately() {
        rows=rows.map(function(row){row.minimized=false; return row;});
        verify(controller.cycleGroup(task));
        compare(calls.length,1); compare(calls[0],"0");
        verify(controller.cycleGroup(task));
        compare(calls.length,2); compare(calls[1],"1");
        held=false; compare(calls.length,2);
    }
    function test_mixedGroupOnlyDefersMinimizedTarget() {
        rows[1].minimized=false;
        verify(controller.cycleGroup(task)); compare(calls.length,0);
        verify(controller.cycleGroup(task)); compare(calls.length,1); compare(calls[0],"1");
        held=false; compare(calls.length,1);
    }
    function test_releaseResolvesWindowAfterRowsShift() {
        controller.cycleGroup(task); controller.cycleGroup(task);
        rows=rows.slice(1);
        held=false;
        compare(calls.length,1); compare(calls[0],"0");
    }
    function test_closedSelectionDoesNotActivateAnotherWindow() {
        controller.cycleGroup(task); controller.cycleGroup(task);
        rows=[rows[0],rows[2]];
        held=false; compare(calls.length,0);
    }
    function test_groupBecomingSingleWindowStillCommitsSelectedId() {
        controller.cycleGroup(task); controller.cycleGroup(task);
        rows=[rows[1]]; task.model={IsGroupParent:false,IsWindow:true};
        held=false;
        compare(calls.length,1); compare(calls[0],"parent");
    }
    function test_nextShortcutAfterGroupBecomesSingleActivatesNormally() {
        controller.cycleGroup(task);
        rows=[rows[0]]; task.model={IsGroupParent:false,IsWindow:true};
        compare(controller.cycleGroup(task),false);
        model.requestActivate("parent"); controller.showForTask(task);
        held=false;
        compare(calls.length,1); compare(controller.deferredWindowId,"");
    }
    function test_cancelDiscardsPendingActivation() {
        controller.cycleGroup(task);
        controller.dismiss(); held=false;
        compare(calls.length,0);
    }
    function test_quickReleaseCommitsWithoutLatePopup() {
        controller.cycleGroup(task); held=false;
        compare(calls.length,1);
        wait(30); compare(task.toolTipShown,false);
    }
    function test_groupSelectionWorksWhenPreviewsDisabled() {
        task.showPreviews=false;
        controller.cycleGroup(task); controller.cycleGroup(task);
        compare(calls.length,0); held=false;
        compare(calls.length,1); compare(calls[0],"1");
    }
}
