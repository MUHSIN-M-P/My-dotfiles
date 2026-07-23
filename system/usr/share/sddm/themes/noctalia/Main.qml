import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0

Item {
    id: root
    width: Screen.width; height: Screen.height

    // ── High-DPI Resolution-Aware Generous Scaling Ratio ──
    readonly property real scaleRatio: {
        var ratio = Screen.width / 1920.0;
        // Increase the baseline scale to 1.35 so elements are beautifully large and prominent on all screens
        return Math.max(1.35, Math.min(ratio * 1.35, 3.5));
    }

    // ── Font Loaders (embedded inside theme folder to guarantee rendering) ──
    FontLoader {
        id: tablerFont
        source: "fonts/noctalia-tabler-icons.ttf"
    }

    FontLoader {
        id: montserratFont
        source: "fonts/Montserrat-Regular.otf"
    }

    // ── Password Character Icons Mapping (matching LockScreenPanel's sequence) ──
    readonly property var passwordChars: ["\uf671", "\uf68c", "\u{1000c}", "\uf6a5", "\uf67b", "\ufeb1", "\uf6ad"]

    // ── State ──────────────────────────────────────────────────────────────────
    property int    sessionIndex: 0
    property string currentUser:  userModel.lastUser
    property int    userIndex:    0
    property bool   dropOpen:     false
    property bool   userDropOpen: false
    property bool   isAuthenticating: false

    // ── Noctalia custom palette from colors.json ──────────────────────────────
    readonly property string cSurface:      "#131313"      // Clear deep black
    readonly property string cSurfaceVar:   "#1f1f1f"
    readonly property string cOnSurface:    "#e2e2e2"
    readonly property string cOnSurfVar:    "#c6c6c6"
    readonly property string cPrimary:      "#9ccaff"      // Primary light blue accent
    readonly property string cOutline:      "#474747"
    readonly property string cOutlineMuted: "#33474747"    // 20% alpha outline
    readonly property string cError:        "#ffb4ab"      // Error crimson/pink
    readonly property string cOnError:      "#690005"
    readonly property string cHover:        "#d5bee5"      // Hover light purple
    readonly property string cOnHover:      "#3a2948"

    // ── Instantiators to safely convert C++ models to QML-accessible objects ──
    Instantiator {
        id: sessionInst
        model: sessionModel
        delegate: QtObject {
            property string name: model.name
            property string file: model.file
        }
    }

    Instantiator {
        id: userInst
        model: userModel
        delegate: QtObject {
            property string name: model.name
            property string realName: model.realName
            property string icon: model.icon
        }
    }

    // ── Safe Model Accessors ──────────────────────────────────────────────────
    function getSessionName(index) {
        if (sessionInst && index >= 0 && index < sessionInst.count) {
            var obj = sessionInst.objectAt(index);
            if (obj && obj.name) return obj.name;
        }
        return "Hyprland";
    }

    function getUserName(index) {
        if (userInst && index >= 0 && index < userInst.count) {
            var obj = userInst.objectAt(index);
            if (obj && obj.name) return obj.name;
        }
        return root.currentUser;
    }

    // ── Live time helpers for analog clock ────────────────────────────────────
    property string liveHour: Qt.formatTime(new Date(), "hh")
    property string liveMin:  Qt.formatTime(new Date(), "mm")
    property int    liveSec:  parseInt(Qt.formatTime(new Date(), "ss"))

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root.liveHour = Qt.formatTime(new Date(), "hh")
            root.liveMin  = Qt.formatTime(new Date(), "mm")
            root.liveSec  = parseInt(Qt.formatTime(new Date(), "ss"))
        }
    }

    // ── Keyboard state safely using global context ────────────────────────────
    property string currentLayoutShort: {
        try {
            if (keyboard && keyboard.layouts && keyboard.currentLayout >= 0 && keyboard.currentLayout < keyboard.layouts.length) {
                var l = keyboard.layouts[keyboard.currentLayout];
                if (l && l.shortName) return l.shortName.toUpperCase();
            }
        } catch(e) {}
        return "US";
    }

    // ── Background with blur & black overlay (45% black tint) ─────────────────
    Image {
        id: bgImg; anchors.fill: parent
        source: config.background !== "" ? config.background : ""
        fillMode: Image.PreserveAspectCrop; smooth: true; visible: false
    }
    GaussianBlur { anchors.fill: parent; source: bgImg; radius: 40; samples: 81 }
    Rectangle    { anchors.fill: parent; color: "#72000000" }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#66000000" }
            GradientStop { position: 0.35; color: "#11000000" }
            GradientStop { position: 1.0;  color: "#88000000" }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // TOP CARD — Header with avatar, greeting, date, and analogue clock
    // ══════════════════════════════════════════════════════════════════════════
    Rectangle {
        id: topCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: 80 * root.scaleRatio
        width: 660 * root.scaleRatio; height: 136 * root.scaleRatio; radius: 24 * root.scaleRatio
        color: root.cSurface  // Clear solid black surface
        border.color: root.cOutlineMuted; border.width: 1

        // ── Avatar circle ──
        Rectangle {
            id: avatarRing
            anchors.left: parent.left; anchors.leftMargin: 20 * root.scaleRatio
            anchors.verticalCenter: parent.verticalCenter
            width: 96 * root.scaleRatio; height: 96 * root.scaleRatio; radius: 48 * root.scaleRatio; color: "transparent"
            border.color: root.cPrimary; border.width: 2

            // Pulsing glow ring when authenticating
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4 * root.scaleRatio
                radius: width / 2
                color: "transparent"
                border.color: root.cPrimary
                border.width: 2.5 * root.scaleRatio
                opacity: 0.8
                visible: root.isAuthenticating

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.isAuthenticating
                    NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                }
            }

            Image {
                id: avi; anchors.centerIn: parent; width: 86 * root.scaleRatio; height: 86 * root.scaleRatio
                source: {
                    if (userInst && root.userIndex >= 0 && root.userIndex < userInst.count) {
                        var obj = userInst.objectAt(root.userIndex);
                        if (obj && obj.icon) return obj.icon;
                    }
                    return "file:///var/lib/AccountsService/icons/" + root.currentUser;
                }
                fillMode: Image.PreserveAspectCrop; asynchronous: true
                visible: status === Image.Ready && root.currentUser !== ""
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle { width: 86 * root.scaleRatio; height: 86 * root.scaleRatio; radius: 43 * root.scaleRatio }
                }
            }
            // Fallback avatar icon using tablerFont
            Text {
                anchors.centerIn: parent; visible: avi.status !== Image.Ready
                text: "\uebd6"; font.family: tablerFont.name; font.pixelSize: Math.round(36 * root.scaleRatio)
                color: root.cOnSurfVar; opacity: 0.6
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { root.userDropOpen = !root.userDropOpen; root.dropOpen = false }
            }
        }

        // ── Greeting + Date ──
        Column {
            anchors.left: avatarRing.right; anchors.leftMargin: 20 * root.scaleRatio
            anchors.verticalCenter: parent.verticalCenter; spacing: 6 * root.scaleRatio

            // Greeting text with clickable user dropdown indicator
            Item {
                width: greetingRow.implicitWidth
                height: greetingRow.implicitHeight

                Row {
                    id: greetingRow
                    spacing: 8 * root.scaleRatio
                    Text {
                        text: "Welcome back, " + root.currentUser + "!"
                        font.family: montserratFont.name; font.pixelSize: Math.round(24 * root.scaleRatio); font.weight: Font.Medium
                        color: root.cOnSurface
                    }
                    Text {
                        text: "▾"; font.family: montserratFont.name; font.pixelSize: Math.round(18 * root.scaleRatio); color: root.cPrimary
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.isAuthenticating
                    }
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    enabled: !root.isAuthenticating
                    onClicked: { root.userDropOpen = !root.userDropOpen; root.dropOpen = false }
                }
            }

            // Date label
            Text {
                id: dateLbl
                font.family: montserratFont.name; font.pixelSize: Math.round(16 * root.scaleRatio); color: root.cOnSurfVar
                text: Qt.formatDate(new Date(), "dddd, MMMM d")
                opacity: root.isAuthenticating ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Timer {
                    interval: 60000; running: true; repeat: true
                    onTriggered: dateLbl.text = Qt.formatDate(new Date(), "dddd, MMMM d")
                }
            }
        }

        // ── Analogue Clock (Canvas-based) ──
        Canvas {
            id: analogClock
            opacity: root.isAuthenticating ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            anchors.right: parent.right; anchors.rightMargin: 24 * root.scaleRatio
            anchors.verticalCenter: parent.verticalCenter
            width: 100 * root.scaleRatio; height: 100 * root.scaleRatio

            property int h: parseInt(root.liveHour)
            property int m: parseInt(root.liveMin)
            property int s: root.liveSec

            onHChanged: requestPaint()
            onMChanged: requestPaint()
            onSChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cx = width / 2, cy = height / 2, r = width / 2 - 4 * root.scaleRatio

                // Clock frame
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.strokeStyle = "#44ffffff"
                ctx.lineWidth = 2 * root.scaleRatio
                ctx.stroke()

                // Tick marks
                for (var i = 0; i < 12; i++) {
                    var angle = i * Math.PI / 6
                    var tickLen = (i % 3 === 0) ? (6 * root.scaleRatio) : (3 * root.scaleRatio)
                    ctx.beginPath()
                    ctx.moveTo(cx + (r - tickLen) * Math.sin(angle),
                               cy - (r - tickLen) * Math.cos(angle))
                    ctx.lineTo(cx + r * Math.sin(angle),
                               cy - r * Math.cos(angle))
                    ctx.strokeStyle = (i % 3 === 0) ? "#dddddd" : "#66ffffff"
                    ctx.lineWidth  = (i % 3 === 0) ? (2 * root.scaleRatio) : (1 * root.scaleRatio)
                    ctx.stroke()
                }

                // Hour hand
                var hAngle = ((h % 12) + m / 60) * Math.PI / 6
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(cx + (r * 0.50) * Math.sin(hAngle),
                           cy - (r * 0.50) * Math.cos(hAngle))
                ctx.strokeStyle = "#e2e2e2"; ctx.lineWidth = 3 * root.scaleRatio; ctx.lineCap = "round"; ctx.stroke()

                // Minute hand
                var mAngle = (m + s / 60) * Math.PI / 30
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(cx + (r * 0.72) * Math.sin(mAngle),
                           cy - (r * 0.72) * Math.cos(mAngle))
                ctx.strokeStyle = "#e2e2e2"; ctx.lineWidth = 2 * root.scaleRatio; ctx.lineCap = "round"; ctx.stroke()

                // Second hand
                var sAngle = s * Math.PI / 30
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(cx + (r * 0.80) * Math.sin(sAngle),
                           cy - (r * 0.80) * Math.cos(sAngle))
                ctx.strokeStyle = root.cPrimary; ctx.lineWidth = 1.5 * root.scaleRatio; ctx.lineCap = "round"; ctx.stroke()

                // Center dot
                ctx.beginPath()
                ctx.arc(cx, cy, 4 * root.scaleRatio, 0, 2 * Math.PI)
                ctx.fillStyle = root.cPrimary; ctx.fill()
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // USER SELECTION DROPDOWN — z:100, floating right below avatar/greeting
    // ══════════════════════════════════════════════════════════════════════════
    Rectangle {
        id: userDropdown
        visible: root.userDropOpen && userInst.count > 0
        z: 100
        width: 270 * root.scaleRatio
        height: Math.min(userInst.count, 6) * 50 * root.scaleRatio + 8

        x: topCard.x + 120 * root.scaleRatio
        y: topCard.y + topCard.height + 6 * root.scaleRatio

        radius: 16 * root.scaleRatio; color: root.cSurface; border.color: root.cOutline; border.width: 1

        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0; verticalOffset: 6 * root.scaleRatio
            radius: 24 * root.scaleRatio; samples: 49; color: "#99000000"
        }

        Column {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
            spacing: 0
            Repeater {
                model: userInst.count
                delegate: Rectangle {
                    width: userDropdown.width - 8; x: 4; height: 50 * root.scaleRatio; radius: 12 * root.scaleRatio
                    color: {
                        if (userItemMa.containsMouse) return "#1a9ccaff"
                        if (root.currentUser === getUserName(index)) return "#0f9ccaff"
                        return "transparent"
                    }
                    Behavior on color { ColorAnimation { duration: 80 } }

                    // Avatar in item
                    Rectangle {
                        id: userAviRing
                        anchors.left: parent.left; anchors.leftMargin: 10 * root.scaleRatio
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32 * root.scaleRatio; height: 32 * root.scaleRatio; radius: 16 * root.scaleRatio; color: "transparent"
                        border.color: root.currentUser === getUserName(index) ? root.cPrimary : "#44ffffff"; border.width: 1

                        Image {
                            id: userAviImg; anchors.centerIn: parent; width: 28 * root.scaleRatio; height: 28 * root.scaleRatio
                            source: {
                                if (userInst && index >= 0 && index < userInst.count) {
                                    var obj = userInst.objectAt(index);
                                    if (obj && obj.icon) return obj.icon;
                                }
                                return "file:///var/lib/AccountsService/icons/" + getUserName(index);
                            }
                            fillMode: Image.PreserveAspectCrop; asynchronous: true
                            visible: status === Image.Ready
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle { width: 28 * root.scaleRatio; height: 28 * root.scaleRatio; radius: 14 * root.scaleRatio }
                            }
                        }
                        Text {
                            anchors.centerIn: parent; visible: userAviImg.status !== Image.Ready
                            text: "\uebd6"; font.family: tablerFont.name; font.pixelSize: Math.round(18 * root.scaleRatio)
                            color: root.cOnSurfVar
                        }
                    }

                    // User name
                    Text {
                        anchors.left: userAviRing.right; anchors.leftMargin: 12 * root.scaleRatio
                        anchors.right: parent.right; anchors.rightMargin: 10 * root.scaleRatio
                        anchors.verticalCenter: parent.verticalCenter
                        text: getUserName(index)
                        font.family: montserratFont.name; font.pixelSize: Math.round(15 * root.scaleRatio)
                        color: root.currentUser === getUserName(index) ? root.cOnSurface : root.cOnSurfVar
                        font.weight: root.currentUser === getUserName(index) ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: userItemMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.userIndex = index
                            root.currentUser = getUserName(index)
                            root.userDropOpen = false
                            pwField.clear()
                            pwField.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // UNIFIED STATUS BAR PILL — Solid black background, exactly matching lockscreen
    // ══════════════════════════════════════════════════════════════════════════
    Rectangle {
        id: statusContainer
        opacity: root.isAuthenticating ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: btmCard.top; anchors.bottomMargin: 14 * root.scaleRatio
        height: 36 * root.scaleRatio; radius: 18 * root.scaleRatio
        color: root.cSurface  // Clear deep black background
        border.color: root.cOutlineMuted; border.width: 1
        width: compactStatusRow.implicitWidth + 32 * root.scaleRatio
        visible: batteryLbl.text !== "" || root.currentLayoutShort !== ""

        Row {
            id: compactStatusRow
            anchors.centerIn: parent
            spacing: 20 * root.scaleRatio

            // Battery
            Row {
                spacing: 6 * root.scaleRatio
                Text {
                    text: "\uea34"; font.family: tablerFont.name; font.pixelSize: Math.round(14 * root.scaleRatio)
                    color: root.cOnSurfVar; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: batteryLbl; text: "100%"; font.family: montserratFont.name; font.pixelSize: Math.round(13 * root.scaleRatio)
                    color: root.cOnSurfVar; anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Keyboard layout
            Row {
                spacing: 6 * root.scaleRatio
                Text {
                    text: "\uebd6"; font.family: tablerFont.name; font.pixelSize: Math.round(14 * root.scaleRatio)
                    color: root.cOnSurfVar; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.currentLayoutShort
                    font.family: montserratFont.name; font.pixelSize: Math.round(13 * root.scaleRatio)
                    color: root.cOnSurfVar; anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Caps Lock Warning (High-contrast red warning)
            Row {
                spacing: 6 * root.scaleRatio; visible: keyboard && keyboard.capsLock
                Text {
                    text: "\uea05"; font.family: tablerFont.name; font.pixelSize: Math.round(14 * root.scaleRatio)
                    color: root.cError; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Caps Lock"; font.family: montserratFont.name; font.pixelSize: Math.round(13 * root.scaleRatio)
                    color: root.cError; anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // BOTTOM CARD — 830px wide password container & premium outline buttons
    // ══════════════════════════════════════════════════════════════════════════
    Rectangle {
        id: btmCard
        width: 880 * root.scaleRatio
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 100 * root.scaleRatio
        radius: 24 * root.scaleRatio; color: root.cSurface  // Clear deep black
        border.color: root.cOutlineMuted; border.width: 1
        height: root.isAuthenticating ? 80 * root.scaleRatio : (errMsg.visible ? 180 : 148) * root.scaleRatio
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // ── Password Input Box (Radius 24 creates a perfect curved end pill) ──
        Rectangle {
            id: pwBox
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 * root.scaleRatio }
            height: 52 * root.scaleRatio; radius: 26 * root.scaleRatio
            color: "#0dffffff"  // Subtle glass fill
            border.color: root.isAuthenticating ? root.cPrimary : (pwField.activeFocus ? root.cPrimary : root.cOutline)
            border.width: root.isAuthenticating ? 2 : (pwField.activeFocus ? 2 : 1)
            Behavior on border.color { ColorAnimation { duration: 180 } }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: pwBox; property: "x"; to: -12; duration: 45 }
                NumberAnimation { target: pwBox; property: "x"; to:  12; duration: 45 }
                NumberAnimation { target: pwBox; property: "x"; to:  -7; duration: 45 }
                NumberAnimation { target: pwBox; property: "x"; to:   0; duration: 45 }
            }

            Text {
                id: inputIcon
                anchors.left: parent.left; anchors.leftMargin: 18 * root.scaleRatio
                anchors.verticalCenter: parent.verticalCenter
                text: "\ueae2"; font.family: tablerFont.name; font.pixelSize: Math.round(16 * root.scaleRatio)
                color: pwField.activeFocus ? root.cPrimary : root.cOnSurfVar
                visible: !root.isAuthenticating
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            // Real hidden text field capturing keypresses (text: transparent)
            TextField {
                id: pwField
                anchors {
                    left: parent.left; leftMargin: 54 * root.scaleRatio
                    right: parent.right; rightMargin: 54 * root.scaleRatio
                    verticalCenter: parent.verticalCenter
                }
                echoMode: TextInput.Normal
                placeholderText: "Enter password…"
                placeholderTextColor: "#55c6c6c6"
                color: "transparent"
                selectedTextColor: "transparent"
                selectionColor: "transparent"
                background: null
                font.family: montserratFont.name; font.pixelSize: Math.round(16 * root.scaleRatio)
                focus: true
                enabled: !root.isAuthenticating
                visible: !root.isAuthenticating
                Keys.onReturnPressed: doLogin()
                Keys.onEnterPressed:  doLogin()
            }

            // Beautiful Custom Tabler Password Characters (matching lockscreen sequence)
            Row {
                id: passwordDisplayContent
                spacing: 6 * root.scaleRatio
                anchors.left: parent.left; anchors.leftMargin: 54 * root.scaleRatio
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.isAuthenticating && pwField.text.length > 0

                Repeater {
                    model: pwField.text.length
                    delegate: Text {
                        font.family: tablerFont.name; font.pixelSize: Math.round(15 * root.scaleRatio)
                        color: root.cPrimary
                        text: root.passwordChars[index % root.passwordChars.length]
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Beautiful Blinking Caret positioning after characters
            Rectangle {
                width: 2 * root.scaleRatio; height: 22 * root.scaleRatio
                color: root.cPrimary
                visible: !root.isAuthenticating && pwField.activeFocus && pwField.text.length >= 0 && pwField.selectionStart === pwField.selectionEnd
                anchors.verticalCenter: parent.verticalCenter
                x: (54 * root.scaleRatio) + (pwField.text.length * 20 * root.scaleRatio) // approx horizontal caret tracking
                
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: !root.isAuthenticating && pwField.activeFocus && pwField.text.length >= 0 && pwField.selectionStart === pwField.selectionEnd
                    NumberAnimation { to: 0; duration: 530 }
                    NumberAnimation { to: 1; duration: 530 }
                }
            }

            // Submit arrow button (Curved pill)
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 6 * root.scaleRatio
                anchors.verticalCenter: parent.verticalCenter
                width: 38 * root.scaleRatio; height: 38 * root.scaleRatio; radius: 19 * root.scaleRatio
                color: submitMa.containsMouse ? "#1a9ccaff" : "transparent"
                border.color: root.cPrimary
                border.width: 1
                visible: !root.isAuthenticating
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent; text: "→"; font.family: montserratFont.name; font.pixelSize: Math.round(16 * root.scaleRatio)
                    color: submitMa.containsMouse ? root.cPrimary : root.cPrimary
                }
                MouseArea {
                    id: submitMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: doLogin()
                }
            }

            // In-place Loading Bar (replaces password input contents on submission)
            Row {
                anchors.centerIn: parent
                spacing: 12 * root.scaleRatio
                visible: root.isAuthenticating

                Item {
                    id: inPlaceSpinner
                    width: 22 * root.scaleRatio; height: 22 * root.scaleRatio
                    anchors.verticalCenter: parent.verticalCenter
                    property real spinAngle: 0

                    NumberAnimation on spinAngle {
                        from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: root.isAuthenticating
                    }

                    Canvas {
                        anchors.fill: parent
                        rotation: inPlaceSpinner.spinAngle
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width / 2, cy = height / 2, r = width / 2 - 2 * root.scaleRatio
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, 1.4 * Math.PI)
                            ctx.strokeStyle = root.cPrimary
                            ctx.lineWidth = 2.5 * root.scaleRatio
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Welcome, " + root.currentUser + "... Logging in"
                    font.family: montserratFont.name
                    font.pixelSize: Math.round(15 * root.scaleRatio)
                    font.weight: Font.Medium
                    color: root.cPrimary
                }
            }
        }

        // Error message
        Text {
            id: errMsg
            anchors { top: pwBox.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
            font.family: montserratFont.name; font.pixelSize: Math.round(14 * root.scaleRatio); color: root.cError
            visible: text !== ""; text: ""
        }

        // ── Custom Outlined Sleek Buttons (Height 38, Radius 19 creates curved end pills) ──
        Row {
            id: ctrlRow
            anchors { bottom: parent.bottom; bottomMargin: 14 * root.scaleRatio; horizontalCenter: parent.horizontalCenter }
            spacing: 10 * root.scaleRatio
            opacity: root.isAuthenticating ? 0.0 : 1.0
            visible: opacity > 0.0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            // Session selector pill
            Rectangle {
                id: sessPill
                width: 220 * root.scaleRatio; height: 42 * root.scaleRatio; radius: 21 * root.scaleRatio
                color: sessMa.containsMouse ? "#14ffffff" : "#0cffffff"
                border.color: root.dropOpen ? root.cPrimary : root.cOutline
                border.width: root.dropOpen ? 2 : 1
                Behavior on color        { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    anchors { left: parent.left; leftMargin: 14 * root.scaleRatio; verticalCenter: parent.verticalCenter }
                    spacing: 8 * root.scaleRatio
                    Text {
                        text: "\uebd6"; font.family: tablerFont.name; font.pixelSize: Math.round(14 * root.scaleRatio)
                        color: root.dropOpen ? root.cPrimary : root.cOnSurfVar
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: sessLbl; font.family: montserratFont.name; font.pixelSize: Math.round(14 * root.scaleRatio)
                        color: root.cOnSurface; width: 150 * root.scaleRatio; elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                        text: getSessionName(root.sessionIndex)
                    }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 14 * root.scaleRatio
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dropOpen ? "▲" : "▼"; font.family: montserratFont.name; font.pixelSize: Math.round(10 * root.scaleRatio); color: root.cOnSurfVar
                }
                MouseArea {
                    id: sessMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.dropOpen = !root.dropOpen; root.userDropOpen = false }
                }
            }

            Rectangle { width: 1; height: 24 * root.scaleRatio; color: root.cOutline; anchors.verticalCenter: sessPill.verticalCenter }

            // Logout Button (Sleek Height 42, Curved Radius 21)
            Rectangle {
                id: logoutBtn; width: 116 * root.scaleRatio; height: 42 * root.scaleRatio; radius: 21 * root.scaleRatio
                color: logoutMa.containsMouse ? root.cHover : "transparent"
                border.color: logoutMa.containsMouse ? root.cHover : root.cOnSurfVar
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 90 } }
                Behavior on border.color { ColorAnimation { duration: 90 } }

                Row {
                    anchors.centerIn: parent; spacing: 8 * root.scaleRatio
                    Text {
                        text: "\ueba8"; font.family: tablerFont.name; font.pixelSize: Math.round(14 * root.scaleRatio)
                        color: logoutMa.containsMouse ? root.cOnHover : root.cOnSurfVar
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Logout"; font.family: montserratFont.name; font.pixelSize: Math.round(14 * root.scaleRatio); font.weight: Font.DemiBold
                        color: logoutMa.containsMouse ? root.cOnHover : root.cOnSurfVar
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: logoutMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: sddm.logout()
                }
            }

            // Suspend Button (Sleek Height 42, Curved Radius 21)
            Rectangle {
                id: suspBtn; width: 120 * root.scaleRatio; height: 42 * root.scaleRatio; radius: 21 * root.scaleRatio
                color: suspMa.containsMouse ? root.cHover : "transparent"
                border.color: suspMa.containsMouse ? root.cHover : root.cOnSurfVar
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 90 } }
                Behavior on border.color { ColorAnimation { duration: 90 } }

                Row {
                    anchors.centerIn: parent; spacing: 8 * root.scaleRatio
                    Text {
                        text: "\ued45"; font.family: tablerFont.name; font.pixelSize: Math.round(14 * root.scaleRatio)
                        color: suspMa.containsMouse ? root.cOnHover : root.cOnSurfVar
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Suspend"; font.family: montserratFont.name; font.pixelSize: Math.round(14 * root.scaleRatio); font.weight: Font.DemiBold
                        color: suspMa.containsMouse ? root.cOnHover : root.cOnSurfVar
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: suspMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: sddm.suspend()
                }
            }

            // Reboot Button (Sleek Height 42, Curved Radius 21)
            Rectangle {
                id: rebtBtn; width: 116 * root.scaleRatio; height: 42 * root.scaleRatio; radius: 21 * root.scaleRatio
                color: rebtMa.containsMouse ? root.cHover : "transparent"
                border.color: rebtMa.containsMouse ? root.cHover : root.cOnSurfVar
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 90 } }
                Behavior on border.color { ColorAnimation { duration: 90 } }

                Row {
                    anchors.centerIn: parent; spacing: 8 * root.scaleRatio
                    Text {
                        text: "\ueb13"; font.family: tablerFont.name; font.pixelSize: Math.round(14 * root.scaleRatio)
                        color: rebtMa.containsMouse ? root.cOnHover : root.cOnSurfVar
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Reboot"; font.family: montserratFont.name; font.pixelSize: Math.round(14 * root.scaleRatio); font.weight: Font.DemiBold
                        color: rebtMa.containsMouse ? root.cOnHover : root.cOnSurfVar
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: rebtMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: sddm.reboot()
                }
            }

            // Shutdown Button (Sleek Height 42, Curved Radius 21, Red accents)
            Rectangle {
                id: shutBtn; width: 130 * root.scaleRatio; height: 42 * root.scaleRatio; radius: 21 * root.scaleRatio
                color: shutMa.containsMouse ? root.cError : "transparent"
                border.color: root.cError
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 90 } }
                Behavior on border.color { ColorAnimation { duration: 90 } }

                Row {
                    anchors.centerIn: parent; spacing: 8 * root.scaleRatio
                    Text {
                        text: "\ueb0d"; font.family: tablerFont.name; font.pixelSize: Math.round(14 * root.scaleRatio)
                        color: shutMa.containsMouse ? root.cOnError : root.cError
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }
                    Text {
                        text: "Shutdown"; font.family: montserratFont.name; font.pixelSize: Math.round(14 * root.scaleRatio); font.weight: Font.DemiBold
                        color: shutMa.containsMouse ? root.cOnError : root.cError
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }
                }
                MouseArea {
                    id: shutMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: sddm.powerOff()
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SESSION DROPDOWN — z:100, never clipped
    // ══════════════════════════════════════════════════════════════════════════
    Rectangle {
        id: dropPanel
        visible: root.dropOpen && sessionInst.count > 0
        z: 100
        width: 250 * root.scaleRatio
        height: Math.min(sessionInst.count, 8) * 44 * root.scaleRatio + 8
        x: (root.width - btmCard.width) / 2 + 16 * root.scaleRatio
        y: btmCard.y - height - 8 * root.scaleRatio
        radius: 16 * root.scaleRatio; color: root.cSurface; border.color: root.cOutline; border.width: 1

        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0; verticalOffset: -6 * root.scaleRatio
            radius: 24 * root.scaleRatio; samples: 49; color: "#99000000"
        }

        Column {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
            spacing: 0
            Repeater {
                model: sessionInst.count
                delegate: Rectangle {
                    width: dropPanel.width - 8; x: 4; height: 44 * root.scaleRatio; radius: 12 * root.scaleRatio
                    color: {
                        if (itemMa.containsMouse)        return "#1a9ccaff"
                        if (root.sessionIndex === index)  return "#0f9ccaff"
                        return "transparent"
                    }
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 14 * root.scaleRatio
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.sessionIndex === index ? "✓" : ""
                        font.pixelSize: Math.round(14 * root.scaleRatio); color: root.cPrimary
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 34 * root.scaleRatio
                        anchors.right: parent.right; anchors.rightMargin: 10 * root.scaleRatio
                        anchors.verticalCenter: parent.verticalCenter
                        text: getSessionName(index)
                        font.family: montserratFont.name; font.pixelSize: Math.round(13 * root.scaleRatio)
                        color: root.sessionIndex === index ? root.cOnSurface : root.cOnSurfVar
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: itemMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.sessionIndex = index
                            sessLbl.text = getSessionName(index)
                            root.dropOpen = false
                            pwField.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // Tap-outside closes active dropdowns
    MouseArea {
        anchors.fill: parent; z: 50
        visible: root.dropOpen || root.userDropOpen
        onClicked: {
            root.dropOpen = false
            root.userDropOpen = false
            pwField.forceActiveFocus()
        }
    }

    // ── Login Logic ────────────────────────────────────────────────────────────
    function doLogin() {
        if (pwField.text.length === 0) return;
        root.dropOpen = false
        root.userDropOpen = false
        errMsg.text = ""
        root.isAuthenticating = true
        sddm.login(root.currentUser, pwField.text, root.sessionIndex)
    }

    // ── Safe Model Sync Logic ──
    Connections {
        target: sddm
        function onLoginFailed() {
            root.isAuthenticating = false
            errMsg.text = "Incorrect password — try again"
            pwField.clear(); shake.start(); pwField.forceActiveFocus()
        }
        function onLoginSucceeded() {
            root.isAuthenticating = true
            errMsg.text = ""
        }
    }

    // Direct and immediate focusing plus active focus retry sequence
    Timer {
        id: focusTimer; interval: 100; running: true; repeat: false
        onTriggered: pwField.forceActiveFocus()
    }
    Timer {
        id: focusTimerSlow; interval: 300; running: true; repeat: false
        onTriggered: {
            pwField.forceActiveFocus();
            
            // Sync last logged-in user safely
            var ui = (userModel.lastIndex >= 0) ? userModel.lastIndex : 0
            if (userInst && userInst.count > 0 && ui < userInst.count) {
                root.userIndex = ui
                root.currentUser = getUserName(ui)
            }
            
            // Sync last session index safely
            var si = (sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : -1
            if (sessionInst && sessionInst.count > 0) {
                if (si === -1 || si >= sessionInst.count) {
                    // Fallback: search for plain Hyprland session in list
                    var hyprIndex = -1;
                    for (var i = 0; i < sessionInst.count; i++) {
                        var sObj = sessionInst.objectAt(i);
                        if (sObj && sObj.name) {
                            var n = sObj.name.toLowerCase();
                            if (n.indexOf("hyprland") !== -1 && n.indexOf("uwsm") === -1) {
                                hyprIndex = i;
                                break;
                            }
                        }
                    }
                    si = (hyprIndex !== -1) ? hyprIndex : 0;
                }
                root.sessionIndex = si
                sessLbl.text = getSessionName(si)
            }
        }
    }

    Component.onCompleted: {
        // Sync user index safely initially
        var ui = (userModel.lastIndex >= 0) ? userModel.lastIndex : 0
        root.userIndex = ui
        root.currentUser = getUserName(ui)

        // Sync session safely initially
        var si = (sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
        root.sessionIndex = si
        sessLbl.text = getSessionName(si)

        pwField.forceActiveFocus()
    }
}