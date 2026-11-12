# Interactive Gravitational Lunar Orb & Audio Pulse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the central wallpaper Moon Phase Orb into an interactive Nothing OS centerpiece featuring expanding gravitational wave ripples, bass-reactive audio pulse via Cava, cursor gravity well physics, hover telemetry badge, and signature Nothing red cusp accent with zero extra VRAM impact.

**Architecture:** Render gravitational wave ripples and the red accent dot directly inside the existing `Dm { step: 8 }` dot-matrix shader in `Orb.qml`. Manage cursor spring dynamics and hover telemetry in `Home.qml` and `Back.qml`. Modulate wave expansion and brightness with `Media.playing` and `Cava.bars[0..1]`.

**Tech Stack:** Quickshell, QML (Qt 6.x), SVG/SceneGraph, Cava, MPRIS, Linux Hyprland.

**Spec:** [`docs/superpowers/specs/2026-11-12-lunar-orb-enhancement-design.md`](file:///home/creserver/Desktop/glyph-rice-custom/docs/superpowers/specs/2026-11-12-lunar-orb-enhancement-design.md)

---

## Global Constraints
- Zero additional offscreen Framebuffer Objects (FBOs) in GPU VRAM (no new `MultiEffect` or `layer.enabled` sub-trees).
- Quickshell RSS memory footprint must remain under 335 MB.
- GPU VRAM consumption must remain $\approx 125$ MiB on NVIDIA RTX 5060.
- All modifications must be backed up bit-for-bit to `~/Desktop/glyph-rice-custom/` with git commits.
- Python scripts (if used) must activate `/home/creserver/extras/local_venv/bin/activate.fish`.

## Review Focus
1. **Window Occlusion:** When windows are open on a workspace (`root.home === false`), ripple animations, Cava, and hover handlers must be idle to preserve CPU.
2. **Audio Quiescence:** When no media is playing (`Media.playing === false`), Cava must not run unnecessarily; ripples must use smooth meditative base timing.
3. **Cursor Spring Stability:** Rapid mouse movement across the orb must not cause overshoot jitter or unbounded coordinates.
4. **Astronomical Integrity:** Moon phase illumination geometry must remain exact according to the 29.53-day synodic calculation.
5. **No Broken Symlinks / Missing Files:** Live files in `~/.local/share/glyph` and desktop backup in `~/Desktop/glyph-rice-custom` must remain identical.

---

### Task 1: Gravitational Ripples, Cava Audio Reactivity & Red Accent in `Orb.qml`

**Files:**
- Modify: `~/.local/share/glyph/config/quickshell/glyph/components/Orb.qml`

**Interfaces:**
- Consumes: `phase: real`, `breathe: bool`, `nowMs: real`, `Cava.bars: var`, `Media.playing: bool`
- Produces: `Orb` with expanding concentric gravitational rings, bass pulsation, surface glint, and Nothing red accent dot

- [ ] **Step 1: Inspect and enhance `Orb.qml` with gravitational ripple rings and red cusp dot**
  - Add 3 concentric ripple circles in `moonSvg()` with radii expanding from $R$ ($195\text{px}$) to $285\text{px}$ based on `phase` and optional `bassAmp`.
  - Add opacity gradient falloff ($0.35 \to 0.00$) so ripples fade as they disperse.
  - Add Nothing signature red accent dot (`#ff2e2e`) at the northern lunar crescent cusp with gentle breathing luminance.
  - Add 3 subtle micro-glint dots along the illuminated crescent edge.

- [ ] **Step 2: Connect audio bass pulse from `Cava` in `Orb.qml`**
  - Read bass amplitude from `Cava.bars[0]` and `Cava.bars[1]` when `Media.playing` is true.
  - Scale ripple expansion and halo brightness with bass amplitude.

- [ ] **Step 3: Syntax and lint check on `Orb.qml`**
  - Run syntax verification with `qmlimportscanner` or rice test.

- [ ] **Step 4: Commit checkpoint**
  - Commit changes to `~/.local/share/glyph` and `~/Desktop/glyph-rice-custom`.

---

### Task 2: Interactive Cursor Gravity & Spring Physics in `Back.qml`

**Files:**
- Modify: `~/.local/share/glyph/config/quickshell/glyph/home/Back.qml`

**Interfaces:**
- Consumes: `orbTiltX: real`, `orbTiltY: real` (from `Home.qml` or internal handler)
- Produces: Smooth spring-damped translation of the central orb

- [ ] **Step 1: Add spring translation to `Orb` in `Back.qml`**
  - Add `property real tiltX: 0; property real tiltY: 0` to `Back.qml`.
  - Add `transform: Translate { x: orb.tiltX; y: orb.tiltY }` on `Orb`.
  - Apply `Behavior on tiltX { SpringAnimation { spring: 2.8; damping: 0.28 } }` and `Behavior on tiltY { SpringAnimation { spring: 2.8; damping: 0.28 } }`.

- [ ] **Step 2: Verify zero FBO overhead**
  - Translation transforms occur directly on the SceneGraph quad without triggering layer reallocations.

- [ ] **Step 3: Commit checkpoint**
  - Commit changes to `~/.local/share/glyph` and `~/Desktop/glyph-rice-custom`.

---

### Task 3: Desktop Hover Area & Telemetry Reveal in `Home.qml`

**Files:**
- Modify: `~/.local/share/glyph/config/quickshell/glyph/home/Home.qml`

**Interfaces:**
- Consumes: Cursor coordinates, `clock.date`, `nakshatraDataObj`
- Produces: `orbHovered: bool`, cursor attraction vectors ($dx, dy$), and animated telemetry badge

- [ ] **Step 1: Add central orb interaction zone in `Home.qml`**
  - Create a 460×460px interaction zone centered at $x=960, y=540$.
  - On mouse hover, compute normalized offset from center and update `orb.tiltX` and `orb.tiltY`.
  - Expose `orbHovered: bool` property.

- [ ] **Step 2: Add Nothing OS Hover Telemetry Badge**
  - Positioned at $x=760, y=780$ (centered under the lunar orb).
  - Shows current phase name (e.g. `WAXING CRESCENT`), percentage illuminated (`14.8% ILLUMINATED`), and current Nakshatra.
  - Smooth fade-in on hover (`opacity: orbHovered ? 1.0 : 0.0`).

- [ ] **Step 3: Enable Cava when media is playing**
  - Update `Cava.active` binding in `Home.qml` to include `Media.playing`.

- [ ] **Step 4: Commit checkpoint**
  - Commit changes to `~/.local/share/glyph` and `~/Desktop/glyph-rice-custom`.

---

### Task 4: Verification, Benchmarking & Documentation Sync

**Files:**
- Modify: `~/Desktop/glyph-rice-custom/SETUP.md`
- Modify: `<artifacts>/tasks.md`

- [ ] **Step 1: Restart Rice shell and verify logs**
  - Run `/home/creserver/.local/bin/rice restart` and ensure clean configuration load with zero warnings/errors.

- [ ] **Step 2: Capture visual verification screenshots**
  - Switch to empty workspace 6, capture screenshots of the orb ripples, red accent dot, and hover telemetry.

- [ ] **Step 3: Measure RAM and VRAM footprint**
  - Verify quickshell RSS $\le 335$ MB and GPU VRAM $\approx 125$ MiB via `ps` and `nvidia-smi`.

- [ ] **Step 4: Sync all files to Desktop backup and commit**
  - Synchronize `Orb.qml`, `Back.qml`, `Home.qml`, `SETUP.md` to `~/Desktop/glyph-rice-custom/` and create git commit.
