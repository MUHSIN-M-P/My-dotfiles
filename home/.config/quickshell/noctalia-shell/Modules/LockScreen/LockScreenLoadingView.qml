import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Widgets

Item {
  id: root

  required property var lockContext
  readonly property bool active: lockContext && (lockContext.unlockInProgress || lockContext.isUnlocking)
  readonly property bool animationsEnabled: Settings.data.general.lockScreenAnimations || false

  anchors.centerIn: parent
  width: card.width
  height: card.height

  opacity: active ? 1.0 : 0.0
  scale: active ? 1.0 : 0.9
  visible: opacity > 0.0

  Behavior on opacity {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  Behavior on scale {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutBack
      easing.overshoot: 1.1
    }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.max(420, contentColumn.implicitWidth + Style.margin2XL * 2)
    height: Math.max(240, contentColumn.implicitHeight + Style.margin2XL * 2)
    radius: Style.radiusXL
    color: Color.mSurface
    border.color: Qt.alpha(Color.mPrimary, 0.35)
    border.width: Style.borderS

    ColumnLayout {
      id: contentColumn
      anchors.centerIn: parent
      spacing: Style.marginL

      // User Avatar with pulsing/glowing accent ring
      Rectangle {
        Layout.preferredWidth: 90
        Layout.preferredHeight: 90
        Layout.alignment: Qt.AlignHCenter
        radius: width / 2
        color: "transparent"

        // Glow ring behind avatar
        Rectangle {
          anchors.fill: parent
          anchors.margins: -5
          radius: parent.radius + 5
          color: "transparent"
          border.color: Color.mPrimary
          border.width: 2.5
          opacity: 0.8

          SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: root.active && root.animationsEnabled
            NumberAnimation {
              to: 0.3
              duration: 900
              easing.type: Easing.InOutQuad
            }
            NumberAnimation {
              to: 1.0
              duration: 900
              easing.type: Easing.InOutQuad
            }
          }

          SequentialAnimation on scale {
            loops: Animation.Infinite
            running: root.active && root.animationsEnabled
            NumberAnimation {
              to: 1.06
              duration: 900
              easing.type: Easing.InOutQuad
            }
            NumberAnimation {
              to: 1.0
              duration: 900
              easing.type: Easing.InOutQuad
            }
          }
        }

        NImageRounded {
          anchors.fill: parent
          radius: width / 2
          imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
          fallbackIcon: "person"
        }
      }

      // User Display Name
      NText {
        Layout.alignment: Qt.AlignHCenter
        text: HostService.displayName || "User"
        pointSize: Style.fontSizeXXL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        horizontalAlignment: Text.AlignHCenter
      }

      // Status Indicator (Spinner + Text)
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginM

        NBusyIndicator {
          size: Style.fontSizeXL
          color: Color.mPrimary
          strokeWidth: 3
          running: root.active
        }

        NText {
          text: lockContext.isUnlocking ? (I18n.tr("system.welcome") || "Welcome") + "..." : (I18n.tr("lock-screen.authenticating") || "Authenticating...")
          pointSize: Style.fontSizeL
          color: Color.mOnSurfaceVariant
          font.weight: Style.fontWeightMedium
        }
      }
    }
  }
}
