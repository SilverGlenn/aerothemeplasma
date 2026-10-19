// SPDX-License-Identifier: GPL-2.0-or-later
// Run the shipped script against KWin signal/property doubles.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,
    '../../plasma/kwin-scripts/taskbarresizeguard/contents/code/main.js'), 'utf8');

function signal() {
    const callbacks = [];
    return {connect: callback => callbacks.push(callback),
        emit: (...args) => callbacks.forEach(callback => callback(...args))};
}
function setup(area = {x: 0, y: 0, width: 1920, height: 1040},
    screen = {x: 0, y: 0, width: 1920, height: 1080}, added = false) {
    let frame = {x: 100, y: 100, width: 800, height: 600};
    const writes = [];
    const window = {
        resize: true, minSize: {width: 100, height: 80},
        clientGeometry: {x: 108, y: 130, width: 784, height: 562},
        interactiveMoveResizeStarted: signal(),
        interactiveMoveResizeStepped: signal(),
        interactiveMoveResizeFinished: signal(),
        get frameGeometry() { return frame; },
        set frameGeometry(value) { frame = {...value}; writes.push(frame); }
    };
    const workspace = {
        windowAdded: signal(), windowList: () => added ? [] : [window],
        clientArea: option => option === 0 ? area : screen
    };
    vm.runInNewContext(source, {workspace, KWin: {MaximizeArea: 0, ScreenArea: 1}});
    if (added) workspace.windowAdded.emit(window);
    return {window, writes, start: () => window.interactiveMoveResizeStarted.emit(),
        step: rect => window.interactiveMoveResizeStepped.emit(rect),
        finish: () => window.interactiveMoveResizeFinished.emit()};
}

// Bottom and corner dragging stops at the taskbar, retaining the opposite edge.
for (const added of [false, true]) {
    const test = setup(undefined, undefined, added);
    test.start();
    test.step({x: 100, y: 100, width: 1000, height: 1000});
    assert.deepEqual(test.writes.at(-1), {x: 100, y: 100, width: 1000, height: 940});
    // Several out-of-bounds steps, then dragging back into the desktop.
    test.step({x: 100, y: 100, width: 1000, height: 1200});
    assert.equal(test.writes.at(-1).height, 940);
    const count = test.writes.length;
    test.step({x: 100, y: 100, width: 1000, height: 800});
    assert.equal(test.writes.length, count);
}

// Wayland step geometry can differ from the still-displayed frame geometry.
{
    const test = setup();
    test.start();
    test.step({x: 100, y: 100, width: 800, height: 1100});
    assert.equal(test.writes.at(-1).height, 940);
}

for (const [area, geometry, expected] of [
    [{x: 0, y: 40, width: 1920, height: 1040},
        {x: 100, y: -20, width: 800, height: 720},
        {x: 100, y: 40, width: 800, height: 660}],
    [{x: 40, y: 0, width: 1880, height: 1080},
        {x: -20, y: 100, width: 920, height: 600},
        {x: 40, y: 100, width: 860, height: 600}],
    [{x: 0, y: 0, width: 1880, height: 1080},
        {x: 100, y: 100, width: 1900, height: 600},
        {x: 100, y: 100, width: 1780, height: 600}]
]) {
    const test = setup(area);
    test.start();
    test.step(geometry);
    assert.deepEqual(test.writes.at(-1), expected);
}

// Negative output origins and fractional panel geometry use logical coordinates.
{
    const test = setup({x: -1920, y: -1080, width: 1920, height: 1039.5},
        {x: -1920, y: -1080, width: 1920, height: 1080});
    test.window.frameGeometry = {x: -1800, y: -900, width: 800, height: 600};
    test.start();
    test.step({x: -1800, y: -900, width: 900, height: 1000});
    assert.equal(test.writes.at(-1).y + test.writes.at(-1).height, -40.5);
}

// Unreserved edges (including adjacent screens and auto-hidden panels) stay free.
for (const area of [undefined, {x: 0, y: 0, width: 1920, height: 1080}]) {
    const test = setup(area);
    test.start();
    test.step({x: 100, y: 100, width: 2400, height: 600});
    assert.equal(test.writes.length, 0);
}

// Moving, fullscreen, panels, desktops, and ordinary geometry changes are ignored.
for (const flags of [{resize: false}, {fullScreen: true}, {dock: true}, {desktopWindow: true}]) {
    const test = setup();
    Object.assign(test.window, flags);
    test.start();
    test.step({x: 100, y: 100, width: 800, height: 1200});
    assert.equal(test.writes.length, 0);
}
{
    const test = setup();
    test.step({x: 100, y: 100, width: 800, height: 1200});
    test.start();
    test.finish(); // Includes Escape: don't override KWin's restored geometry.
    test.step({x: 100, y: 100, width: 800, height: 1200});
    assert.equal(test.writes.length, 0);
}

// A window already overlapping the taskbar doesn't jump during horizontal resize.
{
    const test = setup();
    test.window.frameGeometry = {x: 100, y: 100, width: 800, height: 1000};
    test.start();
    const count = test.writes.length;
    test.step({x: 100, y: 100, width: 1000, height: 1000});
    assert.equal(test.writes.length, count);
}

// A conflicting application minimum size doesn't move the fixed border.
{
    const test = setup();
    test.window.minSize.height = 1000;
    test.start();
    test.step({x: 100, y: 100, width: 1000, height: 1200});
    assert.deepEqual(test.writes.at(-1), {x: 100, y: 100, width: 1000, height: 600});
}
console.log('Resize boundary regression checks passed.');
