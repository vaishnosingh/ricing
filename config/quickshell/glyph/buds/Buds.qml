import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// Nothing / CMF earbuds connected (Sys.buds) -- a card at the bottom, like AirPods: slides in with a spring, the device glows as a
// Glyph dot silhouette and fades into the photo, charge rings light up in a wave.
// Click anywhere on the screen, click the card, or press Esc to dismiss immediately. Auto-dismisses in 2.8s.
PanelWindow {
    id: root

    property string name
    readonly property string art: Quickshell.shellPath("buds/" + name.toLowerCase().replace(/[^a-z0-9]+/g, "-") + ".png")

    // show timeline: t -- card, lit -- dot silhouette, pop -- device settles into place, res -- dots -> photo
    property real t: 0
    property real lit: 0
    property real pop: 0
    property real res: 0
    property bool shown: false

    // Debounce: do not re-show popup within 20s for the same device to prevent reconnect thrashing
    property string lastAddress: ""
    property real lastTime: 0

    // at shell startup the earbuds are already connected -- do not show
    property bool armed: false
    Timer { running: true; interval: 3000; onTriggered: root.armed = true }
    Connections {
        target: Sys
        function onBudsChanged() {
            if (Sys.buds && root.armed) root.show();
        }
    }

    function show() {
        if (!Sys.buds) return;
        const now = Date.now();
        if (Sys.buds.address === lastAddress && (now - lastTime) < 20000) {
            return; // Debounce reconnect loop
        }
        lastAddress = Sys.buds.address;
        lastTime = now;
        name = Sys.buds.name;
        outA.stop();
        t = lit = pop = res = 0;
        shown = true;
        inA.restart();
    }

    function showTest(testName) {
        name = testName || "CMF Buds 2 Plus";
        outA.stop();
        t = lit = pop = res = 0;
        shown = true;
        inA.restart();
    }

    function hide() {
        if (!shown && t === 0) return;
        shown = false;
        inA.stop();
        outA.restart();
    }

    ParallelAnimation {
        id: inA
        NumberAnimation { target: root; property: "t"; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1 }
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            ParallelAnimation {
                NumberAnimation { target: root; property: "lit"; to: 1; duration: 250 }
                NumberAnimation { target: root; property: "pop"; to: 1; duration: 500; easing.type: Easing.OutBack }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: root; property: "res"; to: 1; duration: 450; easing.type: Easing.InOutSine }
        }
    }
    NumberAnimation { id: outA; target: root; property: "t"; to: 0; duration: 260; easing.type: Easing.InCubic }

    // Auto-dismisses in 2.8s so it never lingers or blocks the user
    Timer { interval: 2800; running: root.shown; onTriggered: root.hide() }

    // slight sway while visible
    property real bob: 0
    SequentialAnimation on bob {
        running: root.visible
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 1600; easing.type: Easing.InOutSine }
    }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "glyph-buds"

    // Click anywhere on the screen outside or around the card to dismiss immediately
    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    // Escape key dismisses immediately
    Item {
        focus: root.visible
        Keys.onEscapePressed: root.hide()
    }

    Stage {
        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            // window position: rests 14px above screen bottom at t=1, slides off-screen at t=0
            y: parent.height - 470 + (1 - root.t) * 500
            width: 420
            height: 456
            radius: 44
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            opacity: Math.min(1, root.t * 1.5)

            // Clicking on the card itself also dismisses
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.hide()
            }

            // Close button in top-right corner
            Rectangle {
                anchors { top: parent.top; topMargin: 18; right: parent.right; rightMargin: 18 }
                width: 32
                height: 32
                radius: 16
                color: closeHov.hovered ? Theme.s3 : "transparent"
                Icon {
                    anchors.centerIn: parent
                    text: "\u{F0156}" // mdi-close
                    font.pixelSize: 18
                    color: Theme.mute
                }
                HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
            }

            Lb { anchors.horizontalCenter: parent.horizontalCenter; y: 28; text: "connected"; px: 11 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 46
                text: root.name
                font { family: Theme.ui; pixelSize: 22; weight: Font.DemiBold }
                color: Theme.fg
            }

            Item {
                id: hero
                y: 84
                width: parent.width
                height: 230

                Orb { anchors.centerIn: parent; width: 200; height: 200; step: 6 }

                Item {
                    id: dev
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -6 * root.bob
                    width: 190
                    height: 220
                    scale: 0.7 + 0.3 * root.pop
                    rotation: -10 * (1 - root.pop)

                    // silhouette: white LED dots (black in the light theme), fade out while the photo appears
                    Item {
                        anchors.fill: parent
                        visible: photo.status === Image.Ready && opacity > 0
                        opacity: root.lit * (1 - root.res)
                        layer.enabled: visible
                        layer.effect: Dm { step: 6 }
                        Image {
                            anchors.fill: parent
                            source: photo.source
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            layer.enabled: true
                            layer.effect: MultiEffect { brightness: Theme.light ? -1 : 1 }
                        }
                    }
                    Image {
                        id: photo
                        anchors.fill: parent
                        source: root.name ? root.art : ""
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        opacity: root.res
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: photo.status === Image.Error
                        text: "\u{F02CB}"
                        font.pixelSize: 120
                        opacity: root.lit
                    }
                }
            }

            // charge: left, right, case (case -- only when the earbuds are in it). Until ear replies -- empty
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 330
                spacing: 34
                Repeater {
                    model: ["l", "r", "case"].filter(k => Sys.ear?.[k] !== undefined)
                    Column {
                        id: bat
                        required property string modelData
                        readonly property real v: Sys.ear?.[modelData] ?? 0
                        property real k: 0
                        NumberAnimation on k { from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
                        spacing: 8
                        Item {
                            width: 84
                            height: 84
                            Ring { anchors.fill: parent; n: 32; dot: 5; f: bat.v / 100 * bat.k }
                            Num { anchors.centerIn: parent; text: Math.round(bat.v * bat.k); font.pixelSize: 30 }
                        }
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: bat.modelData; px: 11 }
                    }
                }
            }
        }
    }
}
