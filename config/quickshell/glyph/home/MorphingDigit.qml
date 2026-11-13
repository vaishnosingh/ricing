import QtQuick
import qs

// Authentic Nothing OS Dot-Matrix Clock Digit Component
// Instant, crisp, zero-overhead LED matrix rendering with tabular numbers.
Item {
    id: digitRoot

    property string text: "0"
    property real fontSize: 160
    property real cellWidth: 92
    property real cellHeight: 160
    property color color: Theme.fg

    width: cellWidth
    height: cellHeight

    Text {
        anchors.centerIn: parent
        text: digitRoot.text
        font.family: Theme.ui
        font.pixelSize: digitRoot.fontSize
        font.weight: Font.Bold
        font.features: ({ "tnum": 1 })
        color: digitRoot.color
    }
}
