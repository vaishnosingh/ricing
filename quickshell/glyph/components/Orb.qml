import QtQuick
import QtQuick.Shapes
import qs
import qs.services

// Moon Phase Orb — Nothing OS dot-matrix edition
// Combines physically accurate synodic moon phases with:
//   1. Cosmic Gravitational Wave Ripples: concentric dot rings expanding and fading into deep space
//   2. Audio-Reactive Bass Pulse: Cava visualizer modulation when music is playing
//   3. Surface Glint & Nothing Red Accent Dot at lunar cusp
//   4. Three-layer luminance architecture rendered through Dm { step: 8 }
Item {
    id: root

    // Breathing & ripple wave phase (driven by Back.qml timer)
    property real phase: 0
    property real step: 8
    property bool breathe: true

    // Audio responsiveness via Cava
    readonly property bool hasAudio: Media.playing && Cava.active
    readonly property real bass: hasAudio ? Math.min(1.0, ((Cava.bars[0] || 0) + (Cava.bars[1] || 0)) * 0.75) : 0.0

    // Astronomical reference · Jan 11 2024 11:57 UTC — confirmed new moon
    readonly property real refMs:     1704974220000
    readonly property real synodicMs: 2551442861     // 29.53058867 days

    property real nowMs: Date.now()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.nowMs = Date.now() }

    property real forcedPhase: -1  // set 0..1 to override for previews

    readonly property real moonPhase: {
        if (forcedPhase >= 0 && forcedPhase <= 1) return forcedPhase
        const d = (nowMs - refMs) % synodicMs
        return (d < 0 ? d + synodicMs : d) / synodicMs
    }
    readonly property real moonAge: moonPhase * 29.53058867

    // Dynamic scale pulse on bass hit
    scale: 1.0 + (root.bass * 0.04)
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    // Breathing: subtle ±4% opacity pulse + bass surge
    width:   540
    height:  540
    opacity: (breathe ? (0.70 + 0.04 * Math.sin(phase * 2 * Math.PI / 8)) : 0.72) + (root.bass * 0.15)

    layer.enabled: true
    layer.textureSize: Qt.size(540, 540)
    layer.effect: Dm { step: root.step }

    // ── SVG moon with three luminance layers & gravitational ripples ─────────
    function moonSvg(phi, s, ph, bAmp) {
        // s = size (square canvas), center at s/2
        const cx = s * 0.5, cy = s * 0.5
        const R  = s * 0.36      // moon disk — 72% of canvas (~194px)
        const rH = s * 0.46      // halo radius — bleeds 10% beyond disk edge

        // Phase geometry  ·  terminator x-radius
        const rx = R * Math.abs(Math.cos(2 * Math.PI * phi))

        const top = `${cx} ${cy - R}`
        const bot = `${cx} ${cy + R}`

        // Build the SVG path for the lit zone
        let litPath = ''
        if (phi < 0.015 || phi > 0.985) {
            // New moon — no lit zone, only the dim globe
            litPath = ''
        } else if (phi > 0.49 && phi < 0.51) {
            // Full moon — entire disk
            litPath = `M ${cx - R} ${cy} A ${R} ${R} 0 1 0 ${cx + R} ${cy} A ${R} ${R} 0 1 0 ${cx - R} ${cy} Z`
        } else if (phi <= 0.5) {
            // Waxing — lit on the right
            const sw = phi < 0.25 ? 0 : 1   // crescent bows right (0), gibbous bows left (1)
            litPath = `M ${top} A ${R} ${rx} 0 0 1 ${bot} A ${rx} ${R} 0 0 ${sw} ${top} Z`
        } else {
            // Waning — lit on the left
            const sw = phi < 0.75 ? 0 : 1   // gibbous bows right (0), crescent bows left (1)
            litPath = `M ${top} A ${R} ${rx} 0 0 0 ${bot} A ${rx} ${R} 0 0 ${sw} ${top} Z`
        }

        // Gradient focal point: sunlight comes from the lit side
        const litSide = phi <= 0.5 ? 1 : -1  // +1 = right, -1 = left
        const gx = 50 + litSide * 32          // 82% or 18%
        const gy = 42

        // ── Gravitational Wave Ripples (3 concentric expanding rings) ────────
        let rippleSvg = '';
        const numRipples = 3;
        for (let i = 0; i < numRipples; i++) {
            // Normalized phase progression 0.0 -> 1.0
            const prog = ((ph / (2.0 * Math.PI) + (i / numRipples)) % 1.0 + 1.0) % 1.0;
            // Radius expands from R + 4px up to R + 64px + bass expansion
            const rRip = (R + 4) + prog * (60 + bAmp * 26);
            // Opacity fades smoothly to 0 as it expands outward
            const opRip = Math.max(0, (1.0 - prog) * (0.28 + bAmp * 0.35));
            rippleSvg += `<circle cx="${cx}" cy="${cy}" r="${rRip.toFixed(1)}" fill="none" stroke="#ffffff" stroke-width="2.2" opacity="${opRip.toFixed(3)}"/>`;
        }

        // ── Nothing Signature Red Accent Dot at lunar crescent cusp ──────────
        let redAccentSvg = '';
        if (phi > 0.02 && phi < 0.98) {
            // Position dot right at the northern crescent horn tip
            const tipX = cx + (phi <= 0.5 ? 1 : -1) * (R * 0.08);
            const tipY = cy - R + 3;
            const redOp = (0.75 + 0.25 * Math.sin(ph * 2.0) + bAmp * 0.25).toFixed(2);
            redAccentSvg = `<circle cx="${tipX.toFixed(1)}" cy="${tipY.toFixed(1)}" r="4.2" fill="#ff2e2e" opacity="${redOp}"/>`;
        }

        // ── Lunar Highland Surface Glints ────────────────────────────────────
        let glintSvg = '';
        if (phi > 0.03 && phi < 0.97) {
            const g1Op = Math.max(0, 0.45 * Math.sin(ph * 3.0)).toFixed(2);
            const g2Op = Math.max(0, 0.40 * Math.cos(ph * 2.4 + 1.2)).toFixed(2);
            const glintX = cx + litSide * (rx * 0.45);
            glintSvg = `<circle cx="${(glintX).toFixed(1)}" cy="${(cy - R * 0.32).toFixed(1)}" r="2.8" fill="#ffffff" opacity="${g1Op}"/>` +
                       `<circle cx="${(glintX - litSide * 8).toFixed(1)}" cy="${(cy + R * 0.28).toFixed(1)}" r="2.5" fill="#ffffff" opacity="${g2Op}"/>`;
        }

        return `<svg xmlns="http://www.w3.org/2000/svg" width="${s}" height="${s}" viewBox="0 0 ${s} ${s}">
<defs>
  <!-- LAYER 3: soft outer halo — moonlight atmosphere -->
  <radialGradient id="halo" cx="50%" cy="50%" r="50%">
    <stop offset="68%"  stop-color="#fff" stop-opacity="0"/>
    <stop offset="78%"  stop-color="#fff" stop-opacity="${(0.11 + bAmp * 0.12).toFixed(2)}"/>
    <stop offset="88%"  stop-color="#fff" stop-opacity="${(0.07 + bAmp * 0.08).toFixed(2)}"/>
    <stop offset="100%" stop-color="#fff" stop-opacity="0"/>
  </radialGradient>

  <!-- LAYER 1: dim globe — the full lunar sphere, always visible -->
  <radialGradient id="globe" cx="44%" cy="38%" r="62%">
    <stop offset="0%"   stop-color="#fff" stop-opacity="0.42"/>
    <stop offset="55%"  stop-color="#fff" stop-opacity="0.30"/>
    <stop offset="85%"  stop-color="#bbb" stop-opacity="0.18"/>
    <stop offset="100%" stop-color="#888" stop-opacity="0.08"/>
  </radialGradient>

  <!-- LAYER 2: bright lit zone — the phase itself -->
  <radialGradient id="lit" cx="${gx}%" cy="${gy}%" r="68%">
    <stop offset="0%"   stop-color="#fff" stop-opacity="1.0"/>
    <stop offset="40%"  stop-color="#fff" stop-opacity="0.97"/>
    <stop offset="72%"  stop-color="#eee" stop-opacity="0.88"/>
    <stop offset="92%"  stop-color="#ccc" stop-opacity="0.65"/>
    <stop offset="100%" stop-color="#999" stop-opacity="0.35"/>
  </radialGradient>

  <clipPath id="disk"><circle cx="${cx}" cy="${cy}" r="${R}"/></clipPath>
</defs>

<!-- Gravitational Wave Ripples in deep space -->
${rippleSvg}

<!-- LAYER 3 · Halo (outside disk, bleeds into background dot grid) -->
<circle cx="${cx}" cy="${cy}" r="${rH}" fill="url(#halo)"/>

<!-- LAYER 1 · Full dim globe — every dot in the sphere is at least dim -->
<circle cx="${cx}" cy="${cy}" r="${R}" fill="url(#globe)"/>

<!-- Lunar maria — dark basalt seas deepen surface contrast -->
<g clip-path="url(#disk)" opacity="0.22" fill="#000">
  <ellipse cx="${cx-R*.35}" cy="${cy-R*.25}" rx="${R*.28}" ry="${R*.21}" transform="rotate(-15 ${cx-R*.35} ${cy-R*.25})"/>
  <ellipse cx="${cx+R*.20}" cy="${cy-R*.12}" rx="${R*.17}" ry="${R*.14}"/>
  <ellipse cx="${cx+R*.32}" cy="${cy+R*.12}" rx="${R*.15}" ry="${R*.13}"/>
  <ellipse cx="${cx+R*.58}" cy="${cy-R*.14}" rx="${R*.09}" ry="${R*.07}"/>
  <ellipse cx="${cx-R*.20}" cy="${cy+R*.33}" rx="${R*.17}" ry="${R*.14}"/>
</g>

<!-- LAYER 2 · Bright lit zone — the sunlit phase burns bright -->
${litPath ? `<path d="${litPath}" fill="url(#lit)"/>` : ''}

<!-- Surface highland micro-glints -->
${glintSvg}

<!-- Nothing Signature Red Accent Dot at lunar cusp -->
${redAccentSvg}

</svg>`
    }

    Image {
        anchors.fill: parent
        source: "data:image/svg+xml," + encodeURIComponent(root.moonSvg(root.moonPhase, 540, root.phase, root.bass))
    }
}
