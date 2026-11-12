# Glyph Rice — Custom Setup Guide

> **Stock rice:** [end-4/glyph](https://github.com/end-4/glyph) on Pop!_OS 24.04 LTS  
> **Compositor:** Hyprland (Lua config) · **Shell:** Quickshell + QML  
> **Aesthetic:** Nothing OS — monochrome halftone dot grid  
> **Location hardcoded:** New Delhi (28.6139°N, 77.2090°E, UTC+5:30)

---

## Overview of All Custom Changes

| Area | File | What Changed |
|---|---|---|
| Home backdrop | `Back.qml` | Moon phase orb, solar arc with flat coloured sun |
| Moon orb renderer | `Orb.qml` | Full rewrite — dynamic SVG moon phase |
| Home layout | `Home.qml` | 2-column bento grid, nakshatra constellation display |
| Lock screen | `LockSurface.qml` | Orbital clock rings (seconds/minutes/hours) |
| Widget config | `glyph.json` | Widget list, layout order |
| DPMS / sleep | `rules.json` | Screen never sleeps automatically |
| Workspace scroll | `keybinds.lua` | Mouse scroll direction inverted (natural) |
| Workspace animation | `animations.lua` | Horizontal `slide`, special `slidefade 15%` |
| Keybinds | `keybinds.lua` | `SUPER+Return` / `SUPER+B` → terminal / browser |
| Fish shell | `config.fish` | `zoxide init fish | source` added |

---

## 1. Prerequisites

Install the stock glyph rice first:

```bash
bash <(curl -s https://end-4.github.io/dots-hyprland-wiki/setup.sh)
# Choose: glyph theme
```

Required packages: `quickshell`, `hyprland`, `fish`, `Space Mono` font.

---

## 2. File Locations

| This repo path | Live system path |
|---|---|
| `quickshell/glyph/home/Back.qml` | `~/.local/share/glyph/config/quickshell/glyph/home/Back.qml` |
| `quickshell/glyph/home/Home.qml` | `~/.local/share/glyph/config/quickshell/glyph/home/Home.qml` |
| `quickshell/glyph/lock/LockSurface.qml` | `~/.local/share/glyph/config/quickshell/glyph/lock/LockSurface.qml` |
| `quickshell/glyph/components/Orb.qml` | `~/.local/share/glyph/config/quickshell/glyph/components/Orb.qml` |
| `state/glyph.json` | `~/.local/state/rice/glyph.json` |
| `rules.json` | `~/.config/demonshot/rules.json` |

> `~/.config/quickshell/glyph` is a **symlink** → `~/.local/share/glyph/config/quickshell/glyph`.  
> Always edit files in `~/.local/share/glyph/config/...`

---

## 3. Apply Custom Files

```bash
GLYPH=~/.local/share/glyph/config/quickshell/glyph

cp quickshell/glyph/home/Back.qml        $GLYPH/home/
cp quickshell/glyph/home/Home.qml        $GLYPH/home/
cp quickshell/glyph/lock/LockSurface.qml $GLYPH/lock/
cp quickshell/glyph/components/Orb.qml   $GLYPH/components/

cp state/glyph.json  ~/.local/state/rice/glyph.json
cp rules.json        ~/.config/demonshot/rules.json

# Swiss Ephemeris nakshatra script
pip install pyswisseph   # in your venv
cp nakshatra-calc ~/.local/bin/nakshatra-calc
chmod +x ~/.local/bin/nakshatra-calc

# Systemd timer (runs on boot + daily at midnight)
mkdir -p ~/.config/systemd/user
cp systemd/nakshatra-calc.service ~/.config/systemd/user/
cp systemd/nakshatra-calc.timer   ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now nakshatra-calc.timer

# Run once now to generate the first JSON
~/.local/bin/nakshatra-calc

~/.local/bin/rice restart
```

---

## 4. Change Details

### 4.1 `Back.qml` — Home Backdrop

**Layer:** `WlrLayer.Background` (behind everything — below Home.qml)

#### Moon Phase Orb
- Fully dynamic SVG moon renderer using NOAA synodic calculation
- Anchored epoch: `1704974220000` ms (Jan 11 2024 confirmed new moon)
- Synodic period: `2551442861` ms (29.53059 days)
- 3-layer luminance: earthshine globe → lit face → outer corona halo
- 5 dark lunar maria ellipses for surface texture
- 100ms breathing timer when home screen is empty
- **API:** `width`, `height`, `step`, `phase` — no `moonRadius` or `scale`

#### Solar Arc (bottom strip, 200px height)
- Full NOAA solar position algorithm for New Delhi
- 90 white monochrome dots along a parabolic arc
- **Brighter dots** = minutes already elapsed today (progress trail)
- **Flat solid sun circle** — no glow layers, clean representation:
  - Outer white ring: `r=19, opacity=0.18`
  - Filled colour circle: `r=15, opacity=1.0`
- **Colour** shifts from solar yellow at noon → deep orange-red at sunrise/sunset
  - Hue: 50° (yellow) → 14° (red-orange), computed via `hslToHex()` helper
  - **Critical:** Qt's SVG renderer silently drops `hsl()` syntax — always convert to hex
- Sunrise/sunset time labels in monochrome below the tick marks
- Sun hidden at night (outside sunrise–sunset window)
- 30-second update timer

#### Key gotcha — Qt SVG and `hsl()`
```javascript
// WRONG — Qt drops this silently, circle becomes transparent:
fill="hsl(27, 95%, 59%)"

// RIGHT — always convert to hex before embedding in SVG:
function hslToHex(h, s, l) { /* ... */ }
fill="#e8820a"
```

---

### 4.2 `Home.qml` — Home Screen Overlay

**Layer:** `WlrLayer.Bottom` (transparent, above Background)  
This is the correct layer for ALL visible text and SVG overlays on the home screen.

> ⚠️ **Never put visible text in `Back.qml`** — it's on `WlrLayer.Background` and gets composited below `Home.qml`. Text placed there will be invisible even though QML shows no errors.

#### Real Astronomical Rashi Constellation & Nakshatra Highlight

**1. Real Astronomical Constellation Renderer (`getRashiSvg`):**
Above the lunar orb (`x: 825, y: 140, width: 270, height: 110`), the system renders the **complete, real astronomical Zodiac constellation (Rashi)**:
- Real celestial stars with exact relative astronomical coordinates and stick-figure lines.
- For Scorpius (Vrischika), all **15 physical stars** are rendered:
  - Claws & Head: Acrab ($\beta$ Sco), Dschubba ($\delta$ Sco), Fang ($\pi$ Sco).
  - Heart (**Jyeshtha**): Al Niyat ($\sigma$ Sco), **Antares ($\alpha$ Sco)**, and Paikauhale ($\tau$ Sco).
  - Body & Curve: Larawag ($\epsilon$ Sco), Denebakrab ($\mu$ Sco), $\zeta$ Sco, $\eta$ Sco.
  - Tail & Stinger (Mula): Sargas ($\theta$ Sco), $\iota$ Sco, $\kappa$ Sco, Shaula ($\lambda$ Sco), Lesath ($\upsilon$ Sco).
- **Clean Dot-Matrix Style (No Light Spill):**
  - Stars are rendered as crisp, solid dots (`#ff453a` for Nakshatra stars, `#ffffff` for other Rashi stars) with clean stick-figure lines. All glow halos and light spill have been removed to preserve the pure Nothing OS halftone aesthetic.
  - No text watermarks appear inside the constellation SVG; only the Nakshatra name is displayed cleanly below it.

**2. Nakshatra Name Below Constellation:**
Right below the constellation diagram and above the moon orb:
```
Jyeshtha
ज्येष्ठा
```
- Clean Space Mono typography with letter spacing + Devanagari text.

**3. Calendar Widget (`calendarW`) — Rashi Moon Sign:**
Anchored near the bottom edge of the calendar bento tile (`bottomMargin: 14`) for a uniform, balanced card layout:
```
vrischika, वृश्चिक
```
- Derived directly from the Swiss Ephemeris sidereal longitude ($0^\circ-30^\circ$ per Rashi).

**Accuracy — Swiss Ephemeris pipeline (±1–2 seconds):**

| Method | Longitude error | Timing error |
|---|---|---|
| Mean longitude only | ±4–6° | ±8–11 hours ❌ |
| 14 Meeus perturbation terms | ±0.3° | ±40 minutes ⚠️ |
| **Swiss Ephemeris (pyswisseph)** | **±0.0003°** | **±1–2 seconds ✅** |

**Architecture:**

```
nakshatra-calc (Python, Swiss Ephemeris)
  ↓  runs on boot (OnBootSec=30s) + daily at 00:01
  ↓  binary-searches exact crossing milliseconds
  ↓  writes ~/.local/state/rice/nakshatra.json (8 days of transitions)
        ↓
Home.qml (FileView, watchChanges:true)
  ↓  auto-reloads file when script rewrites it
  ↓  60-second timer walks transition list
  → Nakshatra flips within 60s of exact astronomical moment
```

**nakshatra.json format:**
```json
{
  "idx": 17,
  "nameEn": "Jyeshtha",
  "nameHi": "ज्येष्ठा",
  "fraction": 0.17,
  "transitions": [
    { "idx": 18, "nameEn": "Mula", "nameHi": "मूल", "ts": 1731393558000 },
    { "idx": 19, "nameEn": "Purva Ashadha", "ts": 1731492847000 },
    ...8 days worth...
  ]
}
```

**Remaining error sources (unavoidable):**
- Lahiri ayanamsa is a committee-defined value with ~0.1° ambiguity between authorities = ±10 min
- Different traditional panchangs disagree by this same margin

**Constellation patterns:** All 27 nakshatras encoded with **exact J2000 celestial astrometry** (Hipparcos and Yale Bright Star Catalogs) projected onto a celestial tangent plane in a 150×90 viewBox. Real physical angles, exact star distance ratios, apparent visual magnitude sizing ($r=3.5$–$7.5$), and astronomical spectral colors (red supergiants `#ff453a`, orange giants `#ff9f0a`, blue-white stars `#70b5ff`). Connecting lines at 25% opacity with crisp solid dots (zero light spill / halos).

Notable patterns:
| Nakshatra | Astronomical Pattern & Stars |
|---|---|
| Ashwini | 3 stars: Hamal ($\alpha$ Ari), Sheratan ($\beta$), Mesarthim ($\gamma$) |
| Bharani | Exact celestial triangle: 41, 39, 35 Arietis |
| Krittika | Pleiades dipper: Alcyone, Electra, Maia, Merope, Taygeta, Atlas, Pleione |
| Rohini | Aldebaran (red giant) + Hyades true V-asterism |
| Ashlesha | Serpent head: 6-star loop ($\delta, \sigma, \eta, \rho, \zeta, \epsilon$ Hydrae) |
| Magha | Regulus (blue-white) + Sickle of Leo ($\eta, \gamma, \zeta, \mu, \epsilon$ Leo) |
| Hasta | Corvus constellation: 5 stars forming the hand / crow |
| Vishakha | Scale arch: $\alpha, \beta, \gamma, \iota$ Librae |
| Jyeshtha | Scorpius heart: Antares (red supergiant, $153.6^\circ$ bend) flanked by $\sigma$ and $\tau$ Scorpii (0.88 distance ratio) |
| Mula | Scorpion tail & stinger curve (8 stars ending at Shaula & Lesath) |
| Shravana | 3 footprints of Vishnu: Altair flanked by Tarazed & Alshain |
| Dhanishtha | Delphinus diamond asterism (4 stars) |
| Shatabhisha | Sadachbia asterism in Aquarius (4 stars) |
| Revati | Fish ring: $\zeta, \epsilon, \delta$ Piscium |

#### Bento Widget Grid (2 columns)
```
x: 1230, cell: 220×220, gap: 20
Row 0: calendar (w=1) + weather  (w=1)
Row 1: player   (w=2, full width span)
Row 2: gpu      (w=1) + ram      (w=1)
```
Guard condition: `c + w > 2` — the `system` widget (span=3) is silently skipped.

#### Clock & Layout
- Clock: `x=80, y=118`, font 290px
- Date: `x=88, y=428` · Greeting: `x=86, y=500` · Meta: `x=88, y=672`

---

### 4.3 `Orb.qml` — Moon Phase Renderer

Complete rewrite of the original static orb. Uses `Image` with computed SVG data URI.

> Template literal backtick syntax inside QML arrow functions causes parse errors.  
> Use named `function` blocks instead.

**Properties:**
```qml
Orb {
    width: 460; height: 460; step: 8
    phase: root.phase   // breathing animation offset
}
```

> Do NOT pass `moonRadius:` or `scale:` — removed from API. Will cause  
> `Cannot assign to non-existent property "moonRadius"` errors.

**Orb sizes across files:**
| File | width/height | step |
|---|---|---|
| `Back.qml` | 460 | 8 |
| `Walls.qml` | 540 | 8 |
| `LockSurface.qml` | 540 | 8 |
| `Prefs.qml` | 160 | 5 |
| `Buds.qml` | 200 | 6 |

---

### 4.4 `LockSurface.qml` — Orbital Clock Rings

Three concentric rings of dots around the lock screen:

| Ring | Dots | Radius | Dot size | Tracks |
|---|---|---|---|---|
| Seconds | 72 | 260px | 5×5 | Current second |
| Minutes | 90 | 320px | 6×6 | Current minute |
| Hours | 60 | 380px | 7–9px | Hour (5-min markers larger) |

- Red dot at index 0 on each ring = 12-o'clock reference
- `SystemClock.Seconds` precision required (changed from Minutes)

---

### 4.5 `glyph.json` — Widget Config

```json
{
  "widgets": ["calendar", "weather", "player", "gpu", "ram"],
  "orb": true,
  "grid": true
}
```

---

### 4.6 `rules.json` — DPMS / Sleep Disabled

```json
{ "dpmsAfter": 0, "sleepAfter": 0 }
```

On NVIDIA, `dpms off` via hypridle caused a wake-loop bug. Set both to 0.

---

### 4.7 Hyprland Keybinds (`keybinds.lua`)

```lua
-- Natural scroll direction (scroll down = next workspace)
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + mouse_up",   hl.dsp.focus({ workspace = "-1" }))

-- Terminal and Browser
hl.bind("SUPER + Return",   function() superTap=false; hl.dispatch(hl.dsp.exec_cmd(vars.terminal)) end)
hl.bind("SUPER + KP_Enter", function() superTap=false; hl.dispatch(hl.dsp.exec_cmd(vars.terminal)) end)
hl.bind(vars.kbBrowser,     function() superTap=false; hl.dispatch(hl.dsp.exec_cmd(vars.browser)) end)
```

> `"Return"` is the correct XKB keysym — `"Enter"` causes `Unknown key` Hyprland errors.

---

### 4.8 Workspace Animations (`animations.lua`)

```lua
hl.animation({ leaf="workspaces",       style="slide",         speed=5 })
hl.animation({ leaf="specialWorkspace", style="slidefade 15%", speed=4 })
```

---

## 5. Adapting to Another City

In `Back.qml`, change three constants in `calcSunTimes()`:

```javascript
const lat = 28.6139,  // latitude  (+ = North, - = South)
      lon = 77.2090,  // longitude (+ = East,  - = West)
      tz  = 5.5;      // UTC offset in hours (India = 5.5)
```

Nakshatra is location-independent — it's purely the Moon's ecliptic position.

---

## 6. Verification After Apply

```bash
~/.local/bin/rice restart
sleep 3
INST=$(ls -t /run/user/1000/quickshell/by-id/ | head -1)
qs --log-rules "*.debug=false" log -i $INST | grep -Ei "error|fail|caused"

# Verify today's nakshatra with accurate perturbed calculation
node -e "
const ts=Date.now(), JD=ts/86400000+2440587.5, T=(JD-2451545)/36525;
const L0=((218.3164477+481267.88123421*T-0.0015786*T*T)%360+360)%360;
const M=((134.9633964+477198.8675055*T+0.0087414*T*T)%360+360)%360;
const D=((297.8501921+445267.1114034*T-0.0018819*T*T)%360+360)%360;
const Ms=((357.5291092+35999.0502909*T-0.0001536*T*T)%360+360)%360;
const F=((93.2720950+483202.0175233*T-0.0036539*T*T)%360+360)%360;
const r=Math.PI/180;
const dL=6.289*Math.sin(M*r)-1.274*Math.sin((2*D-M)*r)+0.658*Math.sin(2*D*r)-0.186*Math.sin(Ms*r);
const trueL=((L0+dL)%360+360)%360;
const ayn=23.853+1.3972*T, sid=((trueL-ayn)%360+360)%360, i=Math.floor(sid/(360/27));
const names=['Ashwini','Bharani','Krittika','Rohini','Mrigashira','Ardra','Punarvasu','Pushya','Ashlesha','Magha','Purva Phalguni','Uttara Phalguni','Hasta','Chitra','Swati','Vishakha','Anuradha','Jyeshtha','Mula','Purva Ashadha','Uttara Ashadha','Shravana','Dhanishtha','Shatabhisha','Purva Bhadrapada','Uttara Bhadrapada','Revati'];
const posInNak=(sid%(360/27))/(360/27)*100;
console.log('Nakshatra:', names[i], '('+(posInNak.toFixed(1))+'% complete)');
console.log('Next nakshatra in:', ((1-posInNak/100)*(360/27)/13.176*24).toFixed(1)+'h');
"
```

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Text/SVG in Back.qml invisible | WlrLayer.Background is below Home.qml | Move all visible text to `Home.qml` (WlrLayer.Bottom) |
| Sun circles transparent in SVG | Qt SVG drops `hsl()` syntax silently | Convert with `hslToHex()` before embedding |
| `Unknown key: Enter` in Hyprland | Invalid XKB keysym | Use `"Return"` / `"KP_Enter"` |
| Super+key opens launcher | Cancellation list missing keys | Add all keys to the super-tap loop |
| Screen turns off, wake causes blank | NVIDIA DPMS bug | Set `dpmsAfter:0`, `sleepAfter:0` in `rules.json` |
| `Cannot assign to non-existent property "moonRadius"` | Old Orb.qml API | Remove `moonRadius:` — use only `width/height/step` |
| `Type Orb unavailable` | Backtick in QML arrow function | Rewrite as named `function` blocks |
| Nakshatra timing off by hours | Using mean Moon longitude | Use Swiss Ephemeris (`nakshatra-calc` with `pyswisseph`) |
| Constellation fuzzy / light spill | Outer glow circles / blur filter | Use solid `<circle fill="..." opacity="1.0"/>`, no halo circles |
| OpenType script 11 warning | Space Mono forced on Devanagari | Remove `font.family: Theme.mono` on Hindi `Text` elements |

---

## 8. Nakshatra, Tithi & Rashi UI Reference

### 8.1 Constellation Above Moon Orb
- **All 27 Nakshatras Astrometrically Accurate:** Calculated using true J2000 Right Ascension ($\alpha$) and Declination ($\delta$) coordinates from the Hipparcos and Yale Bright Star Catalogs via celestial tangent plane projection (North Up, East Left).
- **Physical Fidelity:**
  - Exact real angles between stars (e.g. $153.6^\circ$ bend for Jyeshtha, $60^\circ$ triangle for Bharani, Pleiades dipper for Krittika, true V-angle for Rohini).
  - Exact physical distance ratios between every pair of stars (no uniform/fake spacing).
  - Apparent visual magnitude scaling for star dot radii ($r$).
  - Astronomical spectral colors (e.g. `#ff453a` for M-type red supergiants like Antares & Betelgeuse; `#ff9f0a` for K-type orange giants like Arcturus, Pollux, & Algieba; `#70b5ff` for B-type blue-white stars like Spica, Regulus, & Nunki; `#ffffff` for A/F-type white stars).
- **Clean Solid Rendering:** Crisp solid dots (`opacity="1.0"`), zero light spill, zero blur/halo circles.
- **Labels:** English Nakshatra name at `y: 258` (`Space Mono`, pixel size 15), Hindi Nakshatra name at `y: 280` (system sans, pixel size 13).

### 8.2 Date Line with Week, Tithi & Paksha
- **Format:** `week ${root.week(clock.date)} · ${root.tithiEnStr} · ${root.tithiPakshaStr}`
- **Live Display:** `WEEK 46 · TRITIYA · SHUKLAPAKSH` (transitions automatically to `KRISHNAPAKSH` in the waning fortnight)
- **Aesthetic:** Space Mono uppercase with Nothing OS letter tracking.

### 8.3 Calendar Bento Widget
- **Layout:** Vertically centered `Column { anchors.centerIn: parent }` inside 220×220 cell.
- **Hierarchy:**
  1. Month Name (`NOVEMBER`)
  2. Date Number (92px dot-matrix font)
  3. Weekday Row (`M T W T F S S` with active day indicator)
  4. Rashi Sign (`vrischika, वृश्चिक`)
- **Spacing:** Balanced margins above and below with uniform internal padding.

---

### 8.4 Dynamic Day & Night Horizon Arc (`Back.qml`)
- **Daytime (Sunrise to Sunset):**
  - Sun travels along the parabolic arc from left to right.
  - Solar progress: `(nowH - sun.sunrise) / (sun.sunset - sun.sunrise)`.
  - Color gradient: Yellow at solar noon $\rightarrow$ deep red-orange near dawn and dusk.
  - Boundary labels: `[Sunrise Time]` (left) $\rightarrow$ `[Sunset Time]` (right).
- **Nighttime (Sunset to Sunrise):**
  - Moon rises on the eastern horizon (left) at sunset and travels along the same parabolic arc to dawn (right).
  - Night progress: `sinceSunset / ((24 - sunset) + sunrise)`.
  - Dynamic Real Lunar Phase: Rendered with true spherical geometry:
    - Waxing / Waning Crescent, Quarter, Gibbous, and Full Moon matching the active synodic phase (`synodicMs = 2551442861 ms`).
    - Outer moonlight glow (`r=19`, opacity `0.10`), dark base disk (`#181818`, opacity `0.85`), bright lit zone (`#ffffff`, opacity `1.0`), and subtle rim stroke (`#ffffff`, opacity `0.30`).
  - Boundary labels: `[Sunset Time]` (left) $\rightarrow$ `[Sunrise Time]` (right).
  - Dots along the traversed path illuminate in soft moonlight (`opacity="0.72"`).

---

### 8.5 Custom Notes & Tasks Bento Widget (`Home.qml`)
- **Replacement:** Replaces the player widget in the 2-span Bento grid slot (`span: 2`, 460×220px, radius 40).
- **Persistent Storage:** Stored in `~/.local/state/rice/tasks.json` with real-time bidirectional file watching via `FileView`.
- **Dual Capability:**
  - **Tabs Header:**
    - Segmented pills: `[ • TASKS (active/total) ]` and `[ • NOTES (count) ]` with Nothing OS signature red active dot indicators.
    - Single click switches seamlessly between Task list and Notes scratchpad.
  - **Tasks Mode:**
    - **Interactive Tickbox:** Circular dot indicators. Clicking toggles done state; checked items turn Nothing red (`#ff453a`) with a white checkmark `✓` and strike-through text.
    - **Add Task:** Click `+ ADD TASK` to open an inline input bar with Space Mono placeholder. Pressing `Enter` or clicking `✓` adds the task immediately.
    - **Edit Task:** Hovering over any task reveals the `✎` edit button (or double-click task text) to edit inline. Press `Enter` or click `✓` to save.
    - **Remove Task:** Click `✕` to delete any task.
    - **Clear Done:** Dedicated button appears when completed tasks exist to clean up finished items.
  - **Notes Mode:**
    - **Multi-Note Scratchpad:** Supports multiple notes with pagination controls (`‹ 1/N ›`).
    - **New Note:** Click `+ NEW NOTE` to generate a fresh note page.
    - **Delete Note:** Click `✕` to delete the current active note page.
    - **Inline Title & Body:** Space Mono title line + scrollable multi-line `TextEdit` inside `Flickable` with automatic debounced background autosaving to `tasks.json`.
- **Wayland Keyboard Interactivity:**
  - Dynamic focus switching: When any input field gains focus, `Home.qml` promotes to `WlrLayer.Top` and activates `WlrKeyboardFocus.Exclusive` so keystrokes route directly to the widget. Upon pressing `Enter`, `Escape`, or clicking outside, focus releases cleanly back to Hyprland and layer returns to `WlrLayer.Bottom`.

---

### 8.6 Switching & Customizing Widgets via Super + I Menu
- **Native Integration:** Both `notes` (Notes & Tasks Widget) and `player` (Music Player) are registered in `Theme.kinds` and `Prefs.qml` icons.
- **Controls in Settings (`Super + I`):**
  - **Bottom Tray:** Click the `notes` circle (memo icon) or `player` circle (music play icon) to add/remove them from the Bento layout.
  - **Grid Mockup:** Click any placed widget cell to cycle through available widgets (`weather`, `calendar`, `cpu`, `ram`, `gpu`, `disk`, `battery`, `buds`, `notes`, `player`, `system`, `cat`, `cava`).
  - **Drag & Reorder:** Drag tiles on the mockup to reposition them across the grid.
  - **Persistence:** Any changes made in the `Super + I` menu immediately update `~/.local/state/rice/glyph.json` and hot-reload on the desktop.

---

### 8.7 High-Resolution Dot-Matrix Clock (`Home.qml`)
- **Proportions:** Scaled down by ~20% from 290px to 236px (`font.pixelSize: 236`), harmonizing with the Bento grid column height.
- **High-Density LED Dot Matrix:**
  - Rather than low-resolution 4×7 chunky dots, the clock uses Nothing OS's SPIR-V dot shader (`Dm { step: 9.5 }`) over bold typography (`Theme.ui`, `Space Grotesk Bold`).
  - Renders ~14 horizontal and 22 vertical crisp circular LED dots per digit, creating an ultra high-resolution, premium digital display look.
  - Symmetrical colon dots with breathing blink pulse.
- **Vertical Hierarchy:**
  - Clock: `y: 130` (aligned with top of Bento grid).
  - Date & Tithi: `y: 400`.
  - Greeting: `y: 460` (`font.pixelSize: 48`).
  - Notifications & Weather line: `y: 630`.

---

### 8.8 Customizable Dotted Greeting & Name (`Home.qml` & `Prefs.qml`)
- **Dotted Theme Styling:** Both the greeting line (`Good evening,` or custom) and the user name (`Vaishno.`) are rendered in the Nothing OS dot matrix using `Dm { step: 4 }` with high-density LED dots.
- **Customization Methods:**
  1. **Direct On-Screen Editing:**
     - Hover over the greeting on the home screen to reveal the `[ ✎ CUSTOMIZE GREETING ]` pill (or double-click the greeting text).
     - Inline text inputs for **Greeting** (leave empty for automatic time-based greeting: Good morning / afternoon / evening / night) and **Name**.
     - Click `✓ SAVE` to immediately persist to disk.
  2. **Settings Menu (`Super + I`):**
     - Navigate to the `LOOK` page.
     - Dedicated input fields for both `greeting` and `name`.
  3. **Direct Config File:**
     - Stored in `~/.local/state/rice/glyph.json`: `"greeting": ""` and `"name": "Vaishno"`.

---

### 8.9 Real-Time Nakshatra & Tithi Reactive Engine (`Home.qml`)
- **SystemClock Synchronization:**
  - Bound all celestial calculations directly to Quickshell's reactive `SystemClock` (`clock.date`):
    ```qml
    readonly property double nowMs: clock.date ? clock.date.getTime() : Date.now()
    ```
  - Eliminates reliance on non-reactive JavaScript `Date.now()` calls.
  - All 8 planetary bindings (`nakshatraIdx`, `nakshatraEnStr`, `nakshatraHiStr`, `rashiEnStr`, `rashiSaStr`, `rashiHiStr`, `tithiEnStr`, `tithiPakshaStr`) automatically re-evaluate in real time on every minute boundary.
  - Transitions switch dynamically on the exact second/minute (e.g. Jyeshtha -> Mula at 14:19 IST, Mula -> Purva Ashadha at 17:17 IST) without manual reloads.

---

### 8.10 Ultra-Smooth Shooting Stars & Comets Engine (`ShootingStars.qml`)
- **High-Performance Architecture:**
  - Implemented in `ShootingStars.qml` and integrated into `Back.qml` as a native Qt Quick SceneGraph layer.
  - 100% GPU hardware-accelerated with zero runtime heap allocations.
  - Zero idle CPU overhead (animations completely stop when streaks finish).
- **Three Concurrent Multi-Radiant Channels:**
  1. **Channel 1 (Agile Shooting Stars):** Quick, razor-sharp streaks (650–1050 ms, 160–260px tail) triggering every 4–8 seconds.
  2. **Channel 2 (Cross-Sky / Counter-Angle Meteors):** Opposing angle streaks traveling across the sky every 7–12 seconds, allowing simultaneous crossing meteors.
  3. **Channel 3 (Grand Comets):** Majestic, wide celestial comets (2200–3100 ms, 360–480px tail) traveling gracefully with an ethereal cyan/golden ion aura and Nothing OS dot-matrix wake sparks every 16–26 seconds.
- **Diverse Trajectories ("Traveling From Here and There"):**
  - **Northwest Radiant:** Classic diagonal plunge ($32^\circ$ to $48^\circ$ down-right).
  - **Northeast Radiant:** Counter diagonal ($132^\circ$ to $148^\circ$ down-left).
  - **High-Atmosphere Glider:** Shallow sweep across the upper horizon ($12^\circ$ to $22^\circ$).
  - **Steep Plunge:** Near-vertical atmospheric drop ($60^\circ$ to $75^\circ$).
  - **Sporadic Red Flare:** 1 in 10 meteors flashes with the Nothing OS signature red accent glow (`Theme.red`).
- **Settings Menu Integration:**
  - Added a dedicated `shooting stars` toggle under the `LOOK` page in `Super + I` (`Prefs.qml`).
  - Persisted state in `~/.local/state/rice/glyph.json` under `"stars": true`.

---

### 8.11 Subtle Atmospheric Sun Corona Glow (`Back.qml`)
- **Soft Atmospheric Fall-off:**
  - Added a multi-stage feathered radial corona aura surrounding the sun disc along the horizon arc.
  - Uses feathered concentric geometric fall-off with opacity stepping ($0.26 \to 0.18 \to 0.12 \to 0.07 \to 0.04$) up to radius 30px.
  - Dynamically adopts the real-time solar color temperature (golden yellow at solar noon, deepening to warm amber/orange approaching sunset/sunrise).
  - Eliminates harsh ring artifacts, providing a gentle, radiant sun presence without overwhelming the minimal Nothing OS dot-matrix theme.

---

### 8.12 High-Resolution Seconds Counter with MagicUI Morphing Text (`MorphingDigit.qml` & `Home.qml`)
- **Proportions & Spatial Balance:**
  - Clock font scaled to `pixelSize: 160` (width ~600px, height 160px) to seamlessly accommodate hours, minutes, and seconds (`HH : MM : SS`).
  - Adjusted dot matrix density with `Dm { step: 6.5 }` to maintain ultra-dense, crisp circular LED dots (~24 vertical dots per digit).
  - Vertically aligned top row: clock top ($y=140$) and bottom ($y=300$) balance the Bento grid's top row ($y=130$ to $y=314$).
  - Re-spaced left column: Date line ($y=338$), Greeting ($y=390$), Meta notifications row ($y=530$).
- **MagicUI Morphing Text Physics:**
  - Designed in [`MorphingDigit.qml`](file:///home/creserver/.local/share/glyph/config/quickshell/glyph/components/MorphingDigit.qml) using dual-layer cross-fading, micro-scaling ($1.0 \to 0.88$ on exit, $1.10 \to 1.0$ on entry), and vertical micro-drift.
  - As digits transition over a 350ms window, the Nothing OS SPIR-V dot shader (`Dm`) causes the outgoing number's dots to shrink and dissolve like liquid droplets while the incoming number's dots swell and coalesce into place.
  - Independent digit cells: the tens and ones digits transition independently, eliminating any horizontal jitter.
- **Precision Time Synchronization:**
  - Configured `SystemClock { precision: SystemClock.Seconds }` in `Home.qml` for 1000ms real-time precision.

---

### 8.13 Solid Non-Blinking Colons & Zero-Allocation RAM/VRAM Optimization
- **Solid Colons (No Blinking):**
  - Completely disabled and removed the 500ms blink timer in `Home.qml` (`Timer { interval: 500 }`).
  - Configured both clock colons (`HH : MM` and `MM : SS`) with rock-solid `Theme.fg` and 100% steady opacity.
  - Set `"blink": false` in `~/.local/state/rice/glyph.json`.
  - Eliminates 120 timer wakeups per minute, keeping the clock dots steady and saving CPU cycles.
- **Zero-Allocation RAM & VRAM Discipline:**
  - Stripped all nested `MultiEffect` and `QtQuick.Effects` from `MorphingDigit.qml`.
  - Instead of creating secondary and tertiary offscreen Framebuffer Objects (FBOs) in VRAM for blur passes, the morphing digit renders directly into the parent `clockArea` dot-matrix FBO.
  - The halftone dot-matrix shader (`Dm { step: 6.5 }`) naturally executes the gooey morphing effect directly on standard SceneGraph vertex transforms (scale, translation, and opacity), requiring **zero extra VRAM textures**.
  - Quiescent state: outgoing digit containers are completely hidden (`visible: false`) when idle, so no rendering cost occurs between ticks.
  - **Verified System Metrics:**
    - Quickshell RSS memory: ~326 MB (~1.0% system RAM).
    - GPU VRAM consumption: ~125 MiB on NVIDIA GeForce RTX 5060 (total system VRAM ~450 MiB / 8151 MiB).
    - GPU utilization: ~1% with negligible ~17W idle power.
