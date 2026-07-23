import QtQuick  
import Quickshell  
import Quickshell.Wayland  
  
PanelWindow {  
    id: root  
      
    property var targetScreen: Quickshell.screens[0]
    property alias contentItem: root.contentItem  

    screen: targetScreen

    anchors { 
        left: true  
        right: true  
        top: true  
        bottom: true  
    }  
  
    exclusionMode: ExclusionMode.Ignore  
    WlrLayershell.layer: WlrLayer.Overlay  
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand  
  
    Image {  
        source: (root.visible && root.tempPath) ? "file://" + root.tempPath : ""
        anchors.fill: parent  
        z: -1
    }  
}
