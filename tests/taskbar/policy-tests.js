const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ui = process.argv[2];
const ctx = {Qt:{ShiftModifier:1},TaskManager:{AbstractTasksModel:Object.fromEntries(['IsLauncher','IsStartup','IsGroupParent','IsMinimized','IsActive','StackingOrder'].map(x=>[x,x]))},PlasmaCore:{Types:{}}};
vm.createContext(ctx);
for (const file of ['Win7TaskPolicy.js','tools.js']) vm.runInContext(fs.readFileSync(ui+'/code/'+file,'utf8').replace(/^\.(pragma|import).*$/mg,''),ctx,{filename:file});
let checks=0;
function eq(a,b) { assert.deepEqual(JSON.parse(JSON.stringify(a)),b); ++checks; }
const width=ctx.labeledTaskWidth;
eq(width(320,0,2,2,60,2,40,160),159);
eq(width(320,1,2,3,60,2,40,160),128);
eq(width(320,0,2,3,60,2,40,160),158); // hidden startup's real gap slots
for (const args of [[0,0,0,0],[320,3,0,3],[0,1,2,3],[-10,2,1,3],[Infinity,0,2,2]]) { const w=width(...args,60,2,40,160); assert(Number.isFinite(w)); assert(w>=40 && w<=160); ++checks; }
eq(width(2000,0,2,2,60,2,40,160),160);
eq(width(320,1,2,3,44,2,30,160),136);
function fixture(rows,active) {
 const calls=[];
 const tm={count:rows.length,activeTask:active,makeModelIndex:(i,j)=>j===undefined?String(i):`${i}:${j}`,rowCount:i=>(rows[Number(i)].children||[]).length,data:(i,role)=>{const [r,c]=String(i).split(':').map(Number);return (c===undefined?rows[r]:(rows[r].children||[])[c])[role];},requestActivate:i=>calls.push(['activate',i]),requestToggleMinimized:i=>calls.push(['minimize',i]),requestNewInstance:i=>calls.push(['new',i])};
 return {calls,tasksModel:tm,activateWindowView:ids=>calls.push(['view',ids]),taskList:{children:[{}]}};
}
function activate(model,config={},modifiers=0,available=false,rows=[model]) {
 const f=fixture(rows,'0');
 const task={index:0,modelIndex:()=> '0',showGroupChooser:force=>f.calls.push(['chooser',force]),hideImmediately:()=>f.calls.push(['hide'])};
 ctx.activateTask('0',model,modifiers,task,{configuration:{showPreviews:true,groupedTaskVisualization:1,minimizeActiveTaskOnClick:true,...config}},f,available);
 return f.calls;
}
eq(activate({IsActive:false}),[['activate','0']]);
eq(activate({IsActive:true}),[['minimize','0']]);
eq(activate({IsMinimized:true}),[['minimize','0'],['activate','0']]);
eq(activate({IsActive:true},{minimizeActiveTaskOnClick:false}),[['activate','0']]);
eq(activate({IsGroupParent:true},{},1),[['new','0']]);
eq(activate({IsGroupParent:true}),[['chooser',false]]);
eq(activate({IsGroupParent:true},{showPreviews:false}),[['chooser',true]]);
eq(activate({IsGroupParent:true},{groupedTaskVisualization:2}),[['chooser',true]]);
eq(activate({IsGroupParent:true},{groupedTaskVisualization:3}),[['chooser',true]]);
eq(activate({IsGroupParent:true,WinIdList:['1','2']},{groupedTaskVisualization:2},0,true),[['hide'],['view',['1','2']]]);
eq(activate({IsGroupParent:true,children:[]},{groupedTaskVisualization:0}),[]);
eq(activate({IsGroupParent:true,children:[{StackingOrder:-1},{StackingOrder:-2}]},{groupedTaskVisualization:0}),[['activate','0:0']]);
eq(activate({IsGroupParent:true,children:[{IsActive:true},{IsActive:false}]},{groupedTaskVisualization:0}),[['activate','0:1']]);
let f=fixture([{IsLauncher:true},{IsStartup:true},{IsMinimized:true},{},{IsGroupParent:true,children:[{IsMinimized:false},{IsMinimized:true}]}],'3');
ctx.activateNextPrevTask(null,true,true,f);eq(f.calls,[['activate','4:0']]);
f.calls.length=0;ctx.activateNextPrevTask(null,false,true,f);eq(f.calls,[['activate','4:0']]);
f.calls.length=0;ctx.activateNextPrevTask({index:4},true,false,f);eq(f.calls,[['activate','4:0']]);
f.calls.length=0;f.tasksModel.activeTask='4:0';ctx.activateNextPrevTask({index:4},false,false,f);eq(f.calls,[['activate','4:1']]);
f=fixture([{IsLauncher:true},{IsStartup:true}],null);ctx.activateNextPrevTask(null,true,false,f);eq(f.calls,[]);
assert(!fs.readFileSync(ui+'/Task.qml','utf8').includes('task.toolTipVisible')); ++checks;
assert(!fs.readFileSync(ui+'/code/tools.js','utf8').includes('taskList.children')); ++checks;
assert(fs.readFileSync(ui+'/Task.qml','utf8').includes('active: model.IsWindow && task.smartLauncherItem && task.smartLauncherItem.progressVisible')); ++checks;
console.log(`${checks} production helper/source assertions passed`);
// Production main.qml functions with explicit host collaborators (no shell required).
const main = fs.readFileSync(ui+'/main.qml','utf8');
function sourceFunction(source,name) {
 const start=source.indexOf('function '+name+'(');
 assert(start>=0);
 let brace=source.indexOf('{',start), depth=1, end=brace+1;
 while(depth && end<source.length) { if(source[end]==='{') ++depth; if(source[end]==='}') --depth; ++end; }
 return source.slice(start,end);
}
const calls=[];
ctx.tasksModel={count:4};
ctx.taskList={itemAtIndex:i=>[null,{model:{IsLauncher:true}},{index:2,model:{IsStartup:true}},{index:3,model:{}}][i]};
ctx.backend={globalRect:task=>[task.index,0,60,40]};
ctx.tasks={tasksModel:{makeModelIndex:i=>i,requestPublishDelegateGeometry:(i,r)=>calls.push([i,r])}};
ctx.TaskTools={taskManagerInstanceCount:1};
vm.runInContext(sourceFunction(main,'publishIconGeometries'),ctx);
ctx.publishIconGeometries();eq(calls,[[3,[3,0,60,40]]]);
ctx.TaskTools.taskManagerInstanceCount=2;ctx.publishIconGeometries();eq(calls.length,1);
ctx.count=3;ctx.itemAtIndex=i=>[null,{mouseArea:'real-area'},{}][i];ctx.Plasmoid={sendMouseEvent:area=>calls.push(area)};
vm.runInContext(sourceFunction(main,'forceMouseEvent'),ctx);ctx.forceMouseEvent();eq(calls[1],'real-area');
// Execute the actual layout template against the scripting API seam.
const layout=fs.readFileSync(ui+'/../../../../layout-templates/io.gitgud.wackyideas.taskbar/contents/layout.js','utf8');
for (const screenWidth of [800,1024,1200,3840]) {
 let panel;
 const layoutContext={Panel:function(){panel=this;this.screen=0;this.formFactor='horizontal';this.addWidget=()=>{};},panelIds:[],languageId:'en',screenGeometry:()=>({width:screenWidth,height:600})};
 vm.runInNewContext(layout,layoutContext);
 eq([panel.height,panel.floating,panel.location,panel.alignment,panel.minimumLength,panel.maximumLength],[40,false,'bottom','left',screenWidth,screenWidth]);
}
console.log(`${checks} total production policy/source assertions passed`);
