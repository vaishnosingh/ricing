import QtQuick
import Quickshell
import qs
import qs.components

// Ultra-smooth shooting stars & majestic comet effects for Glyph Rice backdrop.
// Pure SceneGraph GPU hardware-accelerated animations with zero runtime allocations.
Item {
    id: root

    anchors.fill: parent
    clip: true

    // Only run when enabled in theme (defaults to true) and when window is not hidden
    readonly property bool active: (Theme.state.stars !== false)

    // ── Helper: Random in range [min, max] ────────────────────────────────────
    function randRange(min, max) {
        return min + Math.random() * (max - min);
    }

    // ── Reusable Meteor / Comet Component ─────────────────────────────────────
    component MeteorStreak: Item {
        id: meteor

        property real startX: 0
        property real startY: 0
        property real endX: 0
        property real endY: 0
        property real travelAngle: 0
        property real tailLength: 200
        property real headWidth: 2.2
        property real maxOpacity: 0.95
        property int durationMs: 800
        property bool isComet: false
        property color coreColor: "#ffffff"
        property color glowColor: "#7dd3fc"
        property color tailColor: "#ffffff"

        x: startX
        y: startY
        opacity: 0.0
        visible: opacity > 0.005

        // Rotation around head coordinate (0, 0)
        Item {
            rotation: meteor.travelAngle
            transformOrigin: Item.TopLeft

            // ── Wide Ethereal Dust/Ion Tail (Comet mode only) ─────────────
            Rectangle {
                visible: meteor.isComet
                x: -meteor.tailLength * 1.35
                y: -meteor.headWidth * 3.5
                width: meteor.tailLength * 1.35
                height: meteor.headWidth * 7.0
                radius: height / 2
                opacity: 0.28
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.65; color: Theme.fade(meteor.glowColor, 0.15) }
                    GradientStop { position: 0.92; color: Theme.fade(meteor.glowColor, 0.45) }
                    GradientStop { position: 1.0; color: meteor.glowColor }
                }
            }

            // ── Main Tapered Gradient Tail ─────────────────────────────────
            Rectangle {
                x: -meteor.tailLength
                y: -meteor.headWidth / 2.0
                width: meteor.tailLength
                height: meteor.headWidth
                radius: meteor.headWidth / 2.0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.45; color: Theme.fade(meteor.tailColor, 0.08) }
                    GradientStop { position: 0.78; color: Theme.fade(meteor.tailColor, 0.38) }
                    GradientStop { position: 0.94; color: Theme.fade(meteor.tailColor, 0.80) }
                    GradientStop { position: 1.0; color: "#ffffff" }
                }
            }

            // ── Inner Crisp Luminous Core Streak ───────────────────────────
            Rectangle {
                x: -meteor.tailLength * 0.45
                y: -meteor.headWidth * 0.35
                width: meteor.tailLength * 0.45
                height: meteor.headWidth * 0.7
                radius: height / 2.0
                opacity: 0.85
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.6; color: Theme.fade("#ffffff", 0.3) }
                    GradientStop { position: 1.0; color: "#ffffff" }
                }
            }

            // ── Stippled Nothing OS Dot-Matrix Sparks in Wake ─────────────
            Repeater {
                model: meteor.isComet ? 7 : 4
                Rectangle {
                    property real f: (index + 1) / (meteor.isComet ? 8.0 : 5.0)
                    x: -meteor.tailLength * f - (index * 3)
                    y: (index % 2 === 0 ? 1 : -1) * (index * 0.6)
                    width: index === 0 ? (meteor.headWidth * 0.9) : (meteor.headWidth * 0.55)
                    height: width
                    radius: width / 2.0
                    color: "#ffffff"
                    opacity: Math.max(0.0, 0.75 - f * 0.7)
                }
            }

            // ── Outer Soft Halo at Nucleus ─────────────────────────────────
            Rectangle {
                x: -meteor.headWidth * 2.8
                y: -meteor.headWidth * 2.8
                width: meteor.headWidth * 5.6
                height: meteor.headWidth * 5.6
                radius: width / 2.0
                color: meteor.glowColor
                opacity: meteor.isComet ? 0.45 : 0.28
            }

            // ── Bright Star Core Pinpoint ──────────────────────────────────
            Rectangle {
                x: -meteor.headWidth * 1.1
                y: -meteor.headWidth * 1.1
                width: meteor.headWidth * 2.2
                height: meteor.headWidth * 2.2
                radius: width / 2.0
                color: meteor.coreColor
            }
        }

        // ── Flight Animation ──────────────────────────────────────────────
        ParallelAnimation {
            id: anim

            NumberAnimation {
                target: meteor
                property: "x"
                from: meteor.startX
                to: meteor.endX
                duration: meteor.durationMs
                easing.type: Easing.Linear
            }

            NumberAnimation {
                target: meteor
                property: "y"
                from: meteor.startY
                to: meteor.endY
                duration: meteor.durationMs
                easing.type: Easing.Linear
            }

            SequentialAnimation {
                // Flash ignition (fast atmospheric entry)
                NumberAnimation {
                    target: meteor
                    property: "opacity"
                    from: 0.0
                    to: meteor.maxOpacity
                    duration: meteor.durationMs * 0.16
                    easing.type: Easing.InQuad
                }
                // Sustained flight
                PauseAnimation {
                    duration: meteor.durationMs * 0.52
                }
                // Burnout extinction into darkness
                NumberAnimation {
                    target: meteor
                    property: "opacity"
                    from: meteor.maxOpacity
                    to: 0.0
                    duration: meteor.durationMs * 0.32
                    easing.type: Easing.OutQuad
                }
            }

            onFinished: {
                meteor.opacity = 0.0;
            }
        }

        function fire(sX, sY, eX, eY, len, w, dur, comet, op, core, glow) {
            anim.stop();
            meteor.startX = sX;
            meteor.startY = sY;
            meteor.endX = eX;
            meteor.endY = eY;
            meteor.tailLength = len;
            meteor.headWidth = w;
            meteor.durationMs = dur;
            meteor.isComet = comet;
            meteor.maxOpacity = op || 0.95;
            meteor.coreColor = core || "#ffffff";
            meteor.glowColor = glow || (comet ? "#7dd3fc" : "#e0f2fe");
            meteor.tailColor = core || "#ffffff";

            // Direction angle in degrees
            const dx = eX - sX;
            const dy = eY - sY;
            meteor.travelAngle = Math.atan2(dy, dx) * 180.0 / Math.PI;

            meteor.x = sX;
            meteor.y = sY;
            meteor.opacity = 0.0;
            anim.restart();
        }

        readonly property bool isFlying: anim.running
    }

    // ── Three Dedicated Meteor Channels ───────────────────────────────────────
    // Channel 1: Agile, rapid shooting stars (every 4-8s)
    MeteorStreak { id: streak1 }

    // Channel 2: Counter-angle / cross-sky meteors (every 7-13s)
    MeteorStreak { id: streak2 }

    // Channel 3: Grand Luminous Comet with long glowing tail (every 18-28s)
    MeteorStreak { id: cometStreak }

    // ── Trajectory Generation Logic ───────────────────────────────────────────
    function launchMeteor(item, isGrandComet) {
        if (!root.active) return;
        if (item.isFlying) return;

        const W = root.width > 100 ? root.width : 1920;
        const H = root.height > 100 ? root.height : 1080;

        let sX, sY, eX, eY, len, w, dur, op, coreCol, glowCol;

        if (isGrandComet) {
            // ── Grand Comet: Long sweeping celestial flight ──
            const mode = Math.random();
            if (mode < 0.60) {
                // High celestial sweep across upper half of screen
                sX = randRange(W * 0.05, W * 0.35);
                sY = randRange(H * 0.02, H * 0.25);
                const angleRad = randRange(22, 38) * Math.PI / 180.0;
                const dist = randRange(1000, 1400);
                eX = sX + Math.cos(angleRad) * dist;
                eY = sY + Math.sin(angleRad) * dist;
            } else {
                // Reverse angle from North-East across towards South-West
                sX = randRange(W * 0.70, W * 0.95);
                sY = randRange(H * 0.02, H * 0.25);
                const angleRad = randRange(142, 158) * Math.PI / 180.0;
                const dist = randRange(1000, 1400);
                eX = sX + Math.cos(angleRad) * dist;
                eY = sY + Math.sin(angleRad) * dist;
            }

            len = randRange(360, 480);
            w = randRange(3.2, 4.2);
            dur = randRange(2200, 3100);
            op = 0.96;

            // Comet tint: ethereal aquamarine / ice cyan, or golden amber
            const tintPick = Math.random();
            if (tintPick < 0.70) {
                glowCol = "#38bdf8"; // cyan starlight
                coreCol = "#f0f9ff";
            } else {
                glowCol = "#fbbf24"; // golden comet flare
                coreCol = "#fffbeb";
            }

            item.fire(sX, sY, eX, eY, len, w, dur, true, op, coreCol, glowCol);
            return;
        }

        // ── Normal Shooting Stars: Diverse angles ("here and there") ──
        const type = Math.floor(Math.random() * 4);

        if (type === 0) {
            // Northwest radiant: classic diagonal (down-right)
            sX = randRange(W * 0.05, W * 0.65);
            sY = randRange(-30, H * 0.30);
            const angleRad = randRange(32, 48) * Math.PI / 180.0;
            const dist = randRange(650, 1050);
            eX = sX + Math.cos(angleRad) * dist;
            eY = sY + Math.sin(angleRad) * dist;
        } else if (type === 1) {
            // Northeast radiant: opposing diagonal (down-left)
            sX = randRange(W * 0.45, W * 0.95);
            sY = randRange(-30, H * 0.30);
            const angleRad = randRange(132, 148) * Math.PI / 180.0;
            const dist = randRange(650, 1050);
            eX = sX + Math.cos(angleRad) * dist;
            eY = sY + Math.sin(angleRad) * dist;
        } else if (type === 2) {
            // High altitude glider: shallow angle across the top
            sX = randRange(-40, W * 0.25);
            sY = randRange(H * 0.05, H * 0.28);
            const angleRad = randRange(12, 22) * Math.PI / 180.0;
            const dist = randRange(900, 1350);
            eX = sX + Math.cos(angleRad) * dist;
            eY = sY + Math.sin(angleRad) * dist;
        } else {
            // Steep plunge / Earth grazer
            sX = randRange(W * 0.25, W * 0.75);
            sY = randRange(-40, H * 0.15);
            const angleRad = randRange(60, 75) * Math.PI / 180.0;
            const dist = randRange(550, 850);
            eX = sX + Math.cos(angleRad) * dist;
            eY = sY + Math.sin(angleRad) * dist;
        }

        len = randRange(160, 260);
        w = randRange(1.8, 2.5);
        dur = randRange(650, 1050);
        op = randRange(0.85, 0.98);

        // 1 in 10 meteors has a subtle red-hot Nothing OS accent glow!
        if (Math.random() < 0.12) {
            coreCol = "#ffffff";
            glowCol = Theme.red; // Nothing red starlight spark
        } else {
            coreCol = "#ffffff";
            glowCol = "#bae6fd";
        }

        item.fire(sX, sY, eX, eY, len, w, dur, false, op, coreCol, glowCol);
    }

    // ── Independent Spawn Timers ──────────────────────────────────────────────
    // Channel 1: Primary shooting stars (4-7 seconds interval)
    Timer {
        id: timer1
        interval: 3500
        running: root.active
        repeat: true
        onTriggered: {
            interval = Math.floor(randRange(4000, 7500));
            root.launchMeteor(streak1, false);
        }
    }

    // Channel 2: Secondary / cross-radiant shooting stars (6-11 seconds interval)
    Timer {
        id: timer2
        interval: 6000
        running: root.active
        repeat: true
        onTriggered: {
            interval = Math.floor(randRange(6500, 11500));
            root.launchMeteor(streak2, false);
        }
    }

    // Channel 3: Grand Comet (16-26 seconds interval)
    Timer {
        id: timer3
        interval: 12000
        running: root.active
        repeat: true
        onTriggered: {
            interval = Math.floor(randRange(16000, 26000));
            root.launchMeteor(cometStreak, true);
        }
    }

    // Initial launch shortly after desktop loads
    Component.onCompleted: {
        timer1.restart();
        timer2.restart();
        timer3.restart();
        Qt.callLater(function() {
            root.launchMeteor(streak1, false);
        });
    }
}
