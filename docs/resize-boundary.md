# Taskbar resize boundary

The `taskbarresizeguard` KWin script stops a dragged window border at space
reserved by a panel. It uses the output's maximize area rather than a fixed
taskbar height, and handles bottom, top, left, and right panels.

Install and enable it immediately for the current user:

```sh
bash scripts/install-resize-boundary.sh
```

Disable it and restore KWin's normal resizing behavior:

```sh
bash scripts/install-resize-boundary.sh --disable
```

Remove the user-local copy entirely (for example when the theme install already
provides the script system-wide; the installer warns if both exist):

```sh
bash scripts/install-resize-boundary.sh --uninstall
```

`qdbus6`, `qdbus-qt6` or `qdbus` is used, whichever is installed.

The installer changes only the user-local KWin script and its
`[Plugins] taskbarresizeguardEnabled` setting in `kwinrc`. It requires no logout
or compositor restart. The theme's CMake installation also includes the script
and enables it in the theme's default configuration.

Only interactive resizing is constrained. The opposite border stays fixed,
ordinary window moves remain available, and Escape retains KWin's resize
cancellation. Borders without reserved panel space can cross screen edges.
Auto-hidden panels are governed by the space KWin actually reserves for them.
If a fixed border leaves less room than the application's minimum size, the
previous accepted geometry on that axis is retained. A window already behind
the taskbar is not repositioned when resizing an unrelated border.

The handler uses each requested resize step, since a Wayland window's displayed
geometry can lag behind the requested size. KWin 6.6.6 schedules the Wayland
configure after these synchronous handlers, allowing the guard to replace an
oversized request before the client receives it. The script uses the public
[KWin scripting API](https://develop.kde.org/docs/plasma/kwin/api/).

Run the regression checks:

```sh
node tests/resize-boundary/test.js
bash -n scripts/install-resize-boundary.sh
```

The checks exercise existing and newly created windows, repeated border drags,
all four panel positions, fixed opposite edges, fractional coordinates,
negative output origins, asynchronous frame geometry, cancellation, minimum
size conflicts, and exclusions for non-resize operations.

Live validation on KWin 6.6.6 also used temporary native Wayland and XWayland
windows. A bottom-right resize dragged beyond the screen produced an actual
and requested bottom of 1040, matching the taskbar's top of 1040. The fixed top
remained at 100, and releasing the resize retained the boundary in both cases.
