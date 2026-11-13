import QtQuick
import QtQuick.Effects
import qs

// Authentic MagicUI Morphing Digit Component for Nothing OS Dot-Matrix Clock.
// Implements true MagicUI gooey / liquid metaball text transitions in-place:
// https://magicui.design/docs/components/morphing-text
//
// Dual-layer hardware-accelerated Gaussian blur via MultiEffect combined with
// MagicUI's calibrated feColorMatrix threshold filter (255 * alpha - 140).
// Calibrated blur radius ensures glyph strokes morph in-place at their exact font size
// without letter expansion, ballooning, or block-of-dots artifacts under Dm dot matrix.
Item {
    id: digitRoot

    property string text: "0"
    property real fontSize: 160
    property real cellWidth: 92
    property real cellHeight: 160
    property color color: Theme.fg
    property int animDuration: 550

    width: cellWidth
    height: cellHeight

    property string currentVal: text
    property string prevVal: text
    property real progress: 1.0
    property bool animating: false
    property bool isReady: false

    onTextChanged: {
        if (!isReady) {
            currentVal = text;
            prevVal = text;
            return;
        }
        if (text !== currentVal) {
            prevVal = currentVal;
            currentVal = text;
            progress = 0.0;
            animating = true;
            morphAnim.restart();
        }
    }

    Component.onCompleted: {
        currentVal = text;
        prevVal = text;
        isReady = true;
    }

    // ── Resting Static Display (Zero Overhead when Idle) ───────────────────
    Text {
        anchors.centerIn: parent
        visible: !digitRoot.animating
        text: digitRoot.currentVal
        font.family: Theme.ui
        font.pixelSize: digitRoot.fontSize
        font.weight: Font.Bold
        font.features: ({ "tnum": 1 })
        color: digitRoot.color
    }

    // ── In-Place Fluid Morphing Container (Active ONLY during transition) ───
    Item {
        id: morphContainer
        anchors.fill: parent
        visible: digitRoot.animating

        // Outgoing text source
        Text {
            id: prevText
            anchors.centerIn: parent
            text: digitRoot.prevVal
            font.family: Theme.ui
            font.pixelSize: digitRoot.fontSize
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
            color: digitRoot.color
            visible: false
        }

        // Incoming text source
        Text {
            id: currText
            anchors.centerIn: parent
            text: digitRoot.currentVal
            font.family: Theme.ui
            font.pixelSize: digitRoot.fontSize
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
            color: digitRoot.color
            visible: false
        }

        readonly property real f1: Math.max(0.001, 1.0 - digitRoot.progress)
        readonly property real f2: Math.max(0.001, digitRoot.progress)

        // Outgoing digit blur and power fade (strictly in-place, no expansion)
        MultiEffect {
            anchors.fill: parent
            source: prevText
            blurEnabled: true
            blurMax: 8
            blur: Math.min(1.0, Math.max(0.0, (2.6 / morphContainer.f1 - 2.6) / 8.0))
            opacity: digitRoot.progress >= 0.98 ? 0.0 : Math.pow(morphContainer.f1, 0.4)
        }

        // Incoming digit blur and power rise (strictly in-place, no expansion)
        MultiEffect {
            anchors.fill: parent
            source: currText
            blurEnabled: true
            blurMax: 8
            blur: Math.min(1.0, Math.max(0.0, (2.6 / morphContainer.f2 - 2.6) / 8.0))
            opacity: digitRoot.progress <= 0.02 ? 0.0 : Math.pow(morphContainer.f2, 0.4)
        }

        // MagicUI SVG threshold filter on the combined blurred item
        layer.enabled: true
        layer.effect: ShaderEffect {
            property color color: digitRoot.color
            fragmentShader: Qt.resolvedUrl("shaders/morph.frag.qsb")
        }
    }

    // ── Silky S-Curve Morph Animation ───────────────────────────────────────
    NumberAnimation {
        id: morphAnim
        target: digitRoot
        property: "progress"
        from: 0.0
        to: 1.0
        duration: digitRoot.animDuration
        easing.type: Easing.InOutQuad

        onFinished: {
            digitRoot.animating = false;
            digitRoot.progress = 1.0;
        }
    }
}
