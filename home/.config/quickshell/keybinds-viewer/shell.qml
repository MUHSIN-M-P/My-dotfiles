//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QPA_PLATFORMTHEME=

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "common"

ShellRoot {
    id: shellRoot

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
        }
    }

    // Load official Noctalia Tabler Icons font
    FontLoader {
        id: tablerIconsFont
        source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/noctalia-shell/Assets/Fonts/tabler/noctalia-tabler-icons.ttf"
    }

    PanelWindow {
        id: rootWindow
        property bool showAddForm: false

        // Automatically choose the currently focused screen/monitor
        screen: {
            const monitor = Hyprland.focusedMonitor;
            if (monitor) {
                for (const s of Quickshell.screens) {
                    if (s.name === monitor.name) {
                        return s;
                    }
                }
            }
            return Quickshell.screens[0] || null;
        }

        // namespace enables automatic blur from Hyprland layers rules
        WlrLayershell.namespace: "noctalia-background-keybinds"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Backdrop overlay
        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.25)

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    Qt.quit();
                }
            }
        }

        // Main Window Frame - Noctalia Style Window
        Rectangle {
            id: mainCard
            width: 920
            height: 640
            anchors.centerIn: parent
            radius: 20
            color: Qt.rgba(Appearance.colors.colLayer0.r, Appearance.colors.colLayer0.g, Appearance.colors.colLayer0.b, 0.92)
            border.color: Appearance.colors.colOutline
            border.width: 1
            clip: true

            // Prevent clicks inside card from closing backdrop
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: false
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                // ==================== ROW 1: TITLE & CLOSE BUTTON ====================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Row {
                        spacing: 12
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 12
                            color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.16)
                            border.color: Appearance.colors.colPrimary
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                font.family: tablerIconsFont.name
                                font.pixelSize: 22
                                text: "\uebd6" // Keyboard icon
                                color: Appearance.colors.colPrimary
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: "Keybindings Cheatsheet"
                                font.family: Appearance.font.family.title
                                font.pixelSize: 22
                                font.bold: true
                                color: Appearance.colors.colOnLayer0
                            }

                            Text {
                                text: (rootWindow.flatFilteredModel ? rootWindow.flatFilteredModel.length : 0) + " shortcuts available"
                                font.family: Appearance.font.family.main
                                font.pixelSize: 12
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Close Button on Opposite Edge (Top Right Corner) - Exact Noctalia Close Icon (\ueb55)
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: closeMouseArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1
                        border.color: Appearance.colors.colOutline
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            font.family: tablerIconsFont.name
                            font.pixelSize: 16
                            text: "\ueb55" // Correct Noctalia 'x' close icon
                            color: closeMouseArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                        }

                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.quit()
                        }
                    }
                }

                // ==================== ROW 2: FULL SIZE SEARCH BAR + ADD COMMAND ====================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Full-size Pill Search Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 20
                        color: Appearance.colors.colLayer1
                        border.color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                font.family: tablerIconsFont.name
                                font.pixelSize: 16
                                text: "\ueb1c" // Search icon
                                color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                Layout.alignment: Qt.AlignVCenter
                            }

                            TextField {
                                id: searchInput
                                placeholderText: "Search keybinds, shortcuts, or commands..."
                                placeholderTextColor: Appearance.colors.colSubtext
                                font.family: Appearance.font.family.main
                                font.pixelSize: 14
                                color: Appearance.colors.colOnLayer2
                                Layout.fillWidth: true
                                background: null
                                focus: true
                                selectByMouse: true

                                onTextChanged: {
                                    rootWindow.searchText = text;
                                    rootWindow.selectFirstItem();
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Down) {
                                        rootWindow.moveSelection(1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Up) {
                                        rootWindow.moveSelection(-1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Return) {
                                        rootWindow.executeSelected();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        Qt.quit();
                                        event.accepted = true;
                                    }
                                }
                            }
                        }
                    }

                    // Add Command Pill Button (Placed directly beside Search Bar)
                    Rectangle {
                        height: 40
                        width: addBtnLayout.implicitWidth + 30
                        radius: 20
                        color: rootWindow.showAddForm ? Appearance.colors.colSecondaryContainer : (addBtnMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1)
                        border.color: Appearance.colors.colPrimary
                        border.width: 1

                        RowLayout {
                            id: addBtnLayout
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                font.family: tablerIconsFont.name
                                font.pixelSize: 14
                                text: rootWindow.showAddForm ? "\ueb55" : "\ueb0b" // 'x' or 'plus' icon
                                color: Appearance.colors.colPrimary
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: rootWindow.showAddForm ? "Cancel" : "Add Command"
                                font.family: Appearance.font.family.main
                                font.pixelSize: 13
                                font.bold: true
                                color: Appearance.colors.colPrimary
                            }
                        }

                        MouseArea {
                            id: addBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                rootWindow.showAddForm = !rootWindow.showAddForm;
                            }
                        }
                    }
                }

                // ==================== ROW 3: ADD COMMAND EXPANSION FORM ====================
                Rectangle {
                    id: addFormContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: rootWindow.showAddForm ? 115 : 0
                    visible: rootWindow.showAddForm
                    color: Appearance.colors.colLayer2
                    radius: 14
                    border.color: Appearance.colors.colPrimary
                    border.width: 1
                    clip: true

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2; Layout.fillWidth: true
                                Text { text: "Name / Description"; font.pixelSize: 10; color: Appearance.colors.colSubtext; font.family: Appearance.font.family.main }
                                Rectangle {
                                    Layout.fillWidth: true; height: 28; color: Appearance.colors.colLayer1; radius: 6; border.color: nameInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline; border.width: 1
                                    TextField { id: nameInput; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; font.pixelSize: 12; color: Appearance.colors.colOnLayer1; background: null; selectByMouse: true; placeholderText: "e.g. Restart Shell" }
                                }
                            }

                            ColumnLayout {
                                spacing: 2; Layout.fillWidth: true
                                Text { text: "Trigger Key / Label"; font.pixelSize: 10; color: Appearance.colors.colSubtext; font.family: Appearance.font.family.main }
                                Rectangle {
                                    Layout.fillWidth: true; height: 28; color: Appearance.colors.colLayer1; radius: 6; border.color: keysInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline; border.width: 1
                                    TextField { id: keysInput; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; font.pixelSize: 12; color: Appearance.colors.colOnLayer1; background: null; selectByMouse: true; placeholderText: "e.g. restart-shell" }
                                }
                            }

                            ColumnLayout {
                                spacing: 2; Layout.fillWidth: true
                                Text { text: "Terminal Command"; font.pixelSize: 10; color: Appearance.colors.colSubtext; font.family: Appearance.font.family.main }
                                Rectangle {
                                    Layout.fillWidth: true; height: 28; color: Appearance.colors.colLayer1; radius: 6; border.color: cmdInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline; border.width: 1
                                    TextField { id: cmdInput; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; font.pixelSize: 12; color: Appearance.colors.colOnLayer1; background: null; selectByMouse: true; placeholderText: "e.g. quickshell kill; ..." }
                                }
                            }
                        }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2; Layout.fillWidth: true
                                Text { text: "Detailed Explanation"; font.pixelSize: 10; color: Appearance.colors.colSubtext; font.family: Appearance.font.family.main }
                                Rectangle {
                                    Layout.fillWidth: true; height: 28; color: Appearance.colors.colLayer1; radius: 6; border.color: expInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline; border.width: 1
                                    TextField { id: expInput; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; font.pixelSize: 12; color: Appearance.colors.colOnLayer1; background: null; selectByMouse: true; placeholderText: "e.g. Restarts topbar and overview modules when frozen." }
                                }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignBottom
                                height: 28
                                width: 84
                                radius: 14
                                color: (nameInput.text && keysInput.text && cmdInput.text) ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                border.color: Appearance.colors.colPrimary
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "Save"
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: (nameInput.text && keysInput.text && cmdInput.text) ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!nameInput.text || !keysInput.text || !cmdInput.text) return;

                                        var pyCmd = "import json, os; " +
                                            "path = os.path.expanduser('~/.config/noctalia/terminal-commands.json'); " +
                                            "data = json.load(open(path)) if os.path.exists(path) else []; " +
                                            "data.append({" +
                                                "'keys': '" + keysInput.text.replace(/'/g, "\\'") + "', " +
                                                "'desc': '" + nameInput.text.replace(/'/g, "\\'") + "', " +
                                                "'explanation': '" + expInput.text.replace(/'/g, "\\'") + "', " +
                                                "'command': '" + cmdInput.text.replace(/'/g, "\\'") + "', " +
                                                "'is_cmd': True" +
                                            "}); " +
                                            "json.dump(data, open(path, 'w'), indent=2); " +
                                            "dotpath = os.path.expanduser('~/dotfiles/home/.config/noctalia/terminal-commands.json'); " +
                                            "if os.path.exists(dotpath): json.dump(data, open(dotpath, 'w'), indent=2);";

                                        Quickshell.execDetached(["python3", "-c", pyCmd]);

                                        nameInput.text = ""; keysInput.text = ""; cmdInput.text = ""; expInput.text = "";
                                        rootWindow.showAddForm = false;
                                        parserProcess.running = false; parserProcess.running = true;
                                    }
                                }
                            }
                        }
                    }
                }

                // ==================== ROW 4: SHORTCUTS LIST (CLEAN NON-OVERLAPPING SCROLLVIEW) ====================
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: listView
                        width: parent.width
                        model: rootWindow.flatFilteredModel
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: -1
                        spacing: 6

                        MouseArea {
                            anchors.fill: parent
                            propagateComposedEvents: true
                            onWheel: (wheel) => {
                                var delta = wheel.angleDelta.y;
                                var scrollAmount = (delta > 0) ? -60 : 60;
                                listView.contentY = Math.max(listView.originY, Math.min(listView.contentHeight - listView.height, listView.contentY + scrollAmount));
                                wheel.accepted = true;
                            }
                            onClicked: (m) => m.accepted = false
                        }

                        delegate: Item {
                            width: listView.width
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: listView.currentIndex === index ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.18) : (itemMouseArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)
                                border.color: listView.currentIndex === index ? Appearance.colors.colPrimary : Appearance.colors.colOutline
                                border.width: 1

                                MouseArea {
                                    id: itemMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: listView.currentIndex = index
                                    onClicked: rootWindow.executeSelected()
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    // Keys / Command Badge
                                    Row {
                                        spacing: 6
                                        Layout.preferredWidth: 260
                                        Layout.alignment: Qt.AlignVCenter

                                        // Mod + Key badges
                                        Repeater {
                                            model: !modelData.is_cmd ? modelData.keys.split(" + ") : []
                                            Rectangle {
                                                height: 25
                                                width: keyText.implicitWidth + 14
                                                color: modelData === "Super" ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                                radius: 7
                                                border.color: modelData === "Super" ? Appearance.colors.colPrimary : Appearance.colors.colOutline
                                                border.width: 1

                                                Text {
                                                    id: keyText
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    font.family: Appearance.font.family.main
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    color: modelData === "Super" ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                                }
                                            }
                                        }

                                        // Monospace badge for CLI commands
                                        Rectangle {
                                            visible: !!modelData.is_cmd
                                            height: 25
                                            width: cmdText.implicitWidth + 16
                                            color: Appearance.colors.colLayer1
                                            radius: 7
                                            border.color: Appearance.colors.colPrimary
                                            border.width: 1

                                            Text {
                                                id: cmdText
                                                anchors.centerIn: parent
                                                text: "$ " + (modelData.keys || "")
                                                font.family: Appearance.font.family.mono
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Appearance.colors.colPrimary
                                            }
                                        }
                                    }

                                    // Description Text
                                    Text {
                                        text: modelData.desc || ""
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: 15
                                        font.bold: true
                                        color: Appearance.colors.colOnLayer2
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // Quick Copy & Delete Buttons for Custom Commands
                                    Row {
                                        visible: !!modelData.is_cmd
                                        spacing: 4
                                        Layout.alignment: Qt.AlignVCenter

                                        Rectangle {
                                            width: 28; height: 28; radius: 7
                                            color: copyItemMouse.containsMouse ? Appearance.colors.colLayer1 : "transparent"
                                            Text { anchors.centerIn: parent; font.family: tablerIconsFont.name; font.pixelSize: 14; text: "\uea7a"; color: Appearance.colors.colPrimary }
                                            MouseArea {
                                                id: copyItemMouse; anchors.fill: parent; hoverEnabled: true
                                                onClicked: (m) => {
                                                    m.accepted = true;
                                                    Quickshell.execDetached(["sh", "-c", "echo -n '" + modelData.command.replace(/'/g, "'\\''") + "' | wl-copy"]);
                                                    Quickshell.execDetached(["notify-send", "-a", "Cheatsheet", "Copied to clipboard", "Command: " + modelData.command]);
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 28; height: 28; radius: 7
                                            color: delItemMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.2) : "transparent"
                                            Text { anchors.centerIn: parent; font.family: tablerIconsFont.name; font.pixelSize: 14; text: "\ueb41"; color: delItemMouse.containsMouse ? "#ff5555" : Appearance.colors.colSubtext }
                                            MouseArea {
                                                id: delItemMouse; anchors.fill: parent; hoverEnabled: true
                                                onClicked: (m) => {
                                                    m.accepted = true;
                                                    var pyDel = "import json, os; " +
                                                        "path = os.path.expanduser('~/.config/noctalia/terminal-commands.json'); " +
                                                        "if os.path.exists(path): " +
                                                        "  data = json.load(open(path)); " +
                                                        "  data = [x for x in data if not (x.get('keys') == '" + modelData.keys.replace(/'/g, "\\'") + "' and x.get('command') == '" + modelData.command.replace(/'/g, "\\'") + "')]; " +
                                                        "  json.dump(data, open(path, 'w'), indent=2); " +
                                                        "  dotpath = os.path.expanduser('~/dotfiles/home/.config/noctalia/terminal-commands.json'); " +
                                                        "  if os.path.exists(dotpath): json.dump(data, open(dotpath, 'w'), indent=2);";
                                                    Quickshell.execDetached(["python3", "-c", pyDel]);
                                                    parserProcess.running = false; parserProcess.running = true;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==================== ROW 5: BOTTOM EXPLANATION & ACTION BUTTONS ====================
                Rectangle {
                    id: explanationBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: explanationColumn.implicitHeight + 20
                    color: Appearance.colors.colLayer2
                    radius: 14
                    border.color: Appearance.colors.colOutline
                    border.width: 1

                    ColumnLayout {
                        id: explanationColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: (rootWindow.selectedItem && rootWindow.selectedItem.desc) ? rootWindow.selectedItem.desc : "Select a shortcut"
                                font.family: Appearance.font.family.main
                                font.pixelSize: 15
                                font.bold: true
                                color: Appearance.colors.colOnLayer2
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: (rootWindow.selectedItem && rootWindow.selectedItem.keys) ? rootWindow.selectedItem.keys : ""
                                font.family: Appearance.font.family.main
                                font.pixelSize: 13
                                font.bold: true
                                color: Appearance.colors.colPrimary
                            }
                        }

                        Text {
                            text: (rootWindow.selectedItem && rootWindow.selectedItem.explanation) ? rootWindow.selectedItem.explanation : "Use Up/Down arrow keys to browse keybindings. Click Execute or press Enter to run."
                            font.family: Appearance.font.family.main
                            font.pixelSize: 13
                            color: Appearance.colors.colOnLayer1
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Bottom Action Pill Buttons (Matching Noctalia Style!)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 10

                            Row {
                                spacing: 6
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    font.family: tablerIconsFont.name
                                    font.pixelSize: 13
                                    text: "\ueaad"
                                    color: Appearance.colors.colSubtext
                                }

                                Text {
                                    text: "~/.config/noctalia/terminal-commands.json"
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 11
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Execute Pill Button
                            Rectangle {
                                height: 34
                                width: execLayout.implicitWidth + 28
                                radius: 17
                                color: execMouse.containsMouse ? Qt.lighter(Appearance.colors.colPrimary, 1.1) : Appearance.colors.colPrimary

                                RowLayout {
                                    id: execLayout
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { font.family: tablerIconsFont.name; font.pixelSize: 13; text: "\uf691"; color: Appearance.colors.colOnPrimary }
                                    Text { text: "Execute"; font.family: Appearance.font.family.main; font.pixelSize: 13; font.bold: true; color: Appearance.colors.colOnPrimary }
                                }

                                MouseArea {
                                    id: execMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: rootWindow.executeSelected()
                                }
                            }

                            // Copy Command Pill Button
                            Rectangle {
                                height: 34
                                width: copyLayout.implicitWidth + 28
                                radius: 17
                                color: copyBtnMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                                border.color: Appearance.colors.colPrimary
                                border.width: 1

                                RowLayout {
                                    id: copyLayout
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { font.family: tablerIconsFont.name; font.pixelSize: 13; text: "\uea7a"; color: Appearance.colors.colPrimary }
                                    Text { text: "Copy Command"; font.family: Appearance.font.family.main; font.pixelSize: 13; font.bold: true; color: Appearance.colors.colPrimary }
                                }

                                MouseArea {
                                    id: copyBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (rootWindow.selectedItem && rootWindow.selectedItem.command) {
                                            const cmd = rootWindow.selectedItem.command.trim();
                                            Quickshell.execDetached(["sh", "-c", "echo -n '" + cmd.replace(/'/g, "'\\''") + "' | wl-copy"]);
                                            Quickshell.execDetached(["notify-send", "-a", "Cheatsheet", "Copied to clipboard", "Command: " + cmd]);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Filtering and Selection Model
        property var keybindsData: []
        property string searchText: ""
        property var flatFilteredModel: {
            const list = [];
            const term = searchText.toLowerCase().trim();

            for (const group of keybindsData) {
                for (const bind of group.binds) {
                    const keysMatch = bind.keys.toLowerCase().includes(term);
                    const descMatch = bind.desc.toLowerCase().includes(term);
                    const expMatch = bind.explanation.toLowerCase().includes(term);
                    const cmdMatch = bind.command.toLowerCase().includes(term);
                    if (!term || keysMatch || descMatch || expMatch || cmdMatch) {
                        list.push({
                            sectionName: group.section,
                            keys: bind.keys,
                            desc: bind.desc,
                            explanation: bind.explanation,
                            command: bind.command,
                            is_cmd: bind.is_cmd
                        });
                    }
                }
            }
            return list;
        }

        property var selectedItem: {
            if (listView.currentIndex >= 0 && listView.currentIndex < flatFilteredModel.length) {
                return flatFilteredModel[listView.currentIndex] || null;
            }
            return null;
        }

        function moveSelection(direction) {
            if (flatFilteredModel.length === 0) return;
            let nextIndex = listView.currentIndex + direction;
            if (nextIndex >= 0 && nextIndex < flatFilteredModel.length) {
                listView.currentIndex = nextIndex;
                listView.positionViewAtIndex(nextIndex, ListView.Contain);
            }
        }

        function selectFirstItem() {
            if (flatFilteredModel.length === 0) {
                listView.currentIndex = -1;
                return;
            }
            listView.currentIndex = 0;
            listView.positionViewAtIndex(0, ListView.Contain);
        }

        function executeSelected() {
            if (listView.currentIndex >= 0 && listView.currentIndex < flatFilteredModel.length) {
                const item = flatFilteredModel[listView.currentIndex];
                if (item && item.command) {
                    const cmd = item.command.trim();
                    if (item.is_cmd) {
                        Quickshell.execDetached(["sh", "-c", cmd]);
                    } else if (cmd.startsWith("exec ")) {
                        const shellCmd = cmd.substring(5).trim();
                        Quickshell.execDetached(["sh", "-c", shellCmd]);
                    } else {
                        Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
                    }
                    Qt.quit();
                }
            }
        }

        // Process parser
        Process {
            id: parserProcess
            command: [Quickshell.shellPath("parse_keybinds.py")]
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const parsedData = JSON.parse(this.text);
                        rootWindow.keybindsData = parsedData;
                        rootWindow.selectFirstItem();
                    } catch (e) {
                        console.log("Failed to parse keybinds JSON: " + e);
                    }
                }
            }
        }

        Component.onCompleted: {
            searchInput.forceActiveFocus();
        }
    }
}
