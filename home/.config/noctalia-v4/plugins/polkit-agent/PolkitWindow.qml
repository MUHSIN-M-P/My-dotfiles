import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI

PanelWindow {
    id: polkitWindow

    property AuthFlow flow
    property var pluginApi

    // Starts in fingerprint mode. Scan finger or enter password.
    property bool fpScanning: true
    property bool fpSuccess: false
    property bool fpFailed: false

    Component.onCompleted: {
        Logger.i("PolkitAgentWindow", "Completed. Flow:", flow);
        if (flow) {
            Logger.i("PolkitAgentWindow", "  isResponseRequired:", flow.isResponseRequired);
            Logger.i("PolkitAgentWindow", "  inputPrompt:", flow.inputPrompt);
            Logger.i("PolkitAgentWindow", "  responseVisible:", flow.responseVisible);
            Logger.i("PolkitAgentWindow", "  supplementaryMessage:", flow.supplementaryMessage);
        }
        fpScanning = true
        fpSuccess = false
        fpFailed = false
        // Autofocus the password field immediately
        passwordInput.inputItem.forceActiveFocus()
    }

    // Watch flow for auth events
    Connections {
        target: flow
        enabled: flow !== null

        function onFailedChanged() {
            if (!flow || !flow.failed) return
            Logger.i("PolkitAgentWindow", "Authentication failed");
            fpSuccess = false
            fpFailed = true
            fpScanning = false
            ToastService.showError(
                pluginApi ? pluginApi.tr("error.failed.title") : "Authentication Failed",
                pluginApi ? pluginApi.tr("error.failed.message") : "The password you entered was incorrect."
            )
        }

        function onIsResponseRequiredChanged() {
            Logger.i("PolkitAgentWindow", "onIsResponseRequiredChanged:", flow ? flow.isResponseRequired : "null");
        }

        function onSupplementaryIsErrorChanged() {
            if (flow && flow.supplementaryIsError) {
                Logger.i("PolkitAgentWindow", "Supplementary error:", flow.supplementaryMessage);
                fpFailed = true
                fpScanning = false
            }
        }

        function onIsCompletedChanged() {
            if (flow && flow.isCompleted) {
                Logger.i("PolkitAgentWindow", "Auth completed, successful:", flow.isSuccessful);
                if (flow.isSuccessful) {
                    fpSuccess = true
                    fpScanning = false
                }
            }
        }

        function onIsSuccessfulChanged() {
            if (flow && flow.isSuccessful) {
                Logger.i("PolkitAgentWindow", "Auth succeeded");
                fpSuccess = true
                fpScanning = false
            }
        }
    }

    // ── Layout ─────────────────────────────────────────────────────────────
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property real shadowPadding: Style.shadowBlurMax + Style.marginL

    implicitWidth: 420 * Style.uiScaleRatio + shadowPadding * 2
    implicitHeight: contentLayout.implicitHeight + (Style.marginL * 2) + shadowPadding * 2

    color: "transparent"

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: shadowPadding
        focus: true

        Keys.onPressed: function(event) {
            if (!flow) return

            if (event.key === Qt.Key_Escape) {
                flow.cancelAuthenticationRequest()
                event.accepted = true
            }
        }

        // ── Shake animation on failure ─────────────────────────────────────
        transform: Translate { id: shakeTranslate; x: 0 }

        SequentialAnimation {
            id: errorShake
            running: flow && flow.failed
            loops: 1
            NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: 10; to: -10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: 10; to: 0; duration: 50; easing.type: Easing.InOutQuad }
        }

        // ── Drop shadow ────────────────────────────────────────────────────
        NDropShadow {
            anchors.fill: cardBackground
            source: cardBackground
            autoPaddingEnabled: true
            z: -1
        }

        // ── Card background ────────────────────────────────────────────────
        Rectangle {
            id: cardBackground
            anchors.fill: parent
            radius: Style.radiusL
            color: Qt.alpha(Color.mSurface, 0.97)
            border.color: fpSuccess ? Color.mPrimary :
                          fpFailed  ? Color.mError :
                          (flow && (flow.failed || flow.supplementaryIsError)) ? Color.mError :
                          Color.mOutline
            border.width: Style.borderS

            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        ColumnLayout {
            id: contentLayout
            anchors.centerIn: parent
            width: parent.width - (Style.marginL * 2)
            spacing: Style.marginM

            // ── Header ─────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NImageRounded {
                    Layout.preferredWidth: Style.fontSizeXXL * 2
                    Layout.preferredHeight: Style.fontSizeXXL * 2
                    imagePath: (flow && flow.iconName) ? Quickshell.iconPath(flow.iconName) : ""
                    fallbackIcon: "lock"
                    borderWidth: 0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXS

                    NText {
                        text: flow ? flow.message : (pluginApi ? pluginApi.tr("window.title") : "Authentication Required")
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    NText {
                        text: flow ? flow.actionId : ""
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        visible: text !== ""
                    }
                }
            }

            // ── Fingerprint zone (always shown) ────────────────────────────
            ColumnLayout {
                id: fpZone
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Style.marginL * 1.5
                Layout.bottomMargin: Style.marginS
                spacing: Style.marginM

                // Large fingerprint icon
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width: 64 * Style.uiScaleRatio
                    height: 64 * Style.uiScaleRatio

                    // Glow ring (pulsing when scanning)
                    Rectangle {
                        id: glowRing
                        anchors.centerIn: parent
                        width: parent.width + 16 * Style.uiScaleRatio
                        height: parent.height + 16 * Style.uiScaleRatio
                        radius: width / 2
                        color: "transparent"
                        border.color: fpSuccess ? Color.mPrimary :
                                      fpFailed  ? Color.mError :
                                      Qt.alpha(Color.mPrimary, 0.4)
                        border.width: 2 * Style.uiScaleRatio
                        visible: fpScanning || fpSuccess

                        SequentialAnimation on opacity {
                            running: fpScanning && !fpSuccess
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.8; to: 0.0; duration: 1000; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.0; to: 0.8; duration: 1000; easing.type: Easing.InOutSine }
                        }
                        opacity: fpSuccess ? 1.0 : 0.0
                    }

                    // Second outer ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 32 * Style.uiScaleRatio
                        height: parent.height + 32 * Style.uiScaleRatio
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.alpha(Color.mPrimary, 0.2)
                        border.width: 1.5 * Style.uiScaleRatio
                        visible: fpScanning

                        SequentialAnimation on opacity {
                            running: fpScanning && !fpSuccess
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.6; to: 0.0; duration: 1000; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.0; to: 0.6; duration: 1400; easing.type: Easing.InOutSine }
                        }
                    }

                    // Main fingerprint icon
                    NIcon {
                        anchors.centerIn: parent
                        icon: "fingerprint"
                        pointSize: 48
                        color: fpSuccess ? Color.mPrimary :
                               fpFailed  ? Color.mError :
                               Color.mOnSurfaceVariant

                        Behavior on color { ColorAnimation { duration: 200 } }

                        SequentialAnimation on opacity {
                            running: fpScanning && !fpSuccess
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.5; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.5; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // Status text
                NText {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        if (fpSuccess) return "✓ Authorized";
                        if (fpFailed) return "Mismatch, try again";
                        return "";
                    }
                    pointSize: Style.fontSizeS
                    font.weight: fpSuccess ? Style.fontWeightBold : Style.fontWeightRegular
                    color: fpSuccess ? Color.mPrimary :
                           fpFailed  ? Color.mError :
                           Color.mOnSurfaceVariant
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            // ── Password input (always visible) ────────────────────────────
            NTextInput {
                id: passwordInput
                Layout.fillWidth: true
                placeholderText: pluginApi ? pluginApi.tr("prompt.password") : "Password"
                label: pluginApi ? pluginApi.tr("prompt.password") : "Password"
                inputItem.echoMode: (flow && !flow.responseVisible) ? TextInput.Password : TextInput.Normal

                onAccepted: {
                    if (flow && text !== "") {
                        flow.submit(text)
                        text = ""
                    }
                }
            }

            // ── Action buttons ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Style.marginS
                spacing: Style.marginM

                Item { Layout.fillWidth: true }

                NButton {
                    text: pluginApi ? pluginApi.tr("action.cancel") : "Cancel"
                    backgroundColor: Color.mSurfaceVariant
                    textColor: Color.mOnSurfaceVariant
                    outlined: false
                    onClicked: {
                        if (flow) flow.cancelAuthenticationRequest()
                    }
                }

                NButton {
                    text: pluginApi ? pluginApi.tr("action.authenticate") : "Authenticate"
                    backgroundColor: Color.mPrimary
                    textColor: Color.mOnPrimary
                    enabled: flow && passwordInput.text !== ""
                    onClicked: {
                        if (flow && passwordInput.text !== "") {
                            flow.submit(passwordInput.text)
                            passwordInput.text = ""
                        }
                    }
                }
            }
        }
    }
}
