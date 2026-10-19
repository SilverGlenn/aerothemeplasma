const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ui = process.argv[2];
const main = fs.readFileSync(ui + '/main.qml', 'utf8');
const start = main.indexOf('function activateTaskAtIndex(');
assert(start >= 0);
let end = main.indexOf('{', start) + 1, depth = 1;
while (depth && end < main.length) {
    if (main[end] === '{') ++depth;
    if (main[end] === '}') --depth;
    ++end;
}

const calls = [];
const rows = [
    {IsGroupParent: true, IsWindow: true, children: [
        {IsActive: false, StackingOrder: 1},
        {IsActive: false, StackingOrder: 2},
    ]},
    {IsWindow: true},
    {IsLauncher: true},
];
const tasksModel = {
    makeModelIndex: (i, j) => j === undefined ? String(i) : `${i}:${j}`,
    rowCount: i => rows[Number(i)].children.length,
    data: (i, role) => {
        const [parent, child] = i.split(':').map(Number);
        return rows[parent].children[child][role];
    },
    requestActivate: i => calls.push(['activate', i]),
    requestToggleMinimized: i => calls.push(['minimize', i]),
    requestNewInstance: i => calls.push(['new', i]),
};
const delegates = rows.map((model, index) => ({
    index, model, showPreviews: !!model.IsWindow,
    modelIndex: () => String(index),
    hideImmediately: () => calls.push(['hide', index]),
}));
const context = {
    Qt: {NoModifier: 0, ShiftModifier: 1},
    TaskManager: {AbstractTasksModel: {IsActive: 'IsActive', StackingOrder: 'StackingOrder'}},
    tasks: {tasksModel, pinnedToolTipOpen: false},
    taskList: {itemAtIndex: i => delegates[i]},
    Plasmoid: {configuration: {groupedTaskVisualization: 1, minimizeActiveTaskOnClick: true}},
    shortcutPreview: {cycleGroup: () => false, showForTask: task => calls.push(['shortcut-preview', task.index])},
};
vm.createContext(context);
vm.runInContext(fs.readFileSync(ui + '/code/tools.js', 'utf8').replace(/^\.(pragma|import).*$/mg, ''), context);
context.TaskTools = {activateTask: context.activateTask};
vm.runInContext(main.slice(start, end), context);
let checks = 0;
function expect(expected) {
    assert.deepEqual(calls.splice(0), expected);
    ++checks;
}
// Always cycle, then delegate preview lifetime to the modifier controller.
for (const preference of [0, 1, 2, 3]) {
    context.Plasmoid.configuration.groupedTaskVisualization = preference;
    context.activateTaskAtIndex(0);
    expect([['activate', '0:1'], ['shortcut-preview', 0]]);
}
rows[0].children[1].IsActive = true;
context.activateTaskAtIndex(0);
expect([['activate', '0:0'], ['shortcut-preview', 0]]);
rows[0].children[1].IsActive = false;
rows[0].children[0].IsActive = true;
context.activateTaskAtIndex(0);
expect([['activate', '0:1'], ['shortcut-preview', 0]]);

context.activateTaskAtIndex(1);
expect([['activate', '1'], ['shortcut-preview', 1]]);
delegates[0].showPreviews = false;
context.activateTaskAtIndex(0);
expect([['hide', 0], ['activate', '0:1'], ['shortcut-preview', 0]]);
context.activateTaskAtIndex(2);
expect([['hide', 2], ['activate', '2'], ['shortcut-preview', 2]]);
for (const invalid of ['0', null, -1, 99]) context.activateTaskAtIndex(invalid);
expect([]);
// A controller-managed group must bypass immediate activation/restoration.
context.shortcutPreview.cycleGroup = task => task.model.IsGroupParent;
delegates[0].showPreviews = true;
context.activateTaskAtIndex(0);
expect([]);
rows[1].IsMinimized = true;
context.activateTaskAtIndex(1);
expect([['minimize','1'],['activate','1'],['shortcut-preview',1]]);
console.log(`${checks} numbered-shortcut production assertions passed`);
