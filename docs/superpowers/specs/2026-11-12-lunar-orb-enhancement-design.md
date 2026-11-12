# Design Specification: Interactive Gravitational Lunar Orb & Audio Pulse

**Date:** 2026-11-12  
**Status:** Pending Approval  
**Target:** `Orb.qml`, `Back.qml`, `Home.qml`  

---

## 1. Intent & Purpose
Transform the wallpaper's central **Moon Phase Orb** from a mostly-static, faint sphere into an alive, captivating celestial centerpiece for the desktop. By blending **gravitational ripple physics & audio-reactive tides (Approach 1)** with **interactive cursor gravity & telemetry hover physics (Approach 3)**, the orb becomes an expressive Nothing OS hallmark while preserving strict zero-extra-VRAM and low-CPU efficiency.

---

## 2. Goals, Non-Goals & Anti-Goals

### Goals
- **Cosmic Gravitational Ripples:** Faint concentric dot rings expand continuously outward from the lunar rim, fading as they disperse into the background matrix.
- **Audio-Reactive Pulse (Cava + MPRIS):** When music is playing (`Media.playing`), the ripples and corona expand and brighten synchronously to the bass frequencies (`Cava.bars[0..1]`). When silent, it smoothly settles back into a calm celestial breathing rhythm.
- **Cursor Gravity Well (Interactive Tilt/Spring):** As the mouse moves across the central zone, the orb subtly shifts toward the pointer ($\pm 10$px) with smooth spring damping physics.
- **Hover Telemetry Reveal:** Hovering over the orb smoothly fades in a sleek Nothing OS dot-matrix telemetry badge below the orb (e.g., `WAXING CRESCENT · 14.8% ILLUMINATED · MULA`).
- **Signature Nothing Red Accent:** A delicate, glowing red dot (`Theme.red`) resting at the lunar cusp, anchoring the monochrome sphere to Nothing OS branding.
- **Surface Glint:** Sporadic micro-twinkle across the lit crescent dots.

### Non-Goals
- Replacing the astronomical Swiss Ephemeris phase calculation (the true synodic phase remains 100% physically accurate).
- Heavy 3D mesh rendering or WebGL/OpenGL raymarching (all visuals remain 2D SVG/SceneGraph filtered through the SPIR-V dot shader).

### Anti-Goals (What would make this a failure)
- Creating extra offscreen Framebuffer Objects (FBOs) in VRAM or causing GPU memory leaks.
- Running high-frequency CPU polling timers when windows are open or when music is silent.
- Visual clutter or aggressive disco-style flashing that detracts from the minimal, meditative Nothing aesthetic.

---

## 3. Approaches Considered & Trade-Offs

1. **Approach 1: Gravitational Ripple & Music Pulse**
   - *Pros:* Mesmerizing ambient motion, excellent music immersion via Cava.
   - *Cons:* Lacks direct mouse interactivity when idle.
2. **Approach 2: Astronomical Orbit Ring & Nakshatra Tracker**
   - *Pros:* High informational density and astronomical realism.
   - *Cons:* More static, less kinetic excitement during casual desktop use.
3. **Approach 3: Interactive Glyph Core & Gravity Well**
   - *Pros:* Tactile and fun to explore with mouse cursor; rich telemetry.
   - *Cons:* No reaction to background music.
4. **Selected Synthesis (User Selected: 1 + 3):**
   - Combines ambient gravitational ripples + audio-reactive Cava bass pulse with interactive cursor gravity spring physics, hover telemetry, and Nothing red accent dot.

---

## 4. Technical Architecture & Implementation Details

### A. Dynamic Gravitational Ripples & Audio Pulse (`Orb.qml`)
- **Concentric SVG Wave Rings:** 3 expanding rings radiating outward from radius $R = 195\text{px}$ to $290\text{px}$ in the SVG definitions.
- **Cava Activation:** In `Home.qml`, tie `Cava.active` to `root.home && (Media.playing || bento.model.some(w => w.id === "cava"))`.
- **Bass Modulation:** The ring expansion radius and peak opacity scale dynamically:
  $$\text{expansion} = \text{basePhase} + (\text{Media.playing} ? \text{bass} \times 24 : 0)$$
  $$\text{opacity} = \text{baseOpacity} \times (1.0 + (\text{Media.playing} ? \text{bass} \times 0.6 : 0))$$

### B. Cursor Gravity Spring Physics (`Back.qml` / `Home.qml`)
- Place a 500×500px `HoverHandler` / `MouseArea` centered on the orb.
- Compute normalized relative cursor vector:
  $$dx = \frac{x - x_{\text{center}}}{250}, \quad dy = \frac{y - y_{\text{center}}}{250}, \quad \text{dist} = \min(1.0, \sqrt{dx^2 + dy^2})$$
- Target displacement: $x_{\text{target}} = dx \times 12\text{px}$, $y_{\text{target}} = dy \times 12\text{px}$.
- Animate via `Behavior on transform { SpringAnimation { spring: 2.8; damping: 0.28 } }` for an organic, liquid celestial tug.

### C. Hover Telemetry Badge (`Home.qml`)
- Positioned directly below the Nakshatra name or lunar orb ($y \approx 780$).
- Fades in with `opacity: orbHovered ? 1.0 : 0.0` with `Theme.t` duration.
- Displays:
  - Phase Name: `WAXING CRESCENT` (or current synodic phase name).
  - Illumination percentage: `(moonPhaseFraction * 100).toFixed(1) + "% ILLUMINATED"`.
  - Active Nakshatra: `MULA · मूल`.

### D. Nothing Red Accent Cusp Dot (`Orb.qml`)
- In `moonSvg()`, render a single circle at the northern crescent tip:
  $$\text{tipX} = cx + rx \cdot \cos(\theta), \quad \text{tipY} = cy - R$$
  with fill `#ff2e2e` (Nothing signature red) and gentle breathing opacity ($0.7 \leftrightarrow 1.0$).

### E. Memory & VRAM Safeguards
- All elements render inside the single existing `layer.effect: Dm { step: 8 }` of `Orb.qml`.
- **Zero additional FBO textures** allocated in GPU VRAM.
- Cava process only runs when media is playing or Cava widget is visible.

---

## 5. Verification Plan
1. **Visual & Kinetic Quality:** Verify ripple expansion, bass reactivity with music, cursor spring tilt, and telemetry fade on hover via grim screenshots.
2. **Resource Metrics:** Verify QuickShell RSS remains $\le 335$ MB and GPU VRAM remains $\approx 125$ MiB on RTX 5060.
3. **Desktop Backup Sync:** Mirror all updated files to `~/Desktop/glyph-rice-custom/` and document in `SETUP.md`.
