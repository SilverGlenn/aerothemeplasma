import QtQuick
import QtTest
TestCase {
 name: "TaskDelegateSource"
 when: windowShown
 visible: true
 width:800; height:600
 InputFixture { id: input; x:100; y:100 }
 GeometryFixture { id: geometry; y:300 }
 SignalSpy { id: windowsSpy; target: input.taskThumbnail; signalName: "windowsChanged" }
 function test_reusingPreviewKeepsBindings() {
  input.updateToolTipBindings()
  windowsSpy.clear()
  for (var i=0; i<10; ++i) input.updateToolTipBindings()
  compare(windowsSpy.count,0)
 }
 function init() {
  input.reset()
  geometry.rows=[]; geometry.iconsOnly=false; geometry.vertical=false; geometry.width=320; geometry.height=40
  wait(300)
 }
 function row(launcher,startup,appId) { return {IsLauncher:launcher,IsStartup:startup,AppId:appId||"window"}; }
 function test_click_once() {
  mouseClick(input,30,20,Qt.LeftButton)
  compare(input.calls.length,1)
  compare(input.calls[0][0],"activate")
 }
 function test_active_minimizes_once() {
  input.model.IsActive=true; input.model=input.model
  mouseClick(input,30,20,Qt.LeftButton)
  compare(input.calls.length,1)
  compare(input.calls[0][0],"minimize")
 }
 function test_shift_then_programmatic() {
  mouseClick(input,30,20,Qt.LeftButton,Qt.ShiftModifier)
  compare(input.calls.length,1); compare(input.calls[0][0],"new")
  input.tap.leftClick()
  compare(input.calls.length,2); compare(input.calls[1][0],"activate")
 }
 function test_drag_no_activation() {
  mousePress(input,30,20,Qt.LeftButton)
  mouseMove(input,50,20,10)
  mouseRelease(input,50,20,Qt.LeftButton)
  compare(input.calls.length,0)
  wait(350)
  mouseClick(input,30,20,Qt.LeftButton)
  compare(input.calls.length,1)
 }
 function test_outside_release_no_activation() {
  mousePress(input,30,20,Qt.LeftButton)
  mouseMove(input,70,20,10)
  mouseRelease(input,70,20,Qt.LeftButton)
  compare(input.calls.length,0)
  wait(350)
 }
 function test_keyboard_modifiers() {
  input.forceActiveFocus()
  keyClick(Qt.Key_Return,Qt.ShiftModifier)
  compare(input.calls.length,1); compare(input.calls[0][0],"new")
  keyClick(Qt.Key_Space)
  compare(input.calls.length,2); compare(input.calls[1][0],"activate")
 }
 function test_group_first_and_second_click() {
  input.model.IsGroupParent=true; input.model=input.model
  mouseClick(input,30,20,Qt.LeftButton)
  tryCompare(input,"previewVisible",true)
  compare(input.groupChooserPinned,true)
  compare(input.tasksRoot.toolTipOpen,true)
  mouseClick(input,30,20,Qt.LeftButton)
  tryCompare(input,"previewVisible",false)
  compare(input.groupChooserPinned,false)
  compare(input.calls.length,0)
 }
 function test_hover_group_first_click_pins() {
  input.model.IsGroupParent=true; input.model=input.model
  input.updateToolTipBindings()
  input.showToolTip()
  tryCompare(input,"previewVisible",true)
  compare(input.groupChooserPinned,false)
  mouseClick(input,30,20,Qt.LeftButton)
  compare(input.previewVisible,true); compare(input.groupChooserPinned,true)
  input.hideImmediately()
  tryCompare(input,"previewVisible",false)
 }
 function test_forced_group_list_and_escape() {
  input.model.IsGroupParent=true; input.model=input.model
  input.mockPlasmoid.configuration.showPreviews=false; input.mockPlasmoid=input.mockPlasmoid
  mouseClick(input,30,20,Qt.LeftButton)
  tryCompare(input,"previewVisible",true)
  compare(input.taskThumbnail.forceList,true)
  compare(input.tasksRoot.toolTipOpen,true)
  compare(input.tasksRoot.pinnedToolTipOpen,false)
  input.taskThumbnail.isPeeking=true
  input.forceActiveFocus(); keyClick(Qt.Key_Escape)
  tryCompare(input,"previewVisible",false)
  compare(input.forceGroupList,false); compare(input.groupChooserPinned,false)
  compare(input.taskThumbnail.isPeeking,false)
 }
 function test_old_owner_cannot_clear_new_flags() {
  input.updateToolTipBindings()
  input.toolTipVisibleChanged(true)
  input.taskThumbnail.parentTask=geometry
  input.tasksRoot.toolTipOpen=true
  input.toolTipVisibleChanged(false)
  compare(input.tasksRoot.toolTipOpen,true)
  compare(input.groupChooserPinned,false)
 }
 function test_two_labels_no_phantom_launcher() {
  geometry.rows=[row(false,false),row(false,false)]
  tryCompare(geometry.list,"count",2)
  tryCompare(geometry.list.itemAtIndex(0),"width",159)
  compare(geometry.list.itemAtIndex(1).width,159)
  geometry.list.forceLayout()
  compare(geometry.list.itemAtIndex(1).x,161)
  geometry.list.forceLayout()
  compare(geometry.list.contentWidth,320)
 }
 function test_pinned_and_running_pitch() {
  geometry.iconsOnly=true
  geometry.rows=[row(true,false,"pinned"),row(false,false)]
  tryCompare(geometry.list,"count",2)
  tryCompare(geometry.list.itemAtIndex(0),"width",60)
  compare(geometry.list.itemAtIndex(1).width,60)
  compare(geometry.list.itemAtIndex(1).x,62)
  geometry.height=30
  tryCompare(geometry.list.itemAtIndex(0),"width",44)
  compare(geometry.list.itemAtIndex(1).width,44)
  geometry.list.forceLayout()
  compare(geometry.list.itemAtIndex(1).x,46)
  compare(geometry.list.itemAtIndex(1).height,30)
 }
 function test_startup_restores_role_binding() {
  geometry.rows=[row(false,true),row(false,false),row(false,false)]
  tryCompare(geometry.list,"count",3)
  const startup=geometry.list.itemAtIndex(0)
  compare(startup.visible,false); compare(startup.width,0)
  tryCompare(geometry.list.itemAtIndex(1),"width",158)
  geometry.rows=[row(false,false),row(false,false),row(false,false)]
  tryCompare(startup,"visible",true)
  tryCompare(startup,"width",105)
  compare(geometry.list.widthCounts.labeled,3)
  verify(isFinite(geometry.list.contentWidth))
 }
 function test_launcher_label_allocation() {
  geometry.rows=[row(true,false,"pinned"),row(false,false),row(false,false)]
  tryCompare(geometry.list,"count",3)
  tryCompare(geometry.list.itemAtIndex(1),"width",128)
  geometry.list.forceLayout()
  compare(geometry.list.contentWidth,320)
 }
 function test_narrowWidthMatrix() {
  for (const width of [140,240,320,800]) {
   geometry.width=width; geometry.rows=[row(true,false,"pinned"),row(false,false),row(false,false)]
   tryCompare(geometry.list,"count",3); wait(50)
   var first=geometry.list.itemAtIndex(0), second=geometry.list.itemAtIndex(1)
   compare(first.width,60); verify(second.width>=40); verify(second.width<=160)
   geometry.list.forceLayout(); compare(second.x,62)
   verify(isFinite(geometry.list.contentWidth))
  }
 }

}
