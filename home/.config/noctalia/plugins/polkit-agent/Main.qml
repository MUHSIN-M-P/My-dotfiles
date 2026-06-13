import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null

    PolkitAgent {
        id: agent

        // Use onAuthenticationRequestStarted - fired AFTER flow is populated
        onAuthenticationRequestStarted: {
            openWindow()
        }

        // Use flowChanged to handle flow teardown
        onFlowChanged: {
            if (agent.flow === null) {
                closeWindow()
            } else if (window !== null) {
                window.flow = agent.flow
            }
        }
    }

    property var window: null

    function openWindow() {
        if (window === null) {
            var comp = Qt.createComponent("PolkitWindow.qml");
            if (comp.status === Component.Error) {
                console.error("[PolkitAgent] PolkitWindow.qml compile error:", comp.errorString());
                return;
            }
            window = comp.createObject(root, {
                flow: agent.flow,
                pluginApi: Qt.binding(function() { return root.pluginApi })
            });
            if (window === null) {
                console.error("[PolkitAgent] createObject returned null:", comp.errorString());
                return;
            }
            window.visible = true;
        } else {
            window.flow = agent.flow
            window.pluginApi = root.pluginApi
            window.visible = true
        }
    }

    function closeWindow() {
        if (window !== null) {
            window.destroy();
            window = null;
        }
    }
}
