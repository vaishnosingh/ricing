import QtQuick
import QtQuick.Shapes
import qs

// Moon Phase Orb — Nothing OS dot-matrix edition
// Ultra-clean, realistic astronomical lunar phase renderer:
//   - Three-layer luminance architecture: dim earthshine globe, blazing sunlit phase, soft outer halo
//   - Basaltic lunar maria for surface contrast and depth
//   - Nothing OS signature red accent dot at northern lunar cusp
//   - Silky-smooth GPU scene-graph opacity breathing (zero SVG re-rasterization churn)
Item {
    id: root

    property real step: 8
    property bool breathe: true

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

    width:  480
    height: 480

    // Silky-smooth GPU-side opacity breathing without any SVG rebuilding
    opacity: 0.72
    SequentialAnimation on opacity {
        running: root.breathe
        loops: Animation.Infinite
        NumberAnimation { from: 0.68; to: 0.76; duration: 4000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.76; to: 0.68; duration: 4000; easing.type: Easing.InOutSine }
    }

    layer.enabled: true
    layer.textureSize: Qt.size(width, height)
    layer.effect: Dm { step: root.step }

    // ── SVG Moon Phase Geometry (rendered once per phase update) ─────────────
    function moonSvg(phi, s) {
        const cx = s * 0.5, cy = s * 0.5
        const R  = s * 0.36      // moon disk (~173px radius)
        const rH = s * 0.46      // halo radius

        // Phase geometry · terminator x-radius
        const rx = R * Math.abs(Math.cos(2 * Math.PI * phi))

        const top = `${cx} ${cy - R}`
        const bot = `${cx} ${cy + R}`

        // Build the SVG path for the lit zone
        let litPath = ''
        if (phi < 0.015 || phi > 0.985) {
            litPath = ''
        } else if (phi > 0.49 && phi < 0.51) {
            litPath = `M ${cx - R} ${cy} A ${R} ${R} 0 1 0 ${cx + R} ${cy} A ${R} ${R} 0 1 0 ${cx - R} ${cy} Z`
        } else if (phi <= 0.5) {
            const sw = phi < 0.25 ? 0 : 1   // crescent bows right (0), gibbous bows left (1)
            litPath = `M ${top} A ${R} ${rx} 0 0 1 ${bot} A ${rx} ${R} 0 0 ${sw} ${top} Z`
        } else {
            const sw = phi < 0.75 ? 0 : 1   // gibbous bows right (0), crescent bows left (1)
            litPath = `M ${top} A ${R} ${rx} 0 0 0 ${bot} A ${rx} ${R} 0 0 ${sw} ${top} Z`
        }

        // Gradient focal point: sunlight comes from the lit side
        const litSide = phi <= 0.5 ? 1 : -1
        const gx = 50 + litSide * 32
        const gy = 42

        // Nothing OS signature red accent dot at the northern lunar cusp
        let redAccentSvg = '';
        if (phi > 0.02 && phi < 0.98) {
            const tipX = cx + litSide * (R * 0.08);
            const tipY = cy - R + 2;
            redAccentSvg = `<circle cx="${tipX.toFixed(1)}" cy="${tipY.toFixed(1)}" r="3.8" fill="#ff2e2e" opacity="0.95"/>`;
        }

        return `<svg xmlns="http://www.w3.org/2000/svg" width="${s}" height="${s}" viewBox="0 0 ${s} ${s}">
<defs>
  <!-- LAYER 3: soft outer halo — moonlight atmosphere -->
  <radialGradient id="halo" cx="50%" cy="50%" r="50%">
    <stop offset="68%"  stop-color="#fff" stop-opacity="0"/>
    <stop offset="78%"  stop-color="#fff" stop-opacity="0.12"/>
    <stop offset="88%"  stop-color="#fff" stop-opacity="0.07"/>
    <stop offset="100%" stop-color="#fff" stop-opacity="0"/>
  </radialGradient>

  <!-- LAYER 1: dim globe — the full lunar sphere with earthshine -->
  <radialGradient id="globe" cx="44%" cy="38%" r="62%">
    <stop offset="0%"   stop-color="#fff" stop-opacity="0.42"/>
    <stop offset="55%"  stop-color="#fff" stop-opacity="0.30"/>
    <stop offset="85%"  stop-color="#bbb" stop-opacity="0.18"/>
    <stop offset="100%" stop-color="#888" stop-opacity="0.08"/>
  </radialGradient>

  <!-- LAYER 2: bright lit zone — the sunlit phase -->
  <radialGradient id="lit" cx="${gx}%" cy="${gy}%" r="68%">
    <stop offset="0%"   stop-color="#fff" stop-opacity="1.0"/>
    <stop offset="40%"  stop-color="#fff" stop-opacity="0.97"/>
    <stop offset="72%"  stop-color="#eee" stop-opacity="0.88"/>
    <stop offset="92%"  stop-color="#ccc" stop-opacity="0.65"/>
    <stop offset="100%" stop-color="#999" stop-opacity="0.35"/>
  </radialGradient>

  <clipPath id="disk"><circle cx="${cx}" cy="${cy}" r="${R}"/></clipPath>
</defs>

<!-- LAYER 3 · Halo (outside disk, bleeds into background dot grid) -->
<circle cx="${cx}" cy="${cy}" r="${rH}" fill="url(#halo)"/>

<!-- LAYER 1 · Full dim globe — every dot in the sphere is at least dim -->
<circle cx="${cx}" cy="${cy}" r="${R}" fill="url(#globe)"/>

<!-- Lunar maria — dark basalt seas deepen surface realism -->
<g clip-path="url(#disk)" opacity="0.22" fill="#000">
  <ellipse cx="${cx-R*.35}" cy="${cy-R*.25}" rx="${R*.28}" ry="${R*.21}" transform="rotate(-15 ${cx-R*.35} ${cy-R*.25})"/>
  <ellipse cx="${cx+R*.20}" cy="${cy-R*.12}" rx="${R*.17}" ry="${R*.14}"/>
  <ellipse cx="${cx+R*.32}" cy="${cy+R*.12}" rx="${R*.15}" ry="${R*.13}"/>
  <ellipse cx="${cx+R*.58}" cy="${cy-R*.14}" rx="${R*.09}" ry="${R*.07}"/>
  <ellipse cx="${cx-R*.20}" cy="${cy+R*.33}" rx="${R*.17}" ry="${R*.14}"/>
</g>

<!-- LAYER 2 · Bright lit zone — the sunlit phase burns bright -->
${litPath ? `<path d="${litPath}" fill="url(#lit)"/>` : ''}

<!-- Nothing Signature Red Accent Dot at lunar cusp -->
${redAccentSvg}

</svg>`
    }

    Image {
        anchors.fill: parent
        source: "data:image/svg+xml," + encodeURIComponent(root.moonSvg(root.moonPhase, root.width))
    }
}
