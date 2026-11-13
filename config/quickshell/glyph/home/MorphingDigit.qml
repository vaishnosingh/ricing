import QtQuick
import qs

// Liquid MagicUI Morphing Digit Component for High-Density LED Clock.
// Uses single-pass GPU Poisson kernel with MagicUI thresholding (metaball fusion)
// packed into red/green channels for zero nested FBO overhead and true molten character transitions.
Item {
    id: digitRoot

    property string text: "0"
    property real fontSize: 160
    property real cellWidth: 92
    property real cellHeight: 160
    property color color: Theme.fg
    property int animDuration: 480

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

    // ── Single-Pass Liquid Morph Surface (Active ONLY while animating) ───────
    Item {
        id: morphSurface
        anchors.fill: parent
        visible: digitRoot.animating

        // Outgoing Digit in Red channel
        Text {
            anchors.centerIn: parent
            text: digitRoot.prevVal
            font.family: Theme.ui
            font.pixelSize: digitRoot.fontSize
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
            color: "#ff0000"
        }

        // Incoming Digit in Green channel
        Text {
            anchors.centerIn: parent
            text: digitRoot.currentVal
            font.family: Theme.ui
            font.pixelSize: digitRoot.fontSize
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
            color: "#00ff00"
        }

        // Enable layer ONLY while animating to maintain strict zero-allocation idle efficiency
        layer.enabled: digitRoot.animating
        layer.effect: ShaderEffect {
            property real progress: digitRoot.progress
            readonly property size size: Qt.size(morphSurface.width, morphSurface.height)
            fragmentShader: Qt.resolvedUrl("shaders/morph.frag.qsb")
        }
    }

    // ── Fluid Morph Animation Curve (Silky S-Curve Deceleration) ─────────────
    NumberAnimation {
        id: morphAnim
        target: digitRoot
        property: "progress"
        from: 0.0
        to: 1.0
        duration: digitRoot.animDuration
        easing.type: Easing.InOutCubic

        onFinished: {
            digitRoot.animating = false;
            digitRoot.progress = 1.0;
        }
    }
}
