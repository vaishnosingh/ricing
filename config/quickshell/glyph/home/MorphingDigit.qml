import QtQuick
import qs

// Zero-allocation MagicUI Morphing Digit Component for High-Density LED Clock.
// Operates directly within parent dot-matrix FBO without nested layer effects
// or MultiEffect allocations, guaranteeing ZERO extra VRAM and minimal RAM usage.
// The dot-matrix halftone shader naturally produces fluid liquid morphing physics
// as overlapping glyph quad transforms crossfade and scale.
Item {
    id: digitRoot

    property string text: "0"
    property real fontSize: 160
    property real cellWidth: 84
    property real cellHeight: 160
    property color color: Theme.fg
    property int animDuration: 350

    width: cellWidth
    height: cellHeight

    property string currentVal: text
    property string prevVal: ""
    property bool animating: false
    property bool isReady: false

    onTextChanged: {
        if (!isReady) {
            currentVal = text;
            return;
        }
        if (text !== currentVal) {
            prevVal = currentVal;
            currentVal = text;
            animating = true;
            morphAnim.restart();
        }
    }

    Component.onCompleted: {
        currentVal = text;
        isReady = true;
    }

    // ── Outgoing Digit (Contracts and dissolves into dots) ───────────────────
    Item {
        id: prevContainer
        anchors.fill: parent
        visible: digitRoot.animating
        opacity: 0.0
        scale: 1.0
        transformOrigin: Item.Center
        transform: Translate { id: prevTrans; y: 0 }

        Text {
            anchors.centerIn: parent
            text: digitRoot.prevVal
            font.family: Theme.ui
            font.pixelSize: digitRoot.fontSize
            font.weight: Font.Bold
            color: digitRoot.color
        }
    }

    // ── Incoming Digit (Expands and crystallizes from dots) ─────────────────
    Item {
        id: currContainer
        anchors.fill: parent
        opacity: 1.0
        scale: 1.0
        transformOrigin: Item.Center
        transform: Translate { id: currTrans; y: 0 }

        Text {
            anchors.centerIn: parent
            text: digitRoot.currentVal
            font.family: Theme.ui
            font.pixelSize: digitRoot.fontSize
            font.weight: Font.Bold
            color: digitRoot.color
        }
    }

    // ── Fluid Morphing Animation (Pure SceneGraph Transforms) ───────────────
    ParallelAnimation {
        id: morphAnim
        running: false

        // Outgoing dissolution
        NumberAnimation {
            target: prevContainer
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: digitRoot.animDuration
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: prevContainer
            property: "scale"
            from: 1.0
            to: 0.88
            duration: digitRoot.animDuration
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: prevTrans
            property: "y"
            from: 0
            to: 5
            duration: digitRoot.animDuration
            easing.type: Easing.InOutQuad
        }

        // Incoming crystallization
        NumberAnimation {
            target: currContainer
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: digitRoot.animDuration
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: currContainer
            property: "scale"
            from: 1.10
            to: 1.0
            duration: digitRoot.animDuration
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: currTrans
            property: "y"
            from: -5
            to: 0
            duration: digitRoot.animDuration
            easing.type: Easing.OutQuad
        }

        onFinished: {
            digitRoot.animating = false;
            prevContainer.opacity = 0.0;
            prevContainer.scale = 1.0;
            prevTrans.y = 0;
            currContainer.opacity = 1.0;
            currContainer.scale = 1.0;
            currTrans.y = 0;
        }
    }
}
