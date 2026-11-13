import QtQuick
import qs

// Liquid MagicUI Morphing Digit Component for High-Density LED Clock.
// Uses continuous Poisson field blending with calibrated metaball threshold
// guaranteeing 100% stroke visibility, continuous molten bridging, zero double-exposure, and zero blinking.
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

        // Outgoing Digit (fades smoothly from 1.0 to 0.0)
        Text {
            anchors.centerIn: parent
            text: digitRoot.prevVal
            font.family: Theme.ui
            font.pixelSize: digitRoot.fontSize
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
            color: "#ffffff"
            opacity: 1.0 - digitRoot.progress
        }

        // Incoming Digit (fades smoothly from 0.0 to 1.0)
        Text {
            anchors.centerIn: parent
            text: digitRoot.currentVal
            font.family: Theme.ui
            font.pixelSize: digitRoot.fontSize
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
            color: "#ffffff"
            opacity: digitRoot.progress
        }

        layer.enabled: digitRoot.animating
        layer.effect: ShaderEffect {
            property real progress: digitRoot.progress
            readonly property size size: Qt.size(morphSurface.width, morphSurface.height)
            fragmentShader: Qt.resolvedUrl("shaders/morph.frag.qsb")
        }
    }

    // ── Fluid S-Curve Morph Animation ───────────────────────────────────────
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
