import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// home backdrop — dot grid, moon phase orb, solar arc, wallpaper
PanelWindow {
    id: root

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "glyph-back"

    readonly property bool home: (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) === 0
    property real phase: 0
    Timer { running: root.home && orb.visible; interval: 100; repeat: true; onTriggered: root.phase += 0.1 }

    // Solar time — updates every 30 s for smooth sun movement
    property real nowMs: Date.now()
    Timer { interval: 30000; running: !wall.opaque; repeat: true; onTriggered: root.nowMs = Date.now() }

    // ── NOAA Solar calculation — New Delhi (28.6139°N, 77.2090°E, UTC+5:30) ──
    // Returns { sunrise, solarNoon, sunset } as decimal hours in IST
    function calcSunTimes(ts) {
        const lat = 28.6139, lon = 77.2090, tz = 5.5;
        const JD  = ts / 86400000.0 + 2440587.5;
        const JC  = (JD - 2451545.0) / 36525.0;

        // Geometric mean longitude & anomaly (°)
        const L0 = ((280.46646 + JC * (36000.76983 + JC * 0.0003032)) % 360 + 360) % 360;
        const M  = 357.52911 + JC * (35999.05029 - 0.0001537 * JC);
        const Mr = M * Math.PI / 180;

        // Equation of centre & true longitude
        const C   = Math.sin(Mr)   * (1.914602 - JC * (0.004817 + 0.000014 * JC))
                  + Math.sin(2*Mr) * (0.019993 - 0.000101 * JC)
                  + Math.sin(3*Mr) * 0.000289;
        const om  = 125.04 - 1934.136 * JC;
        const omr = om * Math.PI / 180;
        const lam = (L0 + C) - 0.00569 - 0.00478 * Math.sin(omr);

        // Obliquity of ecliptic & declination
        const eps0 = 23.0 + (26.0 + (21.448 - JC*(46.815 + JC*(0.00059 - JC*0.001813))) / 60.0) / 60.0;
        const eps  = (eps0 + 0.00256 * Math.cos(omr)) * Math.PI / 180;
        const sinD = Math.sin(eps) * Math.sin(lam * Math.PI / 180);
        const D    = Math.asin(sinD);

        // Equation of time (minutes)
        const eTan = Math.pow(Math.tan(eps / 2), 2);
        const L0r  = L0 * Math.PI / 180;
        const ecc  = 0.016708634 - JC * (0.000042037 + 0.0000001267 * JC);
        const EqT  = 4 * (180/Math.PI) * (
                      eTan * Math.sin(2*L0r)
                    - 2*ecc * Math.sin(Mr)
                    + 4*ecc*eTan * Math.sin(Mr) * Math.cos(2*L0r)
                    - 0.5*eTan*eTan * Math.sin(4*L0r)
                    - 1.25*ecc*ecc * Math.sin(2*Mr));

        // Solar noon (minutes from midnight, local IST)
        const noonMin = 720 - 4*lon - EqT + tz * 60;

        // Hour angle for zenith = 90.833° (refraction + sun disc)
        const latR  = lat * Math.PI / 180;
        const cosHA = (Math.cos(90.833 * Math.PI/180) - Math.sin(latR)*sinD)
                    / (Math.cos(latR) * Math.cos(D));
        if (Math.abs(cosHA) > 1) return { sunrise: 6.0, solarNoon: 12.0, sunset: 18.0 };

        const HA = Math.acos(cosHA) * 180 / Math.PI;
        return {
            sunrise:   (noonMin - 4*HA) / 60,
            solarNoon: noonMin / 60,
            sunset:    (noonMin + 4*HA) / 60
        };
    }

    // ── HSL → Hex (Qt SVG does not support hsl() syntax) ─────────────────────
    function hslToHex(h, s, l) {
        s /= 100; l /= 100;
        const a = s * Math.min(l, 1 - l);
        const f = function(n) { const k=(n+h/30)%12; return l-a*Math.max(Math.min(k-3,9-k,1),-1); };
        const r = Math.round(f(0)*255), g = Math.round(f(8)*255), b = Math.round(f(4)*255);
        const h2 = function(x){ return x.toString(16).padStart(2,'0'); };
        return '#'+h2(r)+h2(g)+h2(b);
    }

    // ── Solar & Lunar Horizon Arc SVG ────────────────────────────────────────
    // Day: Sun moves along arc from sunrise to sunset.
    // Night: Moon rises at sunset and moves along arc to sunrise with real phase.
    function solarArcSvg(ts, W, H) {
        const sun  = calcSunTimes(ts);
        const now  = new Date(ts);
        const nowH = now.getHours() + now.getMinutes()/60 + now.getSeconds()/3600;

        const margin = 100;
        const arcW   = W - 2 * margin;
        const yBase  = H - 30;
        const yPeak  = 50;

        const isDay = nowH >= sun.sunrise && nowH <= sun.sunset;

        let activeProgress = 0;
        if (isDay) {
            activeProgress = Math.max(0, Math.min(1, (nowH - sun.sunrise) / (sun.sunset - sun.sunrise)));
        } else {
            const nightDuration = (24.0 - sun.sunset) + sun.sunrise;
            const sinceSunset = (nowH >= sun.sunset) ? (nowH - sun.sunset) : ((24.0 - sun.sunset) + nowH);
            activeProgress = Math.max(0, Math.min(1, sinceSunset / nightDuration));
        }

        // 90 arc dots — illuminate path up to current celestial position
        const N = 90;
        let arcDots = '';
        for (let i = 0; i <= N; i++) {
            const t  = i / N;
            const dx = (margin + t * arcW).toFixed(1);
            const dy = (yBase + (yPeak - yBase) * 4 * t * (1 - t)).toFixed(1);
            const op = (t < activeProgress - 0.005) ? '0.72' : '0.22';
            arcDots += '<circle cx="'+dx+'" cy="'+dy+'" r="3.5" fill="#fff" opacity="'+op+'"/>';
        }

        // Tick marks
        const ticks =
            '<line x1="'+margin+'" y1="'+(yBase-14)+'" x2="'+margin+'" y2="'+(yBase+4)+'" stroke="#fff" stroke-width="1.5" opacity="0.50"/>' +
            '<line x1="'+(W-margin)+'" y1="'+(yBase-14)+'" x2="'+(W-margin)+'" y2="'+(yBase+4)+'" stroke="#fff" stroke-width="1.5" opacity="0.50"/>';

        function fmtH(h) {
            const hh=Math.floor(h), mm=Math.floor((h-hh)*60);
            return (hh<10?'0':'')+hh+':'+(mm<10?'0':'')+mm;
        }

        // Left label = start of cycle, right label = end of cycle
        const leftLabel  = isDay ? fmtH(sun.sunrise) : fmtH(sun.sunset);
        const rightLabel = isDay ? fmtH(sun.sunset)  : fmtH(sun.sunrise);
        const labels =
            '<text x="'+margin+'" y="'+(yBase+22)+'" text-anchor="middle" font-family="monospace" font-size="13" fill="#fff" opacity="0.55">'+leftLabel+'</text>' +
            '<text x="'+(W-margin)+'" y="'+(yBase+22)+'" text-anchor="middle" font-family="monospace" font-size="13" fill="#fff" opacity="0.55">'+rightLabel+'</text>';

        let celestialBody = '';
        if (isDay) {
            // Sun on the arc with very subtle atmospheric corona glow
            const sun_x = margin + activeProgress * arcW;
            const sun_y = yBase + (yPeak - yBase) * 4 * activeProgress * (1 - activeProgress);
            const sx = sun_x.toFixed(1), sy = sun_y.toFixed(1);
            const d = Math.abs(activeProgress - 0.5) * 2;
            const col = hslToHex(50 - d * 36, 95, 68 - d * 14);

            // Very subtle feathered atmospheric corona glow around the sun disc
            celestialBody =
                '<!-- Subtle atmospheric corona glow -->' +
                '<circle cx="'+sx+'" cy="'+sy+'" r="30" fill="'+col+'" opacity="0.04"/>' +
                '<circle cx="'+sx+'" cy="'+sy+'" r="25" fill="'+col+'" opacity="0.07"/>' +
                '<circle cx="'+sx+'" cy="'+sy+'" r="21" fill="'+col+'" opacity="0.12"/>' +
                '<circle cx="'+sx+'" cy="'+sy+'" r="18" fill="'+col+'" opacity="0.18"/>' +
                '<circle cx="'+sx+'" cy="'+sy+'" r="16" fill="'+col+'" opacity="0.26"/>' +
                '<!-- Sun core disc -->' +
                '<circle cx="'+sx+'" cy="'+sy+'" r="15" fill="'+col+'" opacity="1.0"/>';
        } else {
            // Moon on the arc with actual current lunar phase!
            const moon_x = margin + activeProgress * arcW;
            const moon_y = yBase + (yPeak - yBase) * 4 * activeProgress * (1 - activeProgress);
            const mx = moon_x.toFixed(1), my = moon_y.toFixed(1);

            // Astronomical synodic phase calculation (Jan 11 2024 new moon reference)
            const refMs = 1704974220000.0;
            const synodicMs = 2551442861.0;
            const diff = (ts - refMs) % synodicMs;
            const phi = (diff < 0 ? diff + synodicMs : diff) / synodicMs;

            const R = 15;
            const b = (R * Math.abs(Math.cos(2 * Math.PI * phi))).toFixed(1);
            const top = mx + ' ' + (moon_y - R).toFixed(1);
            const bot = mx + ' ' + (moon_y + R).toFixed(1);

            let litPath = '';
            if (phi < 0.02 || phi > 0.98) {
                // New Moon: dark disk
                litPath = '';
            } else if (phi > 0.48 && phi < 0.52) {
                // Full Moon: fully illuminated
                litPath = '<circle cx="'+mx+'" cy="'+my+'" r="'+R+'" fill="#ffffff" opacity="1.0"/>';
            } else if (phi < 0.5) {
                // Waxing: lit on the RIGHT
                const sw = (phi < 0.25) ? 0 : 1;
                litPath = '<path d="M ' + top + ' A ' + R + ' ' + R + ' 0 0 1 ' + bot + ' A ' + b + ' ' + R + ' 0 0 ' + sw + ' ' + top + ' Z" fill="#ffffff" opacity="1.0"/>';
            } else {
                // Waning: lit on the LEFT
                const sw = (phi < 0.75) ? 0 : 1;
                litPath = '<path d="M ' + top + ' A ' + R + ' ' + R + ' 0 0 0 ' + bot + ' A ' + b + ' ' + R + ' 0 0 ' + sw + ' ' + top + ' Z" fill="#ffffff" opacity="1.0"/>';
            }

            celestialBody =
                '<!-- Moon glow -->' +
                '<circle cx="'+mx+'" cy="'+my+'" r="19" fill="#ffffff" opacity="0.10"/>' +
                '<!-- Moon dark base disk -->' +
                '<circle cx="'+mx+'" cy="'+my+'" r="15" fill="#181818" opacity="0.85"/>' +
                '<!-- Moon rim outline -->' +
                '<circle cx="'+mx+'" cy="'+my+'" r="15" fill="none" stroke="#ffffff" stroke-width="0.8" opacity="0.30"/>' +
                '<!-- Moon lit phase -->' +
                litPath;
        }

        return '<svg xmlns="http://www.w3.org/2000/svg" width="'+W+'" height="'+H+'" viewBox="0 0 '+W+' '+H+'">' +
               arcDots + ticks + labels + celestialBody + '</svg>';
    }

    Stage {
        id: stage

        // Background dot grid
        Image {
            visible: Theme.state.grid && !wall.opaque
            anchors.fill: parent
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="#${Theme.hex(Theme.s2)}"/></svg>`)
        }

        // ── Solar arc — anchored to bottom of screen ──────────────────────
        Image {
            visible: !wall.opaque
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 200    // tall enough for sun glow + labels
            fillMode: Image.Stretch
            source: "data:image/svg+xml," + encodeURIComponent(root.solarArcSvg(root.nowMs, 1920, 200))
        }

        Wall { id: wall; anchors.fill: parent; path: Theme.wallSrc(Theme.state.wall); animate: !Sys.wallOpen }

        // Moon phase orb — centred (above Wall in z-order)
        Orb {
            id: orb
            visible: Theme.state.orb && !wall.opaque
            anchors.centerIn: parent
            width: 460
            height: 460
            step: 8
            phase: root.phase
        }

        // Ultra-smooth shooting stars and comets travelling across the sky
        ShootingStars {
            anchors.fill: parent
            visible: !wall.opaque
        }
    }
}
