# Windows 7 taskbar reference — independent private fork

## Method and authority

Base: `e4cca91b12dd9419485c19bece76534972324f6a`; branch `windows7-fidelity`.
Reuse the methodology of `linux-explorer-win7/README.md`,
`docs/windows7-reference.md` and `docs/uxguide-checklist.md`: observed Windows 7
behavior first, Windows 7-era UX Guide guardrails second, honest Linux adaptation
third. This is not a modern redesign and not an upstream contribution. Upstream's
LICENSE, authorship and README remain; its CONTRIBUTING prohibition on AI-assisted
contributions applies. No new Microsoft resources are acquired or bundled.

Primary local authority is
`/home/siru/VMs/windows7/reference-taskbar/PARENT-OBSERVATIONS.md` and its named
captures. This supersedes the preliminary research report's mistaken labeled
Notepad interpretation and 50–55 px pitch estimate. Captures remain outside the
repository. The earlier Explorer reference is at `~/VMs/windows7/reference/`.

## Observed, not inferred

Windows 7 Ultimate SP1, 800×600, normal text size, Standard VGA / **Basic graphics**,
with parent-controlled temporary snapshot; original guest disk unchanged.

| Evidence | Observation / confidence |
| --- | --- |
| 01 default / parent remeasurement | Bar begins around y=560/561: roughly 39–40 px high; large icons about 32 px, vertically centered. Raster estimates, not universal metrics. |
| 03 two Notepads | Icons-only grouped task. Pinned centers around x=89,150,211/212; Notepad x=272/273: approximately 61–62 px pitch, ±1 px. No justification for shrinking nominal 60+2. |
| 05 group hover Basic | Two-row textual chooser, approximately 189×84 px. This is a Basic fallback reference, not Aero thumbnail geometry. |
| 05/06 and 18/19/20 | First explicit click opens/pins or preserves a hover-visible chooser; second explicit click closes it and it stays dismissed after pointer departure. |
| 16/17 | Active single-window primary click minimizes; subsequent click restores. Use these confirmed captures, not provisional 11/12 names. |
| 13 settled Jump List | Recent destinations, launch, Pin, Close with a section rule; approximately 230×170 px. 07 was premature. This pass preserves real KDE context operations, not a fake destination list. |
| 09/10 | Choosing a row followed by closing a Notepad reduces the group; identical captions/geometry do not prove which indexed instance was selected. |

02's missing tooltip is **not** a delay or absence test. Modifier mappings,
double-click behavior and exact timing were not verified in the guest.
There is **no valid Aero Glass/live-thumbnail/shadow/Peek visual reference**.

## Documented expectations (not new measurements)

Microsoft labels these pages as the guide created for Windows 7, not updated for
newer Windows:

- [Windows 7 Taskbar](https://learn.microsoft.com/en-us/windows/win32/uxguide/winenv-taskbar): program grouping, per-window thumbnail toolbars, useful progress and restrained overlays; Jump Lists differ from immediate thumbnail commands.
- [Mouse](https://learn.microsoft.com/en-us/windows/win32/uxguide/inter-mouse): predictable targeting, hover redundancy and double-click conventions. Generic modifier advice is not proof of special taskbar mappings.
- [Keyboard](https://learn.microsoft.com/en-us/windows/win32/uxguide/inter-keyboard): keyboard access and visible focus; hover must not be required.
- [Tooltips and Infotips](https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-tooltips-and-infotips): concise supplemental labels, placement/delay and redundancy.
- [Menus](https://learn.microsoft.com/en-us/windows/win32/uxguide/cmd-menus): contextual actions and alternative command access.
- [UX checklist](https://learn.microsoft.com/en-us/windows/win32/uxguide/top-violations): low-resolution/DPI checks, target usability, keyboard and feedback.

## Approved implementation proposals / Linux adaptations

Preserve upstream 60 px + 2 px pitch, 40/30 px heights, 44 px small buttons,
160 px labeled cap. Correct width allocation and real model-based optional wheel
cycling, not independent metric redesign. Layout template becomes full-edge,
non-floating, 40 logical px; it is not applied to an existing user's panel.

Compact previews use one stable icon/title/close header in either label mode,
20×20 close hit target around the existing 14×14 glyph, non-overlapping inset/gutter,
and work-area-bounded scrolling lists. These are supervisor-approved proposals,
**not Aero measurements**. Retained nominal 164×94 preview and 800 ms initial
Peek / 250 ms drag timing are upstream values, not measured guest facts.

Peek and capture use the current owner's signal-backed popup lifetime. Real KWin
highlighting, X11 thumbnails, Wayland/PipeWire capture and MPRIS calls remain;
none was proven against a live compositor/player here. MPRIS app/PID matching is
not proof of Windows per-window media semantics. Useful progress/status are
retained. Numeric notification badges and the extra audio mute control are
explicit KDE extensions, off by default. Unsupported Windows services are not
represented by dead controls.

See [the checklist](taskbar-uxguide-checklist.md) and
[reproduction/staging limitations](taskbar-fidelity.md) before any parity claim.
