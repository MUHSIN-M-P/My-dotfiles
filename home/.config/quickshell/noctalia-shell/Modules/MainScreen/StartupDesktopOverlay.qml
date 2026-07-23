import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

/**
 * StartupDesktopOverlay — covers the SDDM→Hyprland gap seamlessly.
 *
 * Appears instantly at shell startup. Visual is identical to SDDM's
 * loading state (same colors, layout, avatar, spinner).
 * Fades only when WallpaperService is initialized (desktop ready).
 * Writes /tmp/noctalia-ready to kill the swaybg bridge process.
 */
Item {
  id: root

  // Noctalia palette — kept in sync with SDDM Main.qml
  readonly property string cSurface:      "#131313"
  readonly property string cOnSurface:    "#e2e2e2"
  readonly property string cOnSurfVar:    "#c6c6c6"
  readonly property string cPrimary:      "#9ccaff"
  readonly property string cOutlineMuted: "#33474747"

  property bool active: true
  property bool isFading: false

  // Signal the swaybg bridge to exit
  Process {
    id: readySignal
    command: ["bash", "-c", "touch /tmp/noctalia-ready"]
  }

  // Poll WallpaperService every 300ms
  Timer {
    id: checkReadyTimer
    interval: 300
    running: true
    repeat: true
    onTriggered: {
      if (WallpaperService.isInitialized) {
        checkReadyTimer.stop();
        safetyTimer.stop();
        postReadyTimer.start();
      }
    }
  }

  // Small buffer after wallpaper ready so first frame fully paints
  Timer {
    id: postReadyTimer
    interval: 350
    running: false
    repeat: false
    onTriggered: {
      readySignal.running = true;
      root.isFading = true;
      unloadTimer.start();
    }
  }

  // Safety bail-out after 8s
  Timer {
    id: safetyTimer
    interval: 8000
    running: true
    repeat: false
    onTriggered: {
      if (!root.isFading) {
        readySignal.running = true;
        root.isFading = true;
        unloadTimer.start();
      }
    }
  }

  Timer {
    id: unloadTimer
    interval: 520
    running: false
    repeat: false
    onTriggered: { root.active = false; }
  }

  Loader {
    active: root.active
    asynchronous: false

    sourceComponent: Variants {
      model: Quickshell.screens
      delegate: PanelWindow {
        required property ShellScreen modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "noctalia-startup-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.anchors { top: true; bottom: true; left: true; right: true }

        color: "transparent"

        // Full-screen solid dark cover — fades out when desktop is ready
        Rectangle {
          anchors.fill: parent
          color: root.cSurface
          opacity: root.isFading ? 0.0 : 1.0
          Behavior on opacity {
            NumberAnimation { duration: 480; easing.type: Easing.OutCubic }
          }
        }

        // Top card — mirrors SDDM topCard layout exactly
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: 80
          width: 660; height: 136; radius: 24
          color: root.cSurface
          border.color: root.cOutlineMuted; border.width: 1
          opacity: root.isFading ? 0.0 : 1.0
          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          // Avatar ring with pulsing outer glow
          Rectangle {
            id: avatarRing
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 96; height: 96; radius: 48
            color: "transparent"
            border.color: root.cPrimary; border.width: 2

            Rectangle {
              anchors.fill: parent; anchors.margins: -4
              radius: width / 2; color: "transparent"
              border.color: root.cPrimary; border.width: 2.5
              SequentialAnimation on opacity {
                loops: Animation.Infinite; running: !root.isFading
                NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
              }
            }

            NImageRounded {
              anchors.fill: parent; anchors.margins: 5
              radius: width / 2
              imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
              fallbackIcon: "person"
            }
          }

          Column {
            anchors.left: avatarRing.right; anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
              text: "Welcome back, " + (HostService.displayName || "...") + "!"
              font.family: Style.fontFamily
              font.pixelSize: 24; font.weight: Font.Medium
              color: root.cOnSurface
            }
            Text {
              text: WallpaperService.isInitialized ? "Almost ready..." : "Preparing your desktop..."
              font.family: Style.fontFamily
              font.pixelSize: 16; color: root.cOnSurfVar
            }
          }
        }

        // Bottom card — mirrors SDDM btmCard loading state exactly
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom; anchors.bottomMargin: 100
          width: 880; height: 80; radius: 24
          color: root.cSurface
          border.color: root.cOutlineMuted; border.width: 1
          opacity: root.isFading ? 0.0 : 1.0
          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          // Inner pill matching pwBox in loading state
          Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
            height: 52; radius: 26
            color: "#0dffffff"
            border.color: root.cPrimary; border.width: 2

            Row {
              anchors.centerIn: parent
              spacing: 12

              // Spinner
              Item {
                id: spinner
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                property real angle: 0
                NumberAnimation on angle {
                  from: 0; to: 360; duration: 1000
                  loops: Animation.Infinite; running: !root.isFading
                }
                Canvas {
                  anchors.fill: parent
                  rotation: spinner.angle
                  onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width/2, cy = height/2, r = width/2 - 2
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 1.4 * Math.PI)
                    ctx.strokeStyle = root.cPrimary
                    ctx.lineWidth = 2.5; ctx.lineCap = "round"
                    ctx.stroke()
                  }
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Welcome, " + (HostService.displayName || "...") + "... Logging in"
                font.family: Style.fontFamily
                font.pixelSize: 15; font.weight: Font.Medium
                color: root.cPrimary
              }
            }
          }
        }
      }
    }
  }
}
