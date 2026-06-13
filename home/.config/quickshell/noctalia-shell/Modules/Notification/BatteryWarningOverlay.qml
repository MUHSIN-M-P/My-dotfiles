import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Hardware
import qs.Widgets

/**
 * BatteryWarningOverlay - Fullscreen dialog alert for low/critical battery levels.
 * Dimmed, blurred, and requires clicking OK or pressing Enter/Space/Escape to dismiss.
 */
Variants {
  id: root
  model: Quickshell.screens

  delegate: Loader {
    id: windowLoader
    required property ShellScreen modelData

    active: BatteryService.showLowBatteryWarning || delayTimer.running

    Timer {
      id: delayTimer
      interval: Style.animationNormal + 50
      repeat: false
    }

    Connections {
      target: BatteryService
      function onShowLowBatteryWarningChanged() {
        if (!BatteryService.showLowBatteryWarning) {
          delayTimer.restart();
        }
      }
    }

    sourceComponent: PanelWindow {
      id: warningWindow
      screen: windowLoader.modelData

      color: "transparent"

      WlrLayershell.namespace: "noctalia-battery-warning-" + (screen?.name || "unknown")
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.exclusionMode: ExclusionMode.Ignore

      WlrLayershell.anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      BackgroundEffect.blurRegion: Settings.data.general.enableBlurBehind ? rootRegion : null
      Region {
        id: rootRegion
        x: 0
        y: 0
        width: warningWindow.width
        height: warningWindow.height
      }

      Shortcut {
        sequence: "Return"
        enabled: BatteryService.showLowBatteryWarning
        onActivated: BatteryService.showLowBatteryWarning = false
      }
      Shortcut {
        sequence: "Enter"
        enabled: BatteryService.showLowBatteryWarning
        onActivated: BatteryService.showLowBatteryWarning = false
      }
      Shortcut {
        sequence: "Escape"
        enabled: BatteryService.showLowBatteryWarning
        onActivated: BatteryService.showLowBatteryWarning = false
      }

      Item {
        id: contentContainer
        anchors.fill: parent

        // Backdrop dimming
        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(0, 0, 0, 0.5)
          opacity: BatteryService.showLowBatteryWarning ? 1.0 : 0.0

          Behavior on opacity {
            NumberAnimation {
              duration: Style.animationNormal
              easing.type: Easing.OutCubic
            }
          }
        }

        // Center dialog box
        Item {
          id: dialogContainer
          anchors.centerIn: parent
          width: Math.min(440 * Style.uiScaleRatio, parent.width * 0.9)
          height: dialogBackground.implicitHeight

          scale: BatteryService.showLowBatteryWarning ? 1.0 : 0.8
          opacity: BatteryService.showLowBatteryWarning ? 1.0 : 0.0

          Behavior on scale {
            SpringAnimation {
              spring: 2.0
              damping: 0.7
              mass: 0.8
            }
          }

          Behavior on opacity {
            NumberAnimation {
              duration: Style.animationNormal
              easing.type: Easing.OutCubic
            }
          }

          NDropShadow {
            source: dialogBackground
            anchors.fill: dialogBackground
            autoPaddingEnabled: true
          }

          Rectangle {
            id: dialogBackground
            anchors.fill: parent
            radius: Style.radiusL
            color: Color.smartAlpha(Color.mSurface)
            border.color: Color.mOutline
            border.width: Style.borderS
            implicitHeight: dialogLayout.implicitHeight + (Style.marginXL * 2)

            ColumnLayout {
              id: dialogLayout
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.marginXL
              spacing: Style.marginL

              // Urgency/Warning Icon
              NIcon {
                icon: BatteryService.lowBatteryWarningIcon || "battery-exclamation"
                pointSize: 48
                color: Color.mError
                Layout.alignment: Qt.AlignHCenter
              }

              // Bold Title
              NText {
                text: BatteryService.lowBatteryWarningTitle || "Low Battery"
                pointSize: Style.fontSizeXL
                font.weight: Style.fontWeightBold
                color: Color.mError
                Layout.alignment: Qt.AlignHCenter
              }

              // Descriptive Warning Message
              NText {
                text: BatteryService.lowBatteryWarningDesc || ""
                pointSize: Style.fontSizeL
                color: Color.mOnSurfaceVariant
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
              }

              // Acknowledge Action Button
              NButton {
                text: "OK"
                backgroundColor: Color.mPrimary
                textColor: Color.mOnPrimary
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Style.marginM
                onClicked: {
                  BatteryService.showLowBatteryWarning = false;
                }
              }
            }
          }
        }
      }
    }
  }
}
