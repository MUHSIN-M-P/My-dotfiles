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

        // Backdrop to catch outside clicks and exit
        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    Qt.quit();
                }
            }
        }

        // Center the main cards container
        Rectangle {
            id: mainCard
            width: 860
            height: 620
            anchors.centerIn: parent
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer0
            border.color: Appearance.colors.colLayer0Border
            border.width: 1

            // Prevent clicks inside the card from closing it
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: false
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                // Top Bar with Title and Search Input
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 15

                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            text: "⌨"
                            font.pixelSize: 22
                            color: Appearance.colors.colPrimary
                        }
                        Text {
                            text: "Keybindings Cheatsheet"
                            font.family: Appearance.font.family.title
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.bold: true
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Search box
                    Rectangle {
                        width: 300
                        height: 36
                        color: Appearance.colors.colLayer1
                        border.color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline
                        border.width: 1
                        radius: Appearance.rounding.small

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "🔍"
                                font.pixelSize: 14
                                color: Appearance.colors.colSubtext
                            }

                            TextField {
                                id: searchInput
                                placeholderText: "Search binds..."
                                placeholderTextColor: Appearance.colors.colSubtext
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.normal
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
                }

                // Middle List Area
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

                        MouseArea {
                            anchors.fill: parent
                            propagateComposedEvents: true
                            onWheel: (wheel) => {
                                var delta = wheel.angleDelta.y;
                                var scrollAmount = (delta > 0) ? -60 : 60;
                                listView.contentY = Math.max(listView.originY, Math.min(listView.contentHeight - listView.height, listView.contentY + scrollAmount));
                                wheel.accepted = true;
                            }
                            onPressed: (mouse) => { mouse.accepted = false; }
                            onReleased: (mouse) => { mouse.accepted = false; }
                            onClicked: (mouse) => { mouse.accepted = false; }
                            onDoubleClicked: (mouse) => { mouse.accepted = false; }
                            onPressAndHold: (mouse) => { mouse.accepted = false; }
                        }

                        delegate: Item {
                            width: listView.width
                            height: modelData.isHeader ? 36 : 42

                            // Selection highlight
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                visible: !modelData.isHeader && listView.currentIndex === index
                                color: Appearance.colors.colLayer2Active
                                radius: Appearance.rounding.small
                                border.color: Appearance.colors.colPrimary
                                border.width: 1
                            }

                            // Hover highlight
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                visible: !modelData.isHeader && mouseArea.containsMouse && listView.currentIndex !== index
                                color: Appearance.colors.colLayer2Hover
                                radius: Appearance.rounding.small
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                enabled: !modelData.isHeader
                                hoverEnabled: true
                                onEntered: {
                                    listView.currentIndex = index;
                                }
                                onClicked: {
                                    rootWindow.executeSelected();
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 15

                                // Section Header Delegate
                                Text {
                                    visible: modelData.isHeader
                                    text: modelData.sectionName
                                    font.family: Appearance.font.family.title
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.bold: true
                                    color: Appearance.colors.colPrimary
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.topMargin: 5
                                }

                                // Keybadge keys or Terminal Command Badge
                                Row {
                                    visible: !modelData.isHeader
                                    spacing: 5
                                    Layout.preferredWidth: 260
                                    Layout.alignment: Qt.AlignVCenter

                                    // Render mod + key pills for normal keybinds
                                    Repeater {
                                        model: (!modelData.isHeader && !modelData.is_cmd) ? modelData.keys.split(" + ") : []
                                        Rectangle {
                                            height: 24
                                            width: keyText.implicitWidth + 12
                                            color: {
                                                if (modelData === "Super") return Appearance.colors.colPrimary;
                                                if (modelData === "Ctrl") return Appearance.colors.colSecondary;
                                                if (modelData === "Shift") return Appearance.colors.colSecondaryContainer;
                                                if (modelData === "Alt") return Qt.rgba(0.9, 0.4, 0.4, 0.8);
                                                return Appearance.colors.colLayer2;
                                            }
                                            radius: 4
                                            border.color: Appearance.colors.colOutline
                                            border.width: 1

                                            Text {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                font.bold: true
                                                color: {
                                                    if (modelData === "Super") return Appearance.colors.colOnPrimary;
                                                    return Appearance.colors.colOnLayer2;
                                                }
                                            }
                                        }
                                    }

                                    // Render a single monospace CLI prompt badge for terminal commands
                                    Rectangle {
                                        visible: !modelData.isHeader && !!modelData.is_cmd
                                        height: 24
                                        width: cmdText.implicitWidth + 16
                                        color: Appearance.colors.colSecondaryContainer
                                        radius: 6
                                        border.color: Appearance.colors.colSecondary
                                        border.width: 1

                                        Text {
                                            id: cmdText
                                            anchors.centerIn: parent
                                            text: "$ " + (modelData.keys || "")
                                            font.family: "monospace"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }
                                    }
                                }

                                // Short description
                                Text {
                                    visible: !modelData.isHeader
                                    text: modelData.desc || ""
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer2
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Action Buttons container (only for custom terminal commands)
                                Row {
                                    visible: !modelData.isHeader && !!modelData.is_cmd
                                    spacing: 6
                                    Layout.alignment: Qt.AlignVCenter

                                    // Copy Button
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        color: copyMouseArea.containsMouse ? Appearance.colors.colLayer1 : "transparent"
                                        radius: 6

                                        Text {
                                            anchors.centerIn: parent
                                            text: "📋"
                                            font.pixelSize: 13
                                            color: copyMouseArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                        }

                                        MouseArea {
                                            id: copyMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: (mouse) => {
                                                mouse.accepted = true; // prevent running the command
                                                Quickshell.execDetached(["sh", "-c", "echo -n '" + modelData.command.replace(/'/g, "'\\''") + "' | wl-copy"]);
                                                Quickshell.execDetached(["notify-send", "-a", "Cheatsheet", "Copied to clipboard", "Command: " + modelData.command]);
                                            }
                                        }
                                    }

                                    // Delete Button
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        color: deleteMouseArea.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.15) : "transparent"
                                        radius: 6

                                        Text {
                                            anchors.centerIn: parent
                                            text: "🗑️"
                                            font.pixelSize: 13
                                            color: deleteMouseArea.containsMouse ? "#ff5555" : Appearance.colors.colSubtext
                                        }

                                        MouseArea {
                                            id: deleteMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: (mouse) => {
                                                mouse.accepted = true; // prevent running the command
                                                
                                                var pyDel = "import json, os; " +
                                                    "path = os.path.expanduser('~/.config/noctalia/terminal-commands.json'); " +
                                                    "if os.path.exists(path): " +
                                                    "  data = json.load(open(path)); " +
                                                    "  data = [x for x in data if not (x.get('keys') == '" + modelData.keys.replace(/'/g, "\\'") + "' and x.get('command') == '" + modelData.command.replace(/'/g, "\\'") + "')]; " +
                                                    "  json.dump(data, open(path, 'w'), indent=2); " +
                                                    "  dotpath = os.path.expanduser('~/dotfiles/home/.config/noctalia/terminal-commands.json'); " +
                                                    "  if os.path.exists(dotpath): json.dump(data, open(dotpath, 'w'), indent=2);";

                                                Quickshell.execDetached(["python3", "-c", pyDel]);

                                                // Restart parser to reload the list view
                                                parserProcess.running = false;
                                                parserProcess.running = true;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

        // Bottom Explanation Panel
        Rectangle {
            Layout.fillWidth: true
            height: (rootWindow.selectedItem && rootWindow.selectedItem.is_cmd) ? 130 : 96
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            border.color: Appearance.colors.colOutline
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: (rootWindow.selectedItem && rootWindow.selectedItem.desc) ? rootWindow.selectedItem.desc : "Select an item"
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.bold: true
                        color: Appearance.colors.colOnLayer2
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (rootWindow.selectedItem && rootWindow.selectedItem.keys) ? rootWindow.selectedItem.keys : ""
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: true
                        color: Appearance.colors.colPrimary
                    }
                }

                Text {
                    text: (rootWindow.selectedItem && rootWindow.selectedItem.explanation) ? rootWindow.selectedItem.explanation : "Use Up/Down keys to navigate the list, or type above to search. Press Enter to run the selected action."
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: rootWindow.selectedItem && !!rootWindow.selectedItem.command && !!rootWindow.selectedItem.is_cmd

                    Text {
                        text: "Command (Click to copy / Enter to run):"
                        font.family: Appearance.font.family.main
                        font.pixelSize: 11
                        color: Appearance.colors.colSubtext
                    }

                    Rectangle {
                        height: 22
                        color: Appearance.colors.colLayer1
                        border.color: Appearance.colors.colOutline
                        border.width: 1
                        radius: 4
                        Layout.fillWidth: true

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            text: (rootWindow.selectedItem && rootWindow.selectedItem.command) ? rootWindow.selectedItem.command : ""
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: Appearance.colors.colPrimary
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
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

        // Bottom Bar showing file path and Add Command toggle
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2

            Text {
                text: "Save Path: ~/.config/noctalia/terminal-commands.json"
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                height: 26
                width: toggleLabel.implicitWidth + 24
                color: rootWindow.showAddForm ? Appearance.colors.colSecondaryContainer : "transparent"
                border.color: Appearance.colors.colOutline
                border.width: 1
                radius: Appearance.rounding.small

                Text {
                    id: toggleLabel
                    anchors.centerIn: parent
                    text: rootWindow.showAddForm ? "Cancel" : "Add Command"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.bold: true
                    color: rootWindow.showAddForm ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colPrimary
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: rootWindow.showAddForm = !rootWindow.showAddForm
                }
            }
        }

        // Add Custom Command Form
        Rectangle {
            id: addFormContainer
            Layout.fillWidth: true
            Layout.preferredHeight: rootWindow.showAddForm ? 100 : 0
            visible: rootWindow.showAddForm
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.small
            border.color: Appearance.colors.colOutline
            border.width: 1
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    // Name Field
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Text { text: "Name / Description"; font.pixelSize: 9; color: Appearance.colors.colSubtext; font.family: Appearance.font.family.main }
                        Rectangle {
                            Layout.fillWidth: true; height: 26; color: Appearance.colors.colLayer1; radius: 4; border.color: nameInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline; border.width: 1
                            TextField {
                                id: nameInput; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; font.pixelSize: 11; color: Appearance.colors.colOnLayer1; background: null; selectByMouse: true; placeholderText: "e.g. Restart Shell"
                            }
                        }
                    }

                    // Keys / Command trigger text Field
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Text { text: "Trigger Key / Label"; font.pixelSize: 9; color: Appearance.colors.colSubtext; font.family: Appearance.font.family.main }
                        Rectangle {
                            Layout.fillWidth: true; height: 26; color: Appearance.colors.colLayer1; radius: 4; border.color: keysInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline; border.width: 1
                            TextField {
                                id: keysInput; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; font.pixelSize: 11; color: Appearance.colors.colOnLayer1; background: null; selectByMouse: true; placeholderText: "e.g. restart-shell"
                            }
                        }
                    }

                    // Command Field
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Text { text: "Terminal Command (to copy)"; font.pixelSize: 9; color: Appearance.colors.colSubtext; font.family: Appearance.font.family.main }
                        Rectangle {
                            Layout.fillWidth: true; height: 26; color: Appearance.colors.colLayer1; radius: 4; border.color: cmdInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline; border.width: 1
                            TextField {
                                id: cmdInput; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; font.pixelSize: 11; color: Appearance.colors.colOnLayer1; background: null; selectByMouse: true; placeholderText: "e.g. quickshell kill; ..."
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    // Explanation Field
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Text { text: "Detailed Explanation"; font.pixelSize: 9; color: Appearance.colors.colSubtext; font.family: Appearance.font.family.main }
                        Rectangle {
                            Layout.fillWidth: true; height: 26; color: Appearance.colors.colLayer1; radius: 4; border.color: expInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutline; border.width: 1
                            TextField {
                                id: expInput; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; font.pixelSize: 11; color: Appearance.colors.colOnLayer1; background: null; selectByMouse: true; placeholderText: "e.g. Restarts topbar and overview modules when frozen."
                            }
                        }
                    }

                    // Save Button
                    Rectangle {
                        Layout.alignment: Qt.AlignBottom
                        height: 26
                        width: 70
                        color: (nameInput.text && keysInput.text && cmdInput.text) ? Appearance.colors.colPrimary : Appearance.colors.colLayer2Active
                        radius: Appearance.rounding.small

                        Text {
                            anchors.centerIn: parent
                            text: "Save"
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: true
                            color: (nameInput.text && keysInput.text && cmdInput.text) ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!nameInput.text || !keysInput.text || !cmdInput.text) return;

                                // Form python execution script
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

                                // Clear and close
                                nameInput.text = "";
                                keysInput.text = "";
                                cmdInput.text = "";
                                expInput.text = "";
                                rootWindow.showAddForm = false;

                                // Restart parser to reload the list view
                                parserProcess.running = false;
                                parserProcess.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}

        // Properties for filtering and navigation
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
                            isHeader: false,
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
                const item = flatFilteredModel[listView.currentIndex];
                return item || null;
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
                if (item && !item.isHeader && item.command) {
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

        // Load python parser data
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
