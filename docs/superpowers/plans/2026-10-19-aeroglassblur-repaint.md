# AeroGlassBlur Repaint Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove motion trails behind Aero glass while retaining AeroGlassBlur and its Windows 7 appearance.

**Architecture:** Port AeroGlassBlur's background-damage registration to KWin 6.6's `BackgroundEffectItem`, following the matching KDE Blur implementation. Keep the external dependency change as a reproducible, idempotently applied patch in this repository. Do not change Aero rendering/shaders or substitute another effect.

**Tech Stack:** C++/Qt 6/KWin 6.6+, shell, Python regression runner, CMake/Ninja.

**Spec:** User request in this session: investigate and patch; AeroGlassBlur is non-negotiable because this project recreates Windows 7 for personal use. Reproduction: move ChatGPT (XWayland) behind the taskbar or an always-on-top Aero frame; transient trails appear only through Aero glass, not KDE Blur.

## Global Constraints

- Preserve AeroGlassBlur's shaders, reflections, colours, glass styling, and existing forced-blur regions.
- Preserve all pre-existing uncommitted changes in this checkout and the external dependency.
- Do not restart KWin/terminate the Wayland session or applications automatically.
- Back up the installed binary before deployment; never overwrite a mapped shared library in place.
- No permanent KDE Blur workaround. X11 companion implementation is outside this patch's scope.
- Require a live user reproduction before claiming that the visual issue is fixed.

## Investigation Evidence

- Running KWin: 6.6.6, Qt 6.10.2, Wayland, AMD/Mesa.
- Effect source: `~/.local/src/aerothemeplasma/repos/aeroshell-kwin-components/effects_cpp/wayland/kde-effects-aeroglassblur/src/{blur.cpp,blur.h}`.
- Aero retains the older `prePaintWindow()` damage expansion via `WindowPrePaintData::devicePaint`.
- Matching KWin 6.6 `WorkspaceScene` collects actual damage later from scene items, not that legacy field.
- KDE Blur registers a `BackgroundEffectItem` per blurred window, including the blur bounds and kernel expansion size. Aero does not register one.
- Existing source geometry-change callbacks and reconfiguration already call `updateBlurRegion()`.

## Review Focus

- Both taskbar glass and decoration-only glass must register background damage dependencies.
- Resizing/reconfiguring blur must update bounds and expansion size without duplicate scene items.
- Excluded/unblurred windows and window deletion must release their scene items safely.
- Patch application must be repeatable and reject incompatible or partially patched source rather than silently continue.
- A cached plugin factory may retain the old library across D-Bus toggles; do not mistake re-creating the old effect for testing the new binary.

---

### Task 1: Regression coverage and reproducible dependency patch

**Files:**
- Create: `tests/aeroglassblur/` regression harness and runner.
- Create: `patches/aeroshell-kwin-components/0001-register-background-damage.patch`.
- Create: `scripts/apply-aeroglassblur-patch.sh`.
- Modify: `install.sh` to apply the dependency patch after fetching, before any installation.
- External source changes: `effects_cpp/wayland/kde-effects-aeroglassblur/src/{blur.cpp,blur.h}`.

**Interfaces:**
- Patch helper consumes an explicit companion repository path; returns zero for successful or already-applied patch, nonzero for incompatible source.
- Regression harness compiles the real `updateBlurRegion()` method and effect data declarations against small KWin boundary doubles and real Qt geometry. It checks the scene-registration contract, not GPU output.

- [x] Write a behavioral regression that fails against the original source because a blurred window has no registered background-effect item. Cover decoration/content regions, reuse after geometry/config updates, and removal when blur is disabled.
- [x] Run it against the unpatched source and record the expected assertion failure.
- [x] Add one owned `BackgroundEffectItem` to `BlurEffectData`; create/reuse it from `updateBlurRegion()`, set its bounds from `blurRegion(w).boundingRect()`, and set its repaint expansion from `m_expandSize`. Use the installed KWin 6.6 API.
- [x] Remove obsolete manual damage accumulation while retaining the existing Firefox translucency handling and effect-chain forwarding.
- [x] Generate a patch containing only these dependency changes; implement apply/check/reverse-check handling and wire it into the installer before builds.
- [x] Run behavioral and patch-application regressions: fresh application, repeated application, incompatible input, preservation of unrelated files. Run `bash -n` on changed shell scripts.

### Task 2: Build, deployment preparation, and live verification

**Files:**
- Create: `docs/kwin/aeroglassblur-repaint.md` with diagnosis, patch/build/test steps, limits, and rollback instructions.
- Update this plan with actual results.

**Interfaces:**
- Build target: `aeroglassblur` in the existing companion build, or a separate build if preserving build state requires it.
- Install artifact: `aeroglassblur.so` at the existing KWin plugin location; deployment requires authorized elevation or a verified user-plugin route.

- [x] Build the patched effect against the installed KWin headers; report compile errors rather than installing an unbuilt patch.
- [x] Run relevant regression suites and record any existing failures by name. Review the final diff for unintended rendering/style changes.
- [x] Determine whether the current KWin process can genuinely load the rebuilt binary. If a logout is necessary, explain and let the user perform it; never restart the Wayland compositor automatically.
- [x] Preserve the old installed binary outside the plugin discovery directory, install atomically with authorized privileges, and confirm the intended file checksum/path.
- [x] Ask the user to repeat the original glass-trail reproduction after loading the patch. The user confirmed the live fix worked. Broader manual menu/resize/accent checks were not individually reported; shader, colour and reflection code was unchanged.
