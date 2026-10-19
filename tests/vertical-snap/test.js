// SPDX-License-Identifier: GPL-2.0-or-later
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,
    '../../plasma/kwin-scripts/aeroverticalsnap/contents/code/main.js'), 'utf8');

function setup(geometry = null, flags = {}) {
    const calls = [];
    const shortcuts = {};
    const window = Object.assign({
        tile: geometry ? {relativeGeometry: geometry} : null,
        maximizable: true, minimizable: true, maximizeMode: 0,
        setMaximize: (v, h) => calls.push(['maximize', v, h])
    }, flags);
    const workspace = {
        activeWindow: window,
        slotWindowQuickTileTop: () => calls.push('top'),
        slotWindowQuickTileBottom: () => calls.push('bottom')
    };
    vm.runInNewContext(source, {workspace, registerShortcut: (id, label, key, fn) => {
        assert.equal(key, '');
        shortcuts[id.endsWith('Up') ? 'up' : 'down'] = fn;
    }});
    return {window, workspace, calls, ...shortcuts};
}

// Existing half and quarter tiles, including ones created with the mouse.
for (const [x, width] of [[0, 1], [0, 0.5], [0.5, 0.5]]) {
    const top = setup({x, y: 0, width, height: 0.5});
    top.up();
    assert.deepEqual(top.calls, [['maximize', true, true]]);
    const bottom = setup({x, y: 0.5, width, height: 0.5});
    bottom.down();
    assert.equal(bottom.window.minimized, true);
    assert.deepEqual(bottom.calls, []);
}

// A floating window at the edge is not a tile. Full-height side tiles must
// still pass through to native quarter tiling in both directions.
for (const geometry of [null, {x: 0, y: 0, width: 0.5, height: 1},
    {x: 0.5, y: 0, width: 0.5, height: 1}]) {
    const test = setup(geometry);
    test.up();
    test.down();
    assert.deepEqual(test.calls, ['top', 'bottom']);
}

// The next press reads the requested tile, even when frame geometry lags.
for (const up of [true, false]) {
    const test = setup();
    const press = up ? test.up : test.down;
    press();
    test.window.tile = {relativeGeometry: {x: 0, y: up ? 0 : 0.5, width: 1, height: 0.5}};
    test.window.frameGeometry = {x: 100, y: 100, width: 600, height: 400};
    press();
    if (up) assert.deepEqual(test.calls, ['top', ['maximize', true, true]]);
    else assert.equal(test.window.minimized, true);
}

// Opposite directions continue through KWin's existing transition behavior.
{
    const test = setup({x: 0, y: 0, width: 1, height: 0.5});
    test.down();
    assert.deepEqual(test.calls, ['bottom']);
}
{
    const test = setup({x: 0, y: 0.5, width: 1, height: 0.5});
    test.up();
    assert.deepEqual(test.calls, ['top']);
}

// Maximized Up is idempotent; Down restores before beginning bottom tiling.
{
    const test = setup(null, {maximizeMode: 3});
    test.up();
    test.down();
    assert.deepEqual(test.calls, [['maximize', true, true], ['maximize', false, false]]);
    test.window.maximizeMode = 0;
    test.down();
    assert.equal(test.calls.at(-1), 'bottom');
}

// Restore partial maximization too, and prioritize restore over a retained tile.
for (const maximizeMode of [1, 2, 3]) {
    const test = setup({x: 0, y: 0.5, width: 1, height: 0.5}, {maximizeMode});
    test.down();
    assert.deepEqual(test.calls, [['maximize', false, false]]);
    assert.equal(test.window.minimized, undefined);
}

// Window capabilities and special surfaces are respected.
for (const flags of [{dock: true}, {desktopWindow: true}, {fullScreen: true},
    {minimized: true}, {move: true}, {resize: true}]) {
    const test = setup(null, flags);
    test.up();
    test.down();
    assert.deepEqual(test.calls, []);
}
{
    const test = setup();
    test.workspace.activeWindow = null;
    test.up();
    test.down();
    assert.deepEqual(test.calls, []);
}
for (const up of [true, false]) {
    const test = setup({x: 0, y: up ? 0 : 0.5, width: 1, height: 0.5},
        {maximizable: false, minimizable: false});
    (up ? test.up : test.down)();
    assert.deepEqual(test.calls, []);
    assert.equal(test.window.minimized, undefined);
}
console.log('Vertical snap regression checks passed.');
