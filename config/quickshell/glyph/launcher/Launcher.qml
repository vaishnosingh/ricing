import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// launcher: tap Super or Super+Space. Panel centered, screen dims to 74%. Search pill with a red caret,
// modes as chips (Tab): apps / run / windows / calc.
// Icons: high-contrast monochrome Nothing glyphs and Retina app icons with tactile hover physics.
PanelWindow {
    id: root

    property int mode: 0
    property int sel: 0
    readonly property var modes: ["apps", "run", "windows", "calc"]
    readonly property string query: input.text
    property var uses: ({}) // app id -> how many times opened

    // Glyphs for known apps; key -- a lowercase piece of id/name
    readonly property var glyphs: [
        // Browsers
        ["brave", "\u{F059F}"], ["firefox", "\u{F0239}"], ["zen", "\u{F0239}"], ["chrom", "\u{F059F}"],
        ["edge", "\u{F059F}"], ["opera", "\u{F059F}"], ["vivaldi", "\u{F059F}"], ["tor", "\u{F059F}"],
        // Terminal & Shells
        ["kitty", "\u{F018D}"], ["foot", "\u{F018D}"], ["alacritty", "\u{F018D}"], ["wezterm", "\u{F018D}"],
        ["ghostty", "\u{F018D}"], ["terminal", "\u{F018D}"], ["ptyxis", "\u{F018D}"], ["console", "\u{F018D}"],
        // Development & Editors
        ["zcode", "\u{F0A1E}"], ["code", "\u{F0A1E}"], ["codium", "\u{F0A1E}"], ["android", "\u{F17B}"],
        ["studio", "\u{F17B}"], ["postman", "\u{F135}"], ["git", "\u{F02A4}"], ["docker", "\u{F0868}"],
        ["neovim", "\u{F018D}"], ["nvim", "\u{F018D}"], ["vim", "\u{F018D}"], ["emacs", "\u{F0219}"],
        ["sublime", "\u{F0A1E}"], ["intellij", "\u{F0A1E}"], ["idea", "\u{F0A1E}"], ["pycharm", "\u{F0A1E}"],
        ["clion", "\u{F0A1E}"], ["webstorm", "\u{F0A1E}"],
        // File Managers & Storage
        ["nautilus", "\u{F024B}"], ["thunar", "\u{F024B}"], ["dolphin", "\u{F024B}"], ["files", "\u{F024B}"],
        ["filezilla", "\u{F01DA}"], ["disk", "\u{F02CA}"], ["baobab", "\u{F02CA}"], ["archive", "\u{F01D8}"],
        ["fileroller", "\u{F01D8}"], ["dropbox", "\u{F01D9}"], ["nextcloud", "\u{F01D9}"],
        // System & Monitoring
        ["btop", "\u{F035B}"], ["htop", "\u{F035B}"], ["nvtop", "\u{F035B}"], ["monitor", "\u{F035B}"],
        ["settings", "\u{F0493}"], ["pavucontrol", "\u{F057E}"], ["software", "\u{F0042}"], ["package", "\u{F0042}"],
        ["bluetooth", "\u{F00AF}"], ["wifi", "\u{F05A9}"], ["clock", "\u{F00F4}"], ["calendar", "\u{F00ED}"],
        ["calculator", "\u{F00EC}"], ["weather", "\u{F0590}"], ["maps", "\u{F0279}"],
        // Communication
        ["telegram", "\u{F2C6}"], ["discord", "\u{F066F}"], ["vesktop", "\u{F066F}"], ["equibop", "\u{F066F}"],
        ["slack", "\u{F04B1}"], ["teams", "\u{F066F}"], ["zoom", "\u{F05A0}"], ["mail", "\u{F01EE}"],
        ["thunderbird", "\u{F01EE}"], ["signal", "\u{F066F}"], ["whatsapp", "\u{F066F}"], ["element", "\u{F066F}"],
        // Media & Graphics
        ["spotify", "\u{F04C7}"], ["mpv", "\u{F040A}"], ["vlc", "\u{F040A}"], ["showtime", "\u{F040A}"],
        ["decibels", "\u{F0001}"], ["music", "\u{F0001}"], ["player", "\u{F0001}"], ["rhythmbox", "\u{F0001}"],
        ["gimp", "\u{F02E9}"], ["inkscape", "\u{F05E7}"], ["blender", "\u{F062E}"], ["krita", "\u{F02E9}"],
        ["obs", "\u{F044A}"], ["camera", "\u{F0100}"], ["snapshot", "\u{F0100}"], ["loupe", "\u{F01E8}"],
        ["image", "\u{F01E8}"], ["photo", "\u{F01E8}"], ["swappy", "\u{F0490}"], ["scan", "\u{F04A7}"],
        // Office & Notes
        ["obsidian", "\u{F082E}"], ["notion", "\u{F082E}"], ["writer", "\u{F0219}"], ["calc", "\u{F00EC}"],
        ["impress", "\u{F0107}"], ["libreoffice", "\u{F0219}"], ["papers", "\u{F0219}"], ["document", "\u{F0219}"],
        ["pdf", "\u{F0219}"], ["text", "\u{F0219}"], ["editor", "\u{F0219}"], ["characters", "\u{F0500}"],
        // Virtualization & Remote
        ["boxes", "\u{F01B2}"], ["virtualbox", "\u{F01B2}"], ["qemu", "\u{F01B2}"], ["remote", "\u{F0314}"],
        ["teamviewer", "\u{F0314}"], ["anydesk", "\u{F0314}"], ["connections", "\u{F0314}"],
        // Network & Utilities
        ["clash", "\u{F0483}"], ["vpn", "\u{F0483}"], ["torrent", "\u{F01DA}"], ["transmission", "\u{F01DA}"],
        ["steam", "\u{F04D3}"], ["lutris", "\u{F04D3}"], ["heroic", "\u{F04D3}"]
    ]
    function glyph(key) { return glyphs.find(g => key.toLowerCase().includes(g[0]))?.[1] ?? ""; }

    property var apps: []
    Timer {
        id: appsT
        interval: 300
        running: true
        onTriggered: root.apps = DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
            id: e.id, name: e.name, src: e.icon ? Quickshell.iconPath(e.icon, true) : "", glyph: root.glyph(`${e.id} ${e.name}`),
            extra: `${e.id} ${e.genericName} ${(e.keywords ?? []).join(" ")}`.toLowerCase(), run: () => e.execute()
        })).sort((a, b) => a.name.localeCompare(b.name))
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { appsT.restart(); }
    }

    readonly property var wins: !visible || mode !== 2 ? [] : Hyprland.toplevels.values.map(t => {
        const cls = t.lastIpcObject?.class ?? "";
        const icon = DesktopEntries.heuristicLookup(cls)?.icon;
        return { name: t.title, src: icon ? Quickshell.iconPath(icon, true) : "", glyph: glyph(cls), extra: cls.toLowerCase(),
                 run: () => Hyprland.dispatch(`hl.dsp.focus({ window = "address:${t.address}" })`) };
    })

    function match(s, q) {
        if (!q) return { score: 1, hl: [] };
        const l = s.toLowerCase(), hl = [], at = l.indexOf(q);
        if (at >= 0) { for (let k = 0; k < q.length; k++) hl.push(at + k); return { score: (at === 0 ? 100 : 50) - at, hl }; }
        let i = 0;
        for (const c of q) {
            i = l.indexOf(c, i);
            if (i < 0) return null;
            hl.push(i++);
        }
        return { score: 10, hl };
    }
    function filter(src, q) {
        const out = [];
        for (const it of src) {
            const m = match(it.name, q);
            if (m) out.push(Object.assign({}, it, { hl: m.hl, score: m.score }));
            else if (it.extra.includes(q)) out.push(Object.assign({}, it, { hl: [], score: 1 }));
        }
        return out.sort((a, b) => b.score - a.score || (uses[b.id] ?? 0) - (uses[a.id] ?? 0));
    }

    readonly property var blocks: {
        const q = query.trim().toLowerCase();
        let b;
        if (mode === 1) b = q ? [{ head: "run", items: [{ name: query, glyph: "\u{F018D}", hl: [], run: () => Quickshell.execDetached(["sh", "-c", query]) }] }] : [];
        else if (mode === 3) b = [];
        else if (mode === 2) b = [{ head: "windows", sub: String(wins.length), items: filter(wins, q) }];
        else if (q) {
            const r = filter(apps, q);
            b = [{ head: "results", sub: String(r.length), items: r }];
        } else {
            const recent = apps.filter(a => uses[a.id]).sort((a, b) => uses[b.id] - uses[a.id]).slice(0, 6);
            b = (recent.length ? [{ head: "recent", items: recent }] : []).concat([{ head: "all apps", sub: String(apps.length), all: true, items: apps }]);
        }
        let row = 0, k = 0;
        for (const x of b) {
            x.items = x.items.map((it, i) => Object.assign({}, it, { row: row + Math.floor(i / 6), col: i % 6, k: k++ }));
            row += Math.ceil(x.items.length / 6);
        }
        return b;
    }
    readonly property var flat: blocks.reduce((a, x) => a.concat(x.items), [])
    readonly property var cur: flat[sel] ?? null

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function open() {
        input.text = "";
        mode = 0;
        sel = 0;
        flick.contentY = 0;
        shown = true;
        input.forceActiveFocus();
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function move(dr, dc) {
        if (!flat.length) return;
        if (dc) return sel = (sel + dc + flat.length) % flat.length;
        const c = cur, row = flat.filter(x => x.row === c.row + dr);
        if (row.length) sel = row.reduce((a, x) => Math.abs(x.col - c.col) < Math.abs(a.col - c.col) ? x : a).k;
    }
    function launch() {
        if (!shown) return;
        if (mode === 3) {
            if (calcOut) Quickshell.execDetached(["wl-copy", calcOut]);
            return close();
        }
        const it = cur;
        if (!it) return;
        close();
        if (it.id) {
            uses = Object.assign({}, uses, { [it.id]: (uses[it.id] ?? 0) + 1 });
            usesFile.setText(JSON.stringify(uses));
        }
        it.run();
    }

    FileView {
        id: usesFile
        path: Quickshell.statePath("launcher-uses.json")
        printErrors: false
        onLoaded: try { root.uses = JSON.parse(text()); } catch (e) {}
    }

    property string calcOut: ""
    Process { id: calc; stdout: StdioCollector { onStreamFinished: root.calcOut = text.trim() } }
    onQueryChanged: {
        sel = 0;
        if (mode === 3 && query.trim()) calc.exec(["qalc", "-t", query]);
        else calcOut = "";
    }
    onModeChanged: { sel = 0; flick.contentY = 0; if (mode === 3) queryChanged(); }
    onFlatChanged: sel = Math.max(0, Math.min(sel, flat.length - 1))
    onVisibleChanged: if (visible) input.forceActiveFocus()
    onShownChanged: if (shown) Qt.callLater(() => input.forceActiveFocus())

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-launcher"

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: 130 + 20 * (1 - root.t)
            width: 880
            height: Math.min(stage.height - 240, 30 + 68 + 20 + body.height + 36)
            opacity: root.t
            radius: 44
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            MouseArea { anchors.fill: parent }

            // Search pill with lens, red caret, clear button, and mode chips
            Rectangle {
                id: search
                x: 34
                y: 30
                width: parent.width - 68
                height: 68
                radius: 34
                color: Theme.s2
                border {
                    width: input.activeFocus ? 1.5 : 1
                    color: input.activeFocus ? Theme.mute : Theme.s3
                }
                Behavior on border.color { ColorAnimation { duration: 180 } }

                Icon {
                    id: lens
                    x: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F0349}"
                    color: input.activeFocus ? Theme.fg : Theme.grey
                    font.pixelSize: 22
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                TextInput {
                    id: input
                    focus: true
                    anchors {
                        left: lens.right
                        leftMargin: 16
                        right: clearBtn.visible ? clearBtn.left : chips.left
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    font { family: Theme.ui; pixelSize: 20; weight: Font.Medium }
                    color: Theme.fg
                    selectionColor: Theme.s3
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2.5
                        radius: 1
                        color: Theme.red
                        Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Text {
                        visible: !input.text
                        x: 2
                        text: ["Search apps, files, commands…", "Run a shell command…", "Search active windows…", "Type math: 2 + 2, 20 usd to eur…"][root.mode]
                        font: input.font
                        color: Theme.mute
                    }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Escape) root.close();
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.launch();
                        else if (e.key === Qt.Key_Tab) root.mode = (root.mode + 1) % 4;
                        else if (e.key === Qt.Key_Backtab) root.mode = (root.mode + 3) % 4;
                        else if (e.key === Qt.Key_Down) root.move(1, 0);
                        else if (e.key === Qt.Key_Up) root.move(-1, 0);
                        else if (e.key === Qt.Key_Right && (!input.text || input.cursorPosition === input.text.length) && root.flat.length) root.move(0, 1);
                        else if (e.key === Qt.Key_Left && (!input.text || input.cursorPosition === 0) && root.flat.length) root.move(0, -1);
                        else return;
                        e.accepted = true;
                    }
                }

                // Tactile Clear Button
                Rectangle {
                    id: clearBtn
                    visible: !!input.text
                    anchors { right: chips.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 28
                    height: 28
                    radius: 14
                    color: clearHov.hovered ? Theme.s3 : "transparent"
                    Icon {
                        anchors.centerIn: parent
                        text: "\u{F0156}"
                        font.pixelSize: 15
                        color: clearHov.hovered ? Theme.fg : Theme.mute
                    }
                    HoverHandler { id: clearHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            input.text = "";
                            input.forceActiveFocus();
                        }
                    }
                }

                // Interactive Mode Chips
                Row {
                    id: chips
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6

                    Repeater {
                        model: root.modes
                        Rectangle {
                            id: chipRect
                            required property string modelData
                            required property int index
                            width: chip.width + 28
                            height: chip.height + 18
                            radius: height / 2
                            color: root.mode === index ? Theme.fg : (chipHov.hovered ? Theme.s3 : "transparent")
                            scale: chipTap.pressed ? 0.93 : (chipHov.hovered ? 1.05 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Lb {
                                id: chip
                                anchors.centerIn: parent
                                text: parent.modelData
                                px: 11
                                color: root.mode === parent.index ? Theme.ink : (chipHov.hovered ? Theme.fg : Theme.grey)
                                font.weight: root.mode === parent.index ? Font.DemiBold : Font.Normal
                            }
                            HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                id: chipTap
                                onTapped: { root.mode = parent.index; input.forceActiveFocus(); }
                            }
                        }
                    }
                }
            }

            Flickable {
                id: flick
                anchors {
                    left: parent.left
                    right: parent.right
                    top: search.bottom
                    bottom: parent.bottom
                    topMargin: 20
                    leftMargin: 36
                    rightMargin: 44
                    bottomMargin: 32
                }
                contentHeight: body.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                function ensure(y, h) {
                    if (y < contentY) contentY = y;
                    else if (y + h > contentY + height) contentY = y + h - height;
                }

                Column {
                    id: body
                    width: flick.width

                    // Calculator mode output
                    Column {
                        visible: root.mode === 3
                        topPadding: 16
                        spacing: 12
                        Row {
                            spacing: 8
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: Theme.red
                            }
                            Lb { text: root.calcOut ? "RESULT · ↵ COPY TO CLIPBOARD" : "CALCULATOR · TYPE FORMULA" }
                        }
                        Num {
                            width: body.width
                            elide: Text.ElideRight
                            text: root.calcOut || "—"
                            font.pixelSize: 84
                            color: Theme.fg
                        }
                    }

                    // Run mode prompt card
                    Column {
                        visible: root.mode === 1
                        topPadding: 16
                        spacing: 14
                        Row {
                            spacing: 8
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: Theme.red
                            }
                            Lb { text: root.query ? "PRESS ENTER TO EXECUTE" : "TYPE COMMAND TO RUN" }
                        }
                        Rectangle {
                            width: body.width
                            height: 72
                            radius: 36
                            color: Theme.s2
                            border { width: 1; color: Theme.s3 }
                            Row {
                                anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                                spacing: 14
                                Text {
                                    text: "❯"
                                    font { family: Theme.mono; pixelSize: 22; weight: Font.Bold }
                                    color: Theme.red
                                }
                                Text {
                                    text: root.query || "type command..."
                                    font { family: Theme.mono; pixelSize: 18 }
                                    color: root.query ? Theme.fg : Theme.mute
                                }
                            }
                        }
                    }

                    // Blocks of apps / search results
                    Repeater {
                        id: blockRep
                        model: root.blocks.length

                        Column {
                            id: block
                            required property int index
                            readonly property var modelData: root.blocks[index] ?? ({ head: "", items: [] })
                            readonly property Item g: grid
                            width: body.width
                            topPadding: index ? 30 : 10

                            Row {
                                spacing: 10
                                bottomPadding: 18

                                Rectangle {
                                    anchors.verticalCenter: blab.verticalCenter
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.red
                                }

                                Num {
                                    visible: !!block.modelData.all
                                    anchors.baseline: blab.baseline
                                    text: root.range
                                    font.pixelSize: 32
                                    color: Theme.fg
                                }

                                Lb {
                                    id: blab
                                    text: (block.modelData.head + (block.modelData.sub ? ` · ${block.modelData.sub}` : "")).toUpperCase()
                                    color: Theme.fg
                                    font.weight: Font.DemiBold
                                }
                            }

                            Grid {
                                id: grid
                                columns: 6
                                rowSpacing: 22
                                Repeater {
                                    model: block.modelData.items.length
                                    Cell { items: block.modelData.items }
                                }
                            }
                        }
                    }
                }
            }

            // Alphabet jumping sidebar on the right
            Column {
                visible: root.mode === 0 && !root.query && !!root.allGrid
                anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 120 }
                spacing: 2

                Repeater {
                    model: [..."ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
                    Rectangle {
                        id: alphaItem
                        required property string modelData
                        width: 22
                        height: 18
                        radius: 9
                        readonly property bool active: root.range.includes(modelData)
                        color: alphaHov.hovered ? Theme.s3 : (active ? Qt.rgba(255, 255, 255, 0.08) : "transparent")
                        scale: alphaHov.hovered ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: alphaItem.modelData
                            font { family: Theme.mono; pixelSize: 10; weight: alphaItem.active ? Font.Bold : Font.Normal }
                            color: alphaItem.active ? Theme.fg : (alphaHov.hovered ? Theme.fg : Theme.mute)
                        }
                        HoverHandler { id: alphaHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.jump(alphaItem.modelData) }
                    }
                }
            }
        }
    }

    // Letters of all apps currently in view: e.g. "A–F"
    readonly property var allItems: blocks.find(b => b.all)?.items ?? []
    readonly property Item allGrid: {
        const i = blocks.findIndex(b => b.all);
        return blockRep.count > i && i >= 0 ? blockRep.itemAt(i)?.g ?? null : null;
    }
    readonly property string range: {
        if (!allGrid || !allItems.length) return "";
        const top = allGrid.mapToItem(body, 0, 0).y, rh = 88 + 12 + 20 + 22;
        const r0 = Math.max(0, Math.floor((flick.contentY - top) / rh)), r1 = Math.floor((flick.contentY + flick.height - top) / rh);
        const seen = allItems.slice(r0 * 6, (r1 + 1) * 6).map(a => a.name[0].toUpperCase());
        return seen.length ? seen[0] === seen[seen.length - 1] ? seen[0] : `${seen[0]}–${seen[seen.length - 1]}` : "";
    }
    function jump(l) {
        const i = allItems.findIndex(a => a.name[0].toUpperCase() >= l);
        if (i < 0) return;
        sel = allItems[i].k;
        flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), allGrid.mapToItem(body, 0, 0).y + Math.floor(i / 6) * (88 + 12 + 20 + 22));
    }

    // App Cell: tactile capsule with high-contrast icon and red match highlights
    component Cell: Column {
        id: cell
        required property int index
        property var items: []
        readonly property var modelData: items[index] ?? ({ name: "", hl: [] })
        readonly property bool on: root.sel === modelData.k
        width: body.width / 6
        spacing: 12
        onOnChanged: if (on) flick.ensure(mapToItem(body, 0, 0).y, height)

        Rectangle {
            id: tile
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88
            height: 88
            radius: 44
            color: cell.on ? Theme.fg : (cellHov.hovered ? Theme.s3 : Theme.s2)
            border {
                width: cell.on ? 0 : (cellHov.hovered ? 1.5 : 1)
                color: cell.on ? "transparent" : (cellHov.hovered ? Theme.fg : Theme.s3)
            }
            scale: cellTap.pressed ? 0.94 : (cellHov.hovered ? 1.06 : (cell.on ? 1.04 : 1.0))
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Subtle red dot at the top when hovered
            Rectangle {
                visible: cellHov.hovered && !cell.on
                anchors { top: parent.top; topMargin: 7; horizontalCenter: parent.horizontalCenter }
                width: 4
                height: 4
                radius: 2
                color: Theme.red
            }

            // High-contrast vector Nerd Font glyph
            Icon {
                anchors.centerIn: parent
                visible: !!cell.modelData.glyph
                text: cell.modelData.glyph ?? ""
                font.pixelSize: 36
                color: cell.on ? Theme.ink : Theme.fg
                scale: cellHov.hovered ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            // Crisp 2x app icon with Nothing monochrome styling
            Image {
                id: appImg
                anchors.centerIn: parent
                visible: !cell.modelData.glyph && status === Image.Ready
                width: 46
                height: 46
                source: cell.modelData.src ?? ""
                sourceSize: Qt.size(92, 92)
                asynchronous: true
                retainWhileLoading: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: cellHov.hovered ? 0.0 : (cell.on ? -0.2 : -0.7)
                    contrast: 0.1
                    brightness: cell.on ? (Theme.light ? 0.1 : -0.1) : 0.0
                    Behavior on saturation { NumberAnimation { duration: 200 } }
                }
            }

            TapHandler {
                id: cellTap
                onTapped: { root.sel = cell.modelData.k; root.launch(); }
            }
            HoverHandler {
                id: cellHov
                cursorShape: Qt.PointingHandCursor
            }
        }

        Text {
            width: parent.width - 8
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            readonly property var hl: cell.modelData.hl ?? []
            text: [...cell.modelData.name].map((c, i) => {
                const e = c === "<" ? "&lt;" : c === "&" ? "&amp;" : c;
                return hl.includes(i) ? `<font color="${Theme.red}"><b>${e}</b></font>` : e;
            }).join("")
            font { family: Theme.ui; pixelSize: 13; weight: cell.on ? Font.DemiBold : Font.Normal }
            color: cell.on ? Theme.fg : (cellHov.hovered ? Theme.fg : Theme.grey)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
}
