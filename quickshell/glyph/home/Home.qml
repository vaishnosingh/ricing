import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Io
import qs
import qs.components
import qs.services

// "home screen" on the bottom layer, transparent: Doto clock, greeting and widget bento. Grid, orb and wallpaper -- beneath it, in Back.
// Window opened -- everything goes under it by itself. System polling and animations -- only while the workspace is empty
PanelWindow {
    id: root

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: root.inputActive ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: root.inputActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-home"

    property bool inputActive: false

    readonly property bool home: (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) === 0
    Binding { target: SysStats; property: "detailed"; value: root.home || Sys.deckOpen }
    // not in a delegate: a destroyed Binding does not return the value -- remove the widget and cava would run forever
    Binding { target: Cava; property: "active"; value: root.home && bento.model.some(w => w.id === "cava") }

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property var en: Qt.locale("en_US")

    // ── Nakshatra — Swiss Ephemeris data via FileView ──────────────────────
    // nakshatra-calc (pyswisseph) writes ~/.local/state/rice/nakshatra.json
    // on boot (systemd timer, OnBootSec=30s) and daily at 00:01.
    property var nakshatraDataObj: null

    function updateNakshatraJson(raw) {
        if (!raw || raw.length === 0) return;
        try {
            root.nakshatraDataObj = JSON.parse(raw);
        } catch(e) {
            console.warn("Failed to parse nakshatra.json:", e);
        }
    }

    FileView {
        id: nakshatraFile
        path: Quickshell.env("HOME") + "/.local/state/rice/nakshatra.json"
        blockLoading: true
        watchChanges: true
        onLoaded: root.updateNakshatraJson(text())
        onFileChanged: reload()
    }

    // ── Notes & Tasks Data ────────────────────────────────────────────────
    property string notesActiveTab: "tasks" // "tasks" or "notes"
    property var taskList: []
    property var noteList: []
    property int activeNoteIdx: 0
    property bool addingTask: false
    property string editingTaskId: ""
    property bool editingGreeting: false

    function loadTasksJson(raw) {
        if (!raw || raw.length === 0) return;
        try {
            const d = JSON.parse(raw);
            if (d.tasks && Array.isArray(d.tasks)) root.taskList = d.tasks;
            if (d.notes && Array.isArray(d.notes)) root.noteList = d.notes;
            if (d.activeTab) root.notesActiveTab = d.activeTab;
        } catch(e) {
            console.warn("Failed to parse tasks.json:", e);
        }
    }

    FileView {
        id: tasksFile
        path: Quickshell.env("HOME") + "/.local/state/rice/tasks.json"
        blockLoading: true
        watchChanges: true
        onLoaded: root.loadTasksJson(text())
        onFileChanged: reload()
    }

    function saveTasksJson() {
        const payload = JSON.stringify({
            activeTab: root.notesActiveTab,
            tasks: root.taskList,
            notes: root.noteList
        }, null, 2);
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", payload, tasksFile.path]);
    }

    function addTask(text) {
        if (!text || !text.trim()) return;
        const newTask = {
            id: "t_" + Date.now(),
            text: text.trim(),
            done: false,
            ts: Date.now()
        };
        root.taskList = [newTask].concat(root.taskList);
        root.saveTasksJson();
    }

    function toggleTask(id) {
        root.taskList = root.taskList.map(t => t.id === id ? Object.assign({}, t, { done: !t.done }) : t);
        root.saveTasksJson();
    }

    function removeTask(id) {
        root.taskList = root.taskList.filter(t => t.id !== id);
        root.saveTasksJson();
    }

    function updateTaskText(id, newText) {
        if (!newText || !newText.trim()) {
            root.removeTask(id);
            return;
        }
        root.taskList = root.taskList.map(t => t.id === id ? Object.assign({}, t, { text: newText.trim() }) : t);
        root.saveTasksJson();
    }

    function addNote() {
        const newNote = {
            id: "n_" + Date.now(),
            title: "Note " + (root.noteList.length + 1),
            body: "",
            ts: Date.now()
        };
        root.noteList = root.noteList.concat([newNote]);
        root.activeNoteIdx = root.noteList.length - 1;
        root.saveTasksJson();
    }

    function updateNote(idx, title, body) {
        if (idx < 0 || idx >= root.noteList.length) return;
        const arr = root.noteList.slice();
        arr[idx] = Object.assign({}, arr[idx], { title: title || "Untitled", body: body || "", ts: Date.now() });
        root.noteList = arr;
        root.saveTasksJson();
    }

    function removeNote(idx) {
        if (idx < 0 || idx >= root.noteList.length) return;
        root.noteList = root.noteList.filter((_, i) => i !== idx);
        if (root.activeNoteIdx >= root.noteList.length) {
            root.activeNoteIdx = Math.max(0, root.noteList.length - 1);
        }
        root.saveTasksJson();
    }

    Component.onCompleted: {
        try {
            if (nakshatraFile && typeof nakshatraFile.text === "function") {
                root.updateNakshatraJson(nakshatraFile.text());
            }
        } catch(e) {}
    }

    // ── Real-time clock-bound epoch timestamp ──────────────────────────────
    // Bound directly to SystemClock (clock.date) so that every minute when the
    // system clock advances, all dependent nakshatra, rashi, and tithi bindings
    // re-evaluate automatically in real time without needing any external trigger.
    readonly property double nowMs: clock.date ? clock.date.getTime() : Date.now()

    // Effective nakshatra index — walks the transition list in real time
    readonly property int nakshatraIdx: {
        var d = root.nakshatraDataObj;
        if (!d) return 17; // fallback to Jyeshtha
        var idx = d.idx !== undefined ? d.idx : 17;
        var now = root.nowMs;
        if (d.transitions) {
            for (var i = 0; i < d.transitions.length; i++) {
                if (now >= d.transitions[i].ts) idx = d.transitions[i].idx;
                else break;
            }
        }
        return idx;
    }
    readonly property string nakshatraEnStr: {
        var d = root.nakshatraDataObj;
        if (!d) return "Jyeshtha";
        var now = root.nowMs;
        if (d.transitions) {
            for (var i = d.transitions.length - 1; i >= 0; i--) {
                if (now >= d.transitions[i].ts) return d.transitions[i].nameEn;
            }
        }
        return d.nameEn || "Jyeshtha";
    }
    readonly property string nakshatraHiStr: {
        var d = root.nakshatraDataObj;
        if (!d) return "ज्येष्ठा";
        var now = root.nowMs;
        if (d.transitions) {
            for (var i = d.transitions.length - 1; i >= 0; i--) {
                if (now >= d.transitions[i].ts) return d.transitions[i].nameHi;
            }
        }
        return d.nameHi || "ज्येष्ठा";
    }

    // ── Rashi (Zodiac / Moon sign) properties ──────────────────────────────
    readonly property string rashiEnStr: {
        var d = root.nakshatraDataObj;
        if (!d) return "Scorpio";
        var now = root.nowMs;
        if (d.transitions) {
            for (var i = d.transitions.length - 1; i >= 0; i--) {
                if (now >= d.transitions[i].ts) return d.transitions[i].rashiEn || "Scorpio";
            }
        }
        return d.rashiEn || "Scorpio";
    }
    readonly property string rashiSaStr: {
        var d = root.nakshatraDataObj;
        if (!d) return "Vrischika";
        var now = root.nowMs;
        if (d.transitions) {
            for (var i = d.transitions.length - 1; i >= 0; i--) {
                if (now >= d.transitions[i].ts) return d.transitions[i].rashiSa || "Vrischika";
            }
        }
        return d.rashiSa || "Vrischika";
    }
    readonly property string rashiHiStr: {
        var d = root.nakshatraDataObj;
        if (!d) return "वृश्चिक";
        var now = root.nowMs;
        if (d.transitions) {
            for (var i = d.transitions.length - 1; i >= 0; i--) {
                if (now >= d.transitions[i].ts) return d.transitions[i].rashiHi || "वृश्चिक";
            }
        }
        return d.rashiHi || "वृश्चिक";
    }

    // ── Tithi (Lunar day) properties ───────────────────────────────────────
    readonly property string tithiEnStr: {
        var d = root.nakshatraDataObj;
        if (!d) return "Tritiya";
        var now = root.nowMs;
        if (d.tithiTransitions) {
            for (var i = d.tithiTransitions.length - 1; i >= 0; i--) {
                if (now >= d.tithiTransitions[i].ts) return d.tithiTransitions[i].nameEn || "Tritiya";
            }
        }
        return d.tithiName || "Tritiya";
    }
    readonly property string tithiPakshaStr: {
        var d = root.nakshatraDataObj;
        if (!d) return "shuklapaksh";
        var now = root.nowMs;
        var p = d.tithiPaksha || "Shukla";
        if (d.tithiTransitions) {
            for (var i = d.tithiTransitions.length - 1; i >= 0; i--) {
                if (now >= d.tithiTransitions[i].ts) {
                    p = d.tithiTransitions[i].paksha || p;
                    break;
                }
            }
        }
        return p.toLowerCase() === "krishna" ? "krishnapaksh" : "shuklapaksh";
    }

    // ── Pure Astrometrically Accurate Nakshatra Constellations ───────────────
    // Exact J2000 celestial tangent plane projection (North Up, East Left).
    // Real angles, real distance ratios, real star magnitudes and spectral colors.
    function nakshatraData(i) {
        var d = [
            "s:54.4,18.0,5.5,#ffffff;92.3,52.4,4.8,#ffffff;95.6,72.0,4.0,#ffffff|l:0-1;1-2", // 0  Ashwini (Hamal, Sheratan, Mesarthim)
            "s:55.4,72.0,5.0,#ffffff;67.9,18.0,4.2,#ffffff;94.6,59.9,4.2,#ffffff|l:0-1;1-2;2-0", // 1  Bharani (41, 39, 35 Arietis)
            "s:64.3,55.7,5.5,#8bc34a;126.2,54.8,4.2,#ffffff;103.6,28.3,4.2,#ffffff;91.7,72.0,4.0,#ffffff;118.3,18.0,3.8,#ffffff;24.4,61.1,4.2,#ffffff;23.8,52.3,3.5,#ffffff|l:1-4;4-2;2-0;0-5;5-6;0-3", // 2  Krittika (Pleiades cluster)
            "s:45.7,58.6,6.5,#ff453a;72.2,18.0,4.2,#ffffff;104.3,72.0,4.2,#ffffff;92.9,42.9,4.0,#ffffff;72.1,68.3,4.2,#ffffff|l:0-4;4-2;2-3;3-1", // 3  Rohini (Aldebaran + Hyades V)
            "s:93.3,18.0,5.0,#ffffff;87.0,55.3,4.0,#ffffff;56.7,72.0,4.0,#ffffff|l:0-1;0-2;1-2", // 4  Mrigashira (Meissa, Phi1, Phi2 Orionis)
            "s:75,45,7.5,#ff453a|l:", // 5  Ardra (Betelgeuse red supergiant)
            "s:91.2,18.0,5.8,#ffffff;58.8,72.0,6.2,#ff9f0a|l:0-1", // 6  Punarvasu (Castor & Pollux)
            "s:50.3,71.0,5.0,#ffffff;55.6,18.0,4.2,#ffffff;99.7,72.0,4.0,#ffffff|l:0-1;0-2", // 7  Pushya (Delta, Gamma, Theta Cancri)
            "s:124.6,30.5,4.2,#ffffff;119.8,72.0,4.0,#ffffff;100.3,71.0,4.0,#ffffff;77.5,28.2,4.0,#ffffff;25.4,26.3,4.8,#ffffff;84.8,18.0,4.5,#ffffff|l:0-1;1-2;2-3;3-4;4-5;5-0", // 8  Ashlesha (Hydra serpent head)
            "s:70.1,72.0,6.5,#70b5ff;71.0,53.6,4.2,#ffffff;59.6,41.7,5.2,#ff9f0a;62.6,28.0,4.2,#ffffff;84.2,18.0,4.0,#ffffff;90.4,26.6,4.5,#ffffff|l:0-1;1-2;2-3;3-4;4-5", // 9  Magha (Regulus & Sickle of Leo)
            "s:75.2,18.0,5.2,#ffffff;74.8,72.0,4.6,#ffffff|l:0-1", // 10 Purva Phalguni (Zosma & Chertan)
            "s:73.8,72.0,5.5,#ffffff;76.2,18.0,4.0,#ffffff|l:0-1", // 11 Uttara Phalguni (Denebola & 93 Leonis)
            "s:83.6,24.8,5.2,#ffffff;62.0,18.0,4.8,#ffffff;55.1,63.2,5.0,#ffffff;92.3,58.1,4.6,#ffffff;94.9,72.0,4.0,#ffffff|l:0-1;1-2;2-3;3-4;3-0", // 12 Hasta (Corvus the hand/crow)
            "s:75,45,7.0,#70b5ff|l:", // 13 Chitra (Spica brilliant blue-white)
            "s:75,45,7.5,#ff9f0a|l:", // 14 Swati (Arcturus golden-orange)
            "s:103.0,52.5,5.0,#ffffff;70.2,18.0,5.2,#8bc34a;47.0,46.0,4.2,#ffffff;76.2,72.0,4.0,#ffffff|l:0-1;1-2;0-3", // 15 Vishakha (Librae scale arch)
            "s:76.1,34.2,5.2,#ffffff;69.4,18.0,5.0,#ffffff;78.0,54.2,4.8,#ffffff;80.6,72.0,4.0,#ffffff|l:1-0;0-2;2-3", // 16 Anuradha (Scorpii forehead arc)
            "s:71.0,35.3,6.0,#ff453a;108.8,18.0,4.2,#ffffff;41.2,72.0,4.2,#ffffff|l:0-1;0-2", // 17 Jyeshtha (Antares + Sigma & Tau Sco: 153.6° bend, 0.88 ratio)
            "s:57.9,35.0,5.5,#ffffff;61.2,36.1,4.8,#ffffff;47.5,46.6,5.0,#ffffff;41.6,53.2,4.5,#ffffff;53.5,70.5,5.2,#ffffff;82.8,72.0,4.2,#ffffff;103.3,66.7,4.0,#ffffff;108.4,18.0,5.0,#ff9f0a|l:7-6;6-5;5-4;4-3;3-2;2-0;0-1", // 18 Mula (Scorpion stinger tail)
            "s:79.0,18.0,5.0,#ffffff;71.0,72.0,5.5,#ffffff|l:0-1", // 19 Purva Ashadha (Kaus Media & Australis)
            "s:87.2,18.0,5.5,#70b5ff;62.8,72.0,5.0,#ffffff|l:0-1", // 20 Uttara Ashadha (Nunki & Ascella)
            "s:75.0,40.4,6.5,#ffffff;89.4,18.0,4.8,#ff9f0a;60.6,72.0,4.2,#ffffff|l:1-0;0-2", // 21 Shravana (Altair, Tarazed, Alshain)
            "s:96.0,25.5,4.5,#ffffff;113.8,72.0,4.8,#ffffff;36.2,18.0,4.0,#ffffff;63.5,55.0,4.0,#ffffff|l:0-1;1-3;3-2;2-0", // 22 Dhanishtha (Delphinus diamond)
            "s:108.5,72.0,5.0,#ffffff;90.8,18.0,4.0,#ffffff;73.4,45.3,4.0,#ffffff;41.5,42.6,4.2,#ffffff|l:0-1;0-2;2-3", // 23 Shatabhisha (Sadachbia asterism)
            "s:74.5,72.0,5.2,#ffffff;75.5,18.0,5.2,#ff9f0a|l:0-1", // 24 Purva Bhadrapada (Markab & Scheat)
            "s:72.8,72.0,5.0,#ffffff;77.2,18.0,5.5,#70b5ff|l:0-1", // 25 Uttara Bhadrapada (Algenib & Alpheratz)
            "s:18.0,47.9,5.0,#ffffff;67.1,42.1,4.2,#ffffff;132.0,47.7,4.0,#ffffff|l:0-1;1-2", // 26 Revati (Zeta, Epsilon, Delta Piscium)
        ];
        return (i >= 0 && i < d.length) ? d[i] : d[17];
    }

    function nakshatraSvg(idx, W, H) {
        var raw   = nakshatraData(idx);
        var parts = raw.split("|");
        var sPart = parts[0].replace("s:", "");
        var lPart = (parts.length > 1) ? parts[1].replace("l:", "") : "";

        var stars = [];
        if (sPart) {
            var sa = sPart.split(";");
            for (var i = 0; i < sa.length; i++) {
                var c = sa[i].split(",");
                if (c.length >= 3) {
                    var col = c.length >= 4 ? c[3] : "#ffffff";
                    stars.push({ x: parseFloat(c[0]), y: parseFloat(c[1]), r: parseFloat(c[2]), col: col });
                }
            }
        }
        var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + H + '" viewBox="0 0 150 90">';
        // Lines first (subtle connecting lines)
        if (lPart) {
            var la = lPart.split(";");
            for (var j = 0; j < la.length; j++) {
                var p = la[j].split("-");
                if (p.length === 2) {
                    var a = parseInt(p[0]), b = parseInt(p[1]);
                    if (a < stars.length && b < stars.length)
                        svg += '<line x1="' + stars[a].x + '" y1="' + stars[a].y + '" x2="' + stars[b].x + '" y2="' + stars[b].y + '" stroke="#ffffff" stroke-width="0.8" opacity="0.25"/>';
                }
            }
        }
        // Crisp solid dots — NO light spill, no halo, solid opacity
        for (var k = 0; k < stars.length; k++) {
            var st = stars[k];
            svg += '<circle cx="' + st.x + '" cy="' + st.y + '" r="' + st.r + '" fill="' + st.col + '" opacity="1.0"/>';
        }
        svg += '</svg>';
        return svg;
    }

    // solid colon -- no blinking timer to preserve CPU & RAM
    property bool dim: false

    readonly property var player: Media.player
    readonly property var buds: Bluetooth.devices.values.find(d => d.connected && d.batteryAvailable) ?? null
    property var hist: [] // cpu over a minute: 34 matrix columns
    Connections {
        target: SysStats
        function onCpuChanged() { root.hist = root.hist.concat([SysStats.cpu]).slice(-34); }
    }

    function week(d) { // ISO week
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }
    readonly property string hello: { const h = clock.date.getHours(); return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"; }

    Stage {
        id: stage

        // ── LEFT COLUMN ─────────────────────────────────────────────────────
        // High-res dot-matrix clock with seconds counter and MagicUI morphing transitions
        Item {
            id: clockArea
            x: 80
            y: 140
            width: clockRow.width
            height: 160
            layer.enabled: true
            layer.effect: Dm { step: 6.5 }

            readonly property string hhStr: Theme.hh(clock.date)
            readonly property string mmStr: Qt.formatTime(clock.date, "mm")
            readonly property string ssStr: Qt.formatTime(clock.date, "ss")

            Row {
                id: clockRow
                spacing: 6

                // Hours (1 or 2 digits)
                Row {
                    spacing: 0
                    Repeater {
                        model: clockArea.hhStr.length
                        MorphingDigit {
                            text: clockArea.hhStr[index]
                            fontSize: 160
                            cellWidth: 84
                            cellHeight: 160
                        }
                    }
                }

                // Colon 1 (HH : MM) - Solid, zero blinking
                Text {
                    text: ":"
                    font.family: Theme.ui
                    font.pixelSize: 154
                    font.weight: Font.Bold
                    color: Theme.fg
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Minutes (2 digits)
                Row {
                    spacing: 0
                    MorphingDigit {
                        text: clockArea.mmStr[0]
                        fontSize: 160
                        cellWidth: 84
                        cellHeight: 160
                    }
                    MorphingDigit {
                        text: clockArea.mmStr[1]
                        fontSize: 160
                        cellWidth: 84
                        cellHeight: 160
                    }
                }

                // Colon 2 (MM : SS) - Solid, zero blinking
                Text {
                    text: ":"
                    font.family: Theme.ui
                    font.pixelSize: 154
                    font.weight: Font.Bold
                    color: Theme.fg
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Seconds (2 digits with MagicUI morphing transition)
                Row {
                    spacing: 0
                    MorphingDigit {
                        text: clockArea.ssStr[0]
                        fontSize: 160
                        cellWidth: 84
                        cellHeight: 160
                    }
                    MorphingDigit {
                        text: clockArea.ssStr[1]
                        fontSize: 160
                        cellWidth: 84
                        cellHeight: 160
                    }
                }
            }
        }
        // Date line
        Lb {
            x: 88
            y: 338
            text: `week ${root.week(clock.date)} · ${root.tithiEnStr} · ${root.tithiPakshaStr}`
            px: 13
        }
        // Greeting (High-res dotted theme with inline customization)
        Item {
            x: 86
            y: 390
            width: 480
            height: root.editingGreeting ? 130 : 100

            // Normal display (dotted theme)
            Column {
                visible: !root.editingGreeting
                spacing: 2
                layer.enabled: true
                layer.effect: Dm { step: 4 }

                Text {
                    text: `${(Theme.state.greeting && Theme.state.greeting.length > 0) ? Theme.state.greeting : root.hello},`
                    font.family: Theme.ui
                    font.pixelSize: 46
                    font.weight: Font.Bold
                    color: Theme.fg
                }
                Text {
                    text: `${Theme.state.name || Quickshell.env("USER")}.`
                    font.family: Theme.ui
                    font.pixelSize: 46
                    font.weight: Font.Bold
                    color: Theme.grey
                }
            }

            // Edit button on hover
            MouseArea {
                id: greetingMouse
                anchors.fill: parent
                hoverEnabled: true
                visible: !root.editingGreeting
                onDoubleClicked: {
                    root.editingGreeting = true;
                    root.inputActive = true;
                }
            }

            Rectangle {
                visible: greetingMouse.containsMouse && !root.editingGreeting
                x: 0
                y: -18
                width: editGreetRow.width + 12
                height: 20
                radius: 10
                color: Theme.s2
                border { width: 1; color: Theme.s3 }

                Row {
                    id: editGreetRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "✎"; font.pixelSize: 10; color: Theme.grey }
                    Text { text: "CUSTOMIZE GREETING"; font.family: Theme.mono; font.pixelSize: 9; color: Theme.grey }
                }

                TapHandler {
                    onTapped: {
                        root.editingGreeting = true;
                        root.inputActive = true;
                    }
                }
            }

            // Inline Customization Editor
            Column {
                visible: root.editingGreeting
                spacing: 8
                width: 420

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 17
                    color: Theme.s2
                    border { width: 1; color: Theme.s3 }
                    Row {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                        spacing: 8
                        Text { text: "GREETING:"; font.family: Theme.mono; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                        TextInput {
                            id: customGreetingField
                            width: parent.width - 95
                            height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            text: Theme.state.greeting ?? ""
                            font.family: Theme.ui
                            font.pixelSize: 13
                            color: Theme.fg
                            clip: true
                            focus: root.editingGreeting
                            onActiveFocusChanged: if (activeFocus) root.inputActive = true;

                            Text {
                                visible: !customGreetingField.text
                                text: `auto (${root.hello})`
                                font.family: customGreetingField.font.family
                                font.pixelSize: customGreetingField.font.pixelSize
                                color: Theme.mute
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 17
                    color: Theme.s2
                    border { width: 1; color: Theme.s3 }
                    Row {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                        spacing: 8
                        Text { text: "NAME:"; font.family: Theme.mono; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                        TextInput {
                            id: customNameField
                            width: parent.width - 75
                            height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            text: Theme.state.name ?? ""
                            font.family: Theme.ui
                            font.pixelSize: 13
                            color: Theme.fg
                            clip: true
                            onActiveFocusChanged: if (activeFocus) root.inputActive = true;

                            Text {
                                visible: !customNameField.text
                                text: Quickshell.env("USER")
                                font.family: customNameField.font.family
                                font.pixelSize: customNameField.font.pixelSize
                                color: Theme.mute
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Row {
                    spacing: 8
                    Rectangle {
                        height: 26
                        width: saveBtnRow.width + 16
                        radius: 13
                        color: Theme.red
                        Row {
                            id: saveBtnRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "✓"; font.pixelSize: 11; font.weight: Font.Bold; color: "#ffffff" }
                            Text { text: "SAVE"; font.family: Theme.mono; font.pixelSize: 10; font.weight: Font.Bold; color: "#ffffff" }
                        }
                        TapHandler {
                            onTapped: {
                                Theme.state.greeting = customGreetingField.text.trim();
                                if (customNameField.text.trim().length > 0) {
                                    Theme.state.name = customNameField.text.trim();
                                }
                                root.editingGreeting = false;
                                root.inputActive = false;
                            }
                        }
                    }

                    Rectangle {
                        height: 26
                        width: cancelBtnRow.width + 16
                        radius: 13
                        color: Theme.s2
                        border { width: 1; color: Theme.s3 }
                        Row {
                            id: cancelBtnRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "✕"; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.grey }
                            Text { text: "CANCEL"; font.family: Theme.mono; font.pixelSize: 10; color: Theme.grey }
                        }
                        TapHandler {
                            onTapped: {
                                root.editingGreeting = false;
                                root.inputActive = false;
                            }
                        }
                    }
                }
            }
        }
        // Meta info row (notifications, weather, buds)
        Row {
            x: 88
            y: 530
            spacing: 24
            Meta { icon: "\u{F009A}"; text: `${Notes.list.length} notifications` }
            Meta { visible: Weather.ok; icon: Weather.glyph(Weather.now?.code ?? 0, Weather.now?.day); text: `${Math.round(Weather.now?.temp ?? 0)}° ${Weather.name(Weather.now?.code)}` }
            Meta { visible: !!root.buds; icon: "\u{F02CB}"; text: `${root.buds?.name ?? ""} · ${Math.round((root.buds?.battery ?? 0) * 100)}%` }
        }

        // ── Pure Nakshatra Constellation above moon orb ──────────────────────
        // Stage 1920×1080. Centred horizontally at x=960. Image 150×90 at x=885, y=160.
        // Below it: English & Hindi Nakshatra name. Moon orb top at y=310.
        Image {
            x: 885; y: 160
            width: 150; height: 90
            fillMode: Image.Stretch
            source: "data:image/svg+xml," + encodeURIComponent(root.nakshatraSvg(root.nakshatraIdx, 150, 90))
        }
        Text {
            x: 760; y: 258
            width: 400
            horizontalAlignment: Text.AlignHCenter
            text: root.nakshatraEnStr
            font.family: "Space Mono"
            font.pixelSize: 15
            font.letterSpacing: 3
            color: "#ffffff"
            opacity: 0.85
        }
        Text {
            x: 760; y: 280
            width: 400
            horizontalAlignment: Text.AlignHCenter
            text: root.nakshatraHiStr
            font.pixelSize: 13
            color: "#ffffff"
            opacity: 0.60
        }

        // ── RIGHT BENTO — 2 columns × 3 rows ────────────────────────────────
        // Bento origin: x=1230, y=130, cell=220, gap=20
        // Widgets order drives layout: 2-wide widgets span both cols
        Repeater {
            id: bento
            model: {
                const out = [];
                let r = 0, c = 0;
                for (const id of Theme.state.widgets ?? []) {
                    const w = Theme.kinds[id];
                    if (!w) continue;
                    if (c + w > 2) { r++; c = 0; }   // 2-col grid (was 3)
                    if (r > 2) break;
                    out.push({ id, x: 1230 + c * 240, y: 130 + r * 240 });
                    c += w;
                }
                return out;
            }
            Loader {
                required property var modelData
                x: modelData.x
                y: modelData.y
                sourceComponent: ({ weather: weatherW, calendar: calendarW, cpu: cpuW, ram: ramW, gpu: gpuW, disk: diskW,
                                    battery: batteryW, buds: budsW, player: notesW, notes: notesW, tasks: notesW, system: systemW, cat: catW, cava: cavaW })[modelData.id] ?? null
            }
        }

        // weather
        Component {
            id: weatherW
            W {
                round: true
                Column {
                    anchors.centerIn: parent
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.glyph(Weather.now?.code ?? 3, Weather.now?.day)
                        font.pixelSize: 78
                        layer.enabled: true
                        layer.effect: Dm { step: 4 }
                    }
                    Num { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 6; text: Weather.ok ? Math.round(Weather.now.temp) + "°" : "--"; font.pixelSize: 66 }
                    Lb {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 8
                        width: Math.min(implicitWidth, 160) // chord of the circle at this height
                        elide: Text.ElideRight
                        text: Weather.ok ? `${Weather.name(Weather.now.code)} · ${Math.round(Weather.days[0]?.min)}°/${Math.round(Weather.days[0]?.max)}°` : "no sky"
                    }
                }
            }
        }

        // calendar
        Component {
            id: calendarW
            W {
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 0
                    Lb { text: root.en.monthName(clock.date.getMonth()) }
                    Num { topPadding: lead + 4; text: clock.date.getDate(); font.pixelSize: 92 }
                    Row {
                        width: parent.width
                        topPadding: 10
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text {
                                required property string modelData
                                required property int index
                                readonly property bool today: (clock.date.getDay() + 6) % 7 === index
                                width: parent.width / 7
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font { family: Theme.mono; pixelSize: 11 }
                                color: today ? Theme.fg : Theme.grey
                                Rectangle { visible: parent.today; anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter } width: 10; height: 2; color: Theme.fg }
                            }
                        }
                    }
                    Row {
                        topPadding: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Text {
                            text: (root.rashiSaStr || "vrischika").toLowerCase() + ","
                            font { family: Theme.mono; pixelSize: 11 }
                            color: Theme.grey
                        }
                        Text {
                            text: root.rashiHiStr || "वृश्चिक"
                            font { pixelSize: 11 }
                            color: Theme.grey
                        }
                    }
                }
            }
        }

        // rings: cpu, memory, gpu, disk, battery
        Component { id: cpuW; RingW { f: SysStats.cpu; value: Math.round(SysStats.cpu * 100); label: "cpu %" } }
        Component { id: ramW; RingW { f: SysStats.mem; value: Math.round(SysStats.mem * 100); label: "ram %" } }
        Component { id: gpuW; RingW { f: SysStats.gpu; value: Math.round(SysStats.gpu * 100); label: `gpu · ${Math.round(SysStats.gpuTemp)}°` } }
        Component { id: diskW; RingW { f: SysStats.disks[0]?.used ?? 0; value: Math.round((SysStats.disks[0]?.used ?? 0) * 100); label: "disk %" } }
        Component {
            id: batteryW
            RingW {
                readonly property var bat: UPower.displayDevice
                f: bat.percentage
                value: Math.round(bat.percentage * 100)
                label: bat.state === UPowerDeviceState.Charging ? "charging" : "battery"
                on: bat.state !== UPowerDeviceState.Charging && bat.percentage < 0.15 ? Theme.red : Theme.fg
            }
        }

        // Custom Notes & Tasks Bento Widget (span: 2, 460x220)
        Component {
            id: notesW
            W {
                span: 2
                clip: true

                Column {
                    anchors { fill: parent; margins: 18 }
                    spacing: 10

                    // ── Header Row: Tabs on Left, Actions on Right ────
                    Item {
                        width: parent.width
                        height: 28

                        // Tabs: TASKS & NOTES
                        Row {
                            spacing: 8
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }

                            // Tasks tab button
                            Rectangle {
                                height: 26
                                width: tasksTabRow.width + 18
                                radius: 13
                                color: root.notesActiveTab === "tasks" ? Theme.s3 : "transparent"
                                border { width: 1; color: root.notesActiveTab === "tasks" ? Theme.s3 : "transparent" }

                                Row {
                                    id: tasksTabRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Rectangle {
                                        width: 5; height: 5; radius: 2.5
                                        color: root.notesActiveTab === "tasks" ? Theme.red : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "TASKS"
                                        font { family: Theme.mono; pixelSize: 11; letterSpacing: 1.1; weight: Font.DemiBold }
                                        color: root.notesActiveTab === "tasks" ? Theme.fg : Theme.grey
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: `${root.taskList.filter(t => !t.done).length}/${root.taskList.length}`
                                        font { family: Theme.mono; pixelSize: 10 }
                                        color: root.notesActiveTab === "tasks" ? Theme.grey : Theme.mute
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                TapHandler {
                                    onTapped: {
                                        root.notesActiveTab = "tasks";
                                        root.saveTasksJson();
                                    }
                                }
                            }

                            // Notes tab button
                            Rectangle {
                                height: 26
                                width: notesTabRow.width + 18
                                radius: 13
                                color: root.notesActiveTab === "notes" ? Theme.s3 : "transparent"
                                border { width: 1; color: root.notesActiveTab === "notes" ? Theme.s3 : "transparent" }

                                Row {
                                    id: notesTabRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Rectangle {
                                        width: 5; height: 5; radius: 2.5
                                        color: root.notesActiveTab === "notes" ? Theme.red : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "NOTES"
                                        font { family: Theme.mono; pixelSize: 11; letterSpacing: 1.1; weight: Font.DemiBold }
                                        color: root.notesActiveTab === "notes" ? Theme.fg : Theme.grey
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: `${root.noteList.length}`
                                        font { family: Theme.mono; pixelSize: 10 }
                                        color: root.notesActiveTab === "notes" ? Theme.grey : Theme.mute
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                TapHandler {
                                    onTapped: {
                                        root.notesActiveTab = "notes";
                                        root.saveTasksJson();
                                    }
                                }
                            }
                        }

                        // Right actions depending on active tab
                        Item {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28
                            width: rightActionsRow.width

                            Row {
                                id: rightActionsRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                // Tasks mode action: Add task button
                                Rectangle {
                                    visible: root.notesActiveTab === "tasks"
                                    height: 26
                                    width: addTaskBtnRow.width + 16
                                    radius: 13
                                    color: root.addingTask ? Theme.s3 : Theme.s2
                                    border { width: 1; color: root.addingTask ? Theme.red : Theme.s3 }

                                    Row {
                                        id: addTaskBtnRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: root.addingTask ? "✕" : "+"
                                            font { family: Theme.mono; pixelSize: 12; weight: Font.Bold }
                                            color: root.addingTask ? Theme.red : Theme.fg
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: root.addingTask ? "CANCEL" : "ADD TASK"
                                            font { family: Theme.mono; pixelSize: 10; letterSpacing: 0.8; weight: Font.DemiBold }
                                            color: Theme.fg
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    TapHandler {
                                        onTapped: {
                                            root.addingTask = !root.addingTask;
                                            if (root.addingTask) {
                                                root.inputActive = true;
                                            } else {
                                                root.inputActive = false;
                                            }
                                        }
                                    }
                                }

                                // Clear completed tasks button
                                Rectangle {
                                    visible: root.notesActiveTab === "tasks" && root.taskList.some(t => t.done) && !root.addingTask
                                    height: 26
                                    width: clearBtnText.width + 14
                                    radius: 13
                                    color: Theme.s2
                                    border { width: 1; color: Theme.s3 }

                                    Text {
                                        id: clearBtnText
                                        anchors.centerIn: parent
                                        text: "CLEAR DONE"
                                        font { family: Theme.mono; pixelSize: 9; letterSpacing: 0.6 }
                                        color: Theme.grey
                                    }

                                    TapHandler {
                                        onTapped: {
                                            root.taskList = root.taskList.filter(t => !t.done);
                                            root.saveTasksJson();
                                        }
                                    }
                                }

                                // Notes mode actions: Page switcher + New Note
                                Row {
                                    visible: root.notesActiveTab === "notes"
                                    spacing: 6
                                    anchors.verticalCenter: parent.verticalCenter

                                    // Note pagination if > 1 note
                                    Row {
                                        visible: root.noteList.length > 1
                                        spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            width: 20; height: 20; radius: 10
                                            color: Theme.s2
                                            Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 13; color: root.activeNoteIdx > 0 ? Theme.fg : Theme.mute }
                                            TapHandler { onTapped: if (root.activeNoteIdx > 0) root.activeNoteIdx-- }
                                        }
                                        Text {
                                            text: `${root.activeNoteIdx + 1}/${root.noteList.length}`
                                            font { family: Theme.mono; pixelSize: 10 }
                                            color: Theme.grey
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Rectangle {
                                            width: 20; height: 20; radius: 10
                                            color: Theme.s2
                                            Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 13; color: root.activeNoteIdx < root.noteList.length - 1 ? Theme.fg : Theme.mute }
                                            TapHandler { onTapped: if (root.activeNoteIdx < root.noteList.length - 1) root.activeNoteIdx++ }
                                        }
                                    }

                                    // New note button
                                    Rectangle {
                                        height: 26
                                        width: newNoteBtnRow.width + 16
                                        radius: 13
                                        color: Theme.s2
                                        border { width: 1; color: Theme.s3 }

                                        Row {
                                            id: newNoteBtnRow
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "+"; font.family: Theme.mono; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: "NEW NOTE"; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 0.8; font.weight: Font.DemiBold; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                                        }

                                        TapHandler { onTapped: root.addNote() }
                                    }

                                    // Delete current note button
                                    Rectangle {
                                        visible: root.noteList.length > 0
                                        height: 26
                                        width: 26
                                        radius: 13
                                        color: Theme.s2
                                        border { width: 1; color: Theme.s3 }

                                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; color: Theme.grey }

                                        TapHandler { onTapped: root.removeNote(root.activeNoteIdx) }
                                    }
                                }
                            }
                        }
                    }

                    // Subtle separator line
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.s2
                    }

                    // ── Body: Tasks View or Notes View ───────────────
                    Item {
                        width: parent.width
                        height: parent.height - 40 // fill remaining height (~144px)

                        // ════════════════════════════════════════════════
                        // 1. TASKS VIEW
                        // ════════════════════════════════════════════════
                        Item {
                            anchors.fill: parent
                            visible: root.notesActiveTab === "tasks"

                            Column {
                                anchors.fill: parent
                                spacing: 6

                                // Inline Add Task Input
                                Rectangle {
                                    visible: root.addingTask
                                    width: parent.width
                                    height: 32
                                    radius: 16
                                    color: Theme.s2
                                    border { width: 1; color: Theme.red }

                                    Row {
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                                        spacing: 8

                                        Text {
                                            text: "+"
                                            font { family: Theme.mono; pixelSize: 14; weight: Font.Bold }
                                            color: Theme.red
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        TextInput {
                                            id: newTaskInput
                                            width: parent.width - 60
                                            height: parent.height
                                            verticalAlignment: TextInput.AlignVCenter
                                            font { family: Theme.ui; pixelSize: 12 }
                                            color: Theme.fg
                                            focus: root.addingTask
                                            clip: true

                                            Text {
                                                visible: !newTaskInput.text
                                                text: "Type task & press Enter..."
                                                font: newTaskInput.font
                                                color: Theme.grey
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            onActiveFocusChanged: {
                                                if (activeFocus) root.inputActive = true;
                                            }

                                            onAccepted: {
                                                root.addTask(text);
                                                text = "";
                                                root.addingTask = false;
                                                root.inputActive = false;
                                            }

                                            Keys.onEscapePressed: {
                                                text = "";
                                                root.addingTask = false;
                                                root.inputActive = false;
                                            }
                                        }

                                        // Confirm button
                                        Rectangle {
                                            width: 22; height: 22; radius: 11
                                            color: newTaskInput.text.trim().length > 0 ? Theme.red : Theme.s3
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✓"
                                                font { pixelSize: 11; weight: Font.Bold }
                                                color: "#ffffff"
                                            }

                                            TapHandler {
                                                onTapped: {
                                                    root.addTask(newTaskInput.text);
                                                    newTaskInput.text = "";
                                                    root.addingTask = false;
                                                    root.inputActive = false;
                                                }
                                            }
                                        }
                                    }
                                }

                                // Tasks List
                                ListView {
                                    id: taskListView
                                    width: parent.width
                                    height: root.addingTask ? parent.height - 38 : parent.height
                                    clip: true
                                    spacing: 4
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: root.taskList

                                    delegate: Rectangle {
                                        id: taskRow
                                        required property var modelData
                                        required property int index
                                        width: taskListView.width
                                        height: 30
                                        radius: 8
                                        color: rowMouse.containsMouse ? Theme.s2 : "transparent"

                                        MouseArea {
                                            id: rowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }

                                        Row {
                                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                            spacing: 8

                                            // Checkbox / Tick Circle
                                            Item {
                                                width: 20; height: parent.height
                                                anchors.verticalCenter: parent.verticalCenter

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 16; height: 16; radius: 8
                                                    color: modelData.done ? Theme.red : "transparent"
                                                    border { width: 1.5; color: modelData.done ? Theme.red : (rowMouse.containsMouse ? Theme.fg : Theme.mute) }

                                                    Text {
                                                        visible: modelData.done
                                                        anchors.centerIn: parent
                                                        text: "✓"
                                                        font { pixelSize: 10; weight: Font.Bold }
                                                        color: "#ffffff"
                                                    }
                                                }

                                                TapHandler {
                                                    onTapped: root.toggleTask(modelData.id)
                                                }
                                            }

                                            // Task Text or Edit Field
                                            Item {
                                                width: parent.width - 66
                                                height: parent.height

                                                // Regular Display Text
                                                Text {
                                                    visible: root.editingTaskId !== modelData.id
                                                    anchors { fill: parent; verticalCenter: parent.verticalCenter }
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: modelData.text
                                                    font {
                                                        family: Theme.ui
                                                        pixelSize: 12
                                                        strikeout: modelData.done
                                                    }
                                                    color: modelData.done ? Theme.mute : Theme.fg
                                                    elide: Text.ElideRight

                                                    TapHandler {
                                                        onTapped: root.toggleTask(modelData.id)
                                                        onDoubleTapped: {
                                                            root.editingTaskId = modelData.id;
                                                            root.inputActive = true;
                                                        }
                                                    }
                                                }

                                                // Inline Edit Input Field
                                                TextInput {
                                                    id: editTaskField
                                                    visible: root.editingTaskId === modelData.id
                                                    anchors { fill: parent; verticalCenter: parent.verticalCenter }
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    text: modelData.text
                                                    font { family: Theme.ui; pixelSize: 12 }
                                                    color: Theme.fg
                                                    clip: true
                                                    focus: root.editingTaskId === modelData.id

                                                    onActiveFocusChanged: {
                                                        if (activeFocus) root.inputActive = true;
                                                    }

                                                    onAccepted: {
                                                        root.updateTaskText(modelData.id, text);
                                                        root.editingTaskId = "";
                                                        root.inputActive = false;
                                                    }

                                                    Keys.onEscapePressed: {
                                                        root.editingTaskId = "";
                                                        root.inputActive = false;
                                                    }
                                                }
                                            }

                                            // Action Buttons (Edit / Delete)
                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6
                                                visible: rowMouse.containsMouse || root.editingTaskId === modelData.id

                                                // If editing: Save checkmark
                                                Rectangle {
                                                    visible: root.editingTaskId === modelData.id
                                                    width: 18; height: 18; radius: 9
                                                    color: Theme.red
                                                    Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 9; font.weight: Font.Bold; color: "#ffffff" }
                                                    TapHandler {
                                                        onTapped: {
                                                            root.updateTaskText(modelData.id, editTaskField.text);
                                                            root.editingTaskId = "";
                                                            root.inputActive = false;
                                                        }
                                                    }
                                                }

                                                // Edit pencil
                                                Rectangle {
                                                    visible: root.editingTaskId !== modelData.id
                                                    width: 18; height: 18; radius: 9
                                                    color: Theme.s3
                                                    Text { anchors.centerIn: parent; text: "✎"; font.pixelSize: 10; color: Theme.grey }
                                                    TapHandler {
                                                        onTapped: {
                                                            root.editingTaskId = modelData.id;
                                                            root.inputActive = true;
                                                        }
                                                    }
                                                }

                                                // Delete cross
                                                Rectangle {
                                                    width: 18; height: 18; radius: 9
                                                    color: Theme.s3
                                                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 9; color: Theme.grey }
                                                    TapHandler {
                                                        onTapped: {
                                                            if (root.editingTaskId === modelData.id) {
                                                                root.editingTaskId = "";
                                                                root.inputActive = false;
                                                            }
                                                            root.removeTask(modelData.id);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Empty Tasks message
                                Item {
                                    visible: root.taskList.length === 0 && !root.addingTask
                                    width: parent.width
                                    height: parent.height

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Lb { text: "NO ACTIVE TASKS"; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Tap '+ ADD TASK' above to create one"; font.family: Theme.ui; font.pixelSize: 11; color: Theme.mute; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 2. NOTES VIEW
                        // ════════════════════════════════════════════════
                        Item {
                            anchors.fill: parent
                            visible: root.notesActiveTab === "notes"

                            Column {
                                anchors.fill: parent
                                spacing: 4

                                // Empty notes state
                                Item {
                                    visible: root.noteList.length === 0
                                    width: parent.width
                                    height: parent.height

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Lb { text: "NO NOTES YET"; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: "Tap '+ NEW NOTE' above to start writing"; font.family: Theme.ui; font.pixelSize: 11; color: Theme.mute; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                }

                                // Active note editor
                                Column {
                                    visible: root.noteList.length > 0
                                    width: parent.width
                                    height: parent.height
                                    spacing: 4

                                    // Note Title
                                    Item {
                                        width: parent.width
                                        height: 22

                                        Row {
                                            anchors.fill: parent
                                            spacing: 6

                                            Text {
                                                text: "TITLE:"
                                                font { family: Theme.mono; pixelSize: 10; letterSpacing: 0.6; weight: Font.Bold }
                                                color: Theme.red
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            TextInput {
                                                id: noteTitleField
                                                width: parent.width - 60
                                                height: parent.height
                                                verticalAlignment: TextInput.AlignVCenter
                                                text: root.noteList[root.activeNoteIdx]?.title ?? ""
                                                font { family: Theme.mono; pixelSize: 12; weight: Font.DemiBold }
                                                color: Theme.fg
                                                clip: true

                                                onActiveFocusChanged: {
                                                    if (activeFocus) root.inputActive = true;
                                                    else if (!noteBodyField.activeFocus) root.inputActive = false;
                                                }

                                                onTextEdited: {
                                                    root.updateNote(root.activeNoteIdx, text, noteBodyField.text);
                                                }
                                            }
                                        }
                                    }

                                    // Note Body (Multi-line scrollable text editor)
                                    Rectangle {
                                        width: parent.width
                                        height: parent.height - 28
                                        radius: 10
                                        color: Theme.s2
                                        border { width: 1; color: noteBodyField.activeFocus ? Theme.s3 : "transparent" }

                                        Flickable {
                                            anchors { fill: parent; margins: 8 }
                                            contentWidth: width
                                            contentHeight: noteBodyField.implicitHeight
                                            clip: true
                                            boundsBehavior: Flickable.StopAtBounds

                                            TextEdit {
                                                id: noteBodyField
                                                width: parent.width
                                                text: root.noteList[root.activeNoteIdx]?.body ?? ""
                                                font { family: Theme.ui; pixelSize: 12 }
                                                color: Theme.fg
                                                wrapMode: TextEdit.Wrap
                                                selectByMouse: true

                                                Text {
                                                    visible: !noteBodyField.text
                                                    text: "Write notes, thoughts or snippets here...\n(Autosaved to disk)"
                                                    font: noteBodyField.font
                                                    color: Theme.mute
                                                    anchors.top: parent.top
                                                    anchors.left: parent.left
                                                }

                                                onActiveFocusChanged: {
                                                    if (activeFocus) root.inputActive = true;
                                                    else if (!noteTitleField.activeFocus) root.inputActive = false;
                                                }

                                                onTextChanged: {
                                                    if (activeFocus) bodySaveTimer.restart();
                                                }
                                            }
                                        }

                                        Timer {
                                            id: bodySaveTimer
                                            interval: 400
                                            repeat: false
                                            onTriggered: {
                                                root.updateNote(root.activeNoteIdx, noteTitleField.text, noteBodyField.text);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // player: cover as dots spins while playing
        Component {
            id: playerW
            W {
                span: 2
                Item {
                    id: art
                    x: 28
                    anchors.verticalCenter: parent.verticalCenter
                    width: 164
                    height: 164
                    property real turn: 0
                    Timer { running: root.home && Media.playing; interval: 33; repeat: true; onTriggered: art.turn = (art.turn + 360 / 14 / 30) % 360 }
                    Art { anchors.fill: parent; rotation: art.turn; url: root.player?.trackArtUrl ?? ""; step: 6 }
                }
                Column {
                    anchors { left: art.right; leftMargin: 26; right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                    Lb { text: `now playing · ${root.player?.identity ?? "silence"}`; width: parent.width; elide: Text.ElideRight }
                    Text {
                        width: parent.width
                        topPadding: 10
                        elide: Text.ElideRight
                        text: root.player?.trackTitle || "Nothing on"
                        font { family: Theme.ui; pixelSize: 26; weight: Font.DemiBold }
                        color: Theme.fg
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.player?.trackArtist ?? ""
                        font { family: Theme.ui; pixelSize: 15 }
                        color: Theme.grey
                    }
                    Item { width: 1; height: 18 }
                    Seg { width: parent.width; height: 6; n: 24; f: root.player?.lengthSupported && root.player.length > 0 ? Media.position / root.player.length : 0 }
                    Item { width: 1; height: 16 }
                    Controls { size: 22; play: 52 }
                }
            }
        }

        // earbuds as a ring; none -- volume
        Component {
            id: budsW
            W {
                round: true
                Ring { anchors { fill: parent; margins: 12 } f: root.buds ? root.buds.battery : Sys.vol }
                Column {
                    anchors.centerIn: parent
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: root.buds ? "\u{F02CB}" : "\u{F057E}"; font.pixelSize: 30 }
                    Num { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 8; text: Math.round((root.buds ? root.buds.battery : Sys.vol) * 100); font.pixelSize: 54 }
                    Lb {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 6
                        width: 130
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.buds?.name ?? "volume"
                    }
                }
            }
        }

        // cat: gif as a matrix in the theme tone via the wallpaper shader (like Wall in look 0). Dances only while home is visible
        Component {
            id: catW
            W {
                id: cw
                AnimatedImage { id: cat; anchors.fill: fx; opacity: 0; source: "cat.gif"; playing: root.home } // texture for fx, see Wall
                ShaderEffect {
                    id: fx
                    anchors { fill: parent; margins: 12 }
                    readonly property size size: Qt.size(width, height)
                    readonly property point origin: Qt.point(0, 0)
                    readonly property size cropA: Qt.size(1, 1)
                    readonly property size cropB: cropA
                    readonly property color lo: Theme.light ? Theme.fg : Theme.bg
                    readonly property color hi: Theme.light ? Theme.bg : Theme.fg
                    readonly property color bg: cw.color // transparent in the gif -- into the tile color
                    readonly property real pitch: 6
                    readonly property real dots: 1
                    readonly property real mono: 1
                    readonly property real bright: 1
                    readonly property real wave: 0
                    readonly property real hasA: cat.status === Image.Ready ? 1 : 0
                    readonly property real hasB: 0
                    readonly property var srcA: cat
                    readonly property var srcB: cat
                    fragmentShader: Qt.resolvedUrl("../components/shaders/wall.frag.qsb")
                }
            }
        }

        // cava as a matrix in a circle, like Glyph Matrix on the back of Nothing Phone (3): bass in the center, highs toward the edges, bars grow
        // from the middle up and down. Silence -- dimmed dots. cava runs only while home is visible
        Component {
            id: cavaW
            W {
                round: true
                Grid {
                    anchors.centerIn: parent
                    columns: 15
                    spacing: 4
                    Repeater {
                        model: 15 * 15
                        Rectangle {
                            required property int index
                            readonly property int cx: index % 15 - 7
                            readonly property int cy: Math.floor(index / 15) - 7
                            readonly property int half: Math.floor(Math.sqrt(7.5 * 7.5 - cx * cx)) // half the column height inside the circle
                            readonly property real v: Cava.bars[Math.abs(cx)] ?? 0
                            width: 8
                            height: 8
                            radius: 4
                            // outside the circle -- transparent, not visible: Grid would shift the rest
                            color: Math.abs(cy) > half ? "transparent" : Math.abs(cy) < v * (half + 1) ? Theme.fg : Theme.s3
                        }
                    }
                }
            }
        }

        // system: numbers and cpu graph as a matrix
        Component {
            id: systemW
            W {
                span: 3
                Grid {
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 22
                    Stat { label: "cpu"; value: Math.round(SysStats.cpu * 100) + "%" }
                    Stat { label: "mem"; value: SysStats.memUsed.toFixed(1) + "G" }
                    Stat { label: "gpu"; value: Math.round(SysStats.gpuTemp) + "°" }
                    Stat { label: "disk"; value: Math.round((SysStats.disks[0]?.used ?? 0) * 100) + "%" }
                }
                Column {
                    x: 344
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 34
                    spacing: 12
                    Lb { text: "cpu · 60 s" }
                    // top dot of the column white, below it grey
                    Grid {
                        id: spark
                        width: parent.width
                        columns: 34
                        spacing: 4
                        readonly property real d: (width - 33 * spacing) / 34
                        Repeater {
                            model: 34 * 8
                            Rectangle {
                                required property int index
                                readonly property int x_: index % 34
                                readonly property int up: 8 - Math.floor(index / 34) // 8 at the top ... 1 at the bottom
                                readonly property int h: Math.round(1 + 6 * (root.hist[x_ - 34 + root.hist.length] ?? 0))
                                width: spark.d
                                height: spark.d
                                radius: spark.d / 2
                                color: up === h ? Theme.fg : up < h ? Theme.grey : Theme.s2
                            }
                        }
                    }
                }
            }
        }
    }

    component W: Rectangle {
        property int span: 1
        property bool round
        width: span * 220 + (span - 1) * 20
        height: 220
        radius: round ? 110 : 40
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
    }
    // round widget: ring of dots lit by fraction f, number and label in the center
    component RingW: Rectangle {
        id: rw
        property real f
        property string value
        property string label
        property color on: Theme.fg
        width: 220
        height: 220
        radius: 110
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
        Ring { anchors { fill: parent; margins: 12 } f: rw.f; on: rw.on }
        Column {
            anchors.centerIn: parent
            Num { anchors.horizontalCenter: parent.horizontalCenter; text: rw.value; font.pixelSize: 72 }
            Lb { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 8; text: rw.label }
        }
    }
    component Meta: Row {
        property string icon
        property string text
        spacing: 10
        Icon { anchors.verticalCenter: parent.verticalCenter; text: parent.icon; font.pixelSize: 16 }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: parent.text }
    }
    component Stat: Column {
        property string label
        property string value
        width: 130
        Lb { text: parent.label }
        Num { topPadding: lead + 6; text: parent.value }
    }
}
