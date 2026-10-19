# Window snap preview

The outline in `plasma/outline` animates the projected window area when a window
is dragged to a screen edge. It retains the Aero reflection, rounded border, and
shadow. Qt 6.8 or newer is required for the textured `ShapePath` fill.

Install it for the current user:

```sh
python3 scripts/install-snap-preview.py
```

Log out and back in afterward. KWin creates and caches the outline QML component
on first use; reconfiguring KWin does not replace an existing instance. The
installer saves the previous user override and can restore it with:

```sh
python3 scripts/install-snap-preview.py --disable
```

The theme's CMake installation includes the outline, and its default `kwinrc`
selects `aerothemeplasma/outline/outline.qml`.

## Rendering

The older Aero outline rendered a reflection and an animated opacity mask at
the size of the entire virtual desktop. It also resized two SVG frames and
animated four integer properties independently. This could produce expensive
offscreen passes, repeated rasterization, and visible stepping.

The optimized outline samples the original reflection image directly into a
rounded `Shape` using Qt Quick's curve renderer. It uses no opacity mask,
`ShaderEffectSource`, or item layers. The reflection stays anchored to the
virtual desktop, including monitors with negative origins. Its image texture
stays at its original resolution.

The border and shadow use `BorderImage` with fixed bitmap slices extracted
losslessly from the original Aero `res/outline-frame.svgz`, retained beside them
as the asset source. Resizing updates vertices while reusing those textures.
A single rectangle property animation preserves fractional coordinates and
retargets from the displayed frame. The backing window is sized once per target
change to contain the starting and final rectangles plus the shadow, and stays
fixed throughout the transition. Keyboard previews without a visual parent
appear immediately; animation duration follows Kirigami's system setting.

Run the animation and pixel checks on an isolated virtual display:

```sh
xvfb-run -a env QT_QPA_PLATFORM=xcb QSG_RHI_BACKEND=opengl \
    /usr/lib/qt6/bin/qmltestrunner -input tests/outline -o -,txt
```
