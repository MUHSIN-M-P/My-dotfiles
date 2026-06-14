import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.Noctalia
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen
  property var widgetData: null
  property int widgetIndex: -1

  property real defaultX: 100
  property real defaultY: 100

  default property alias content: contentContainer.data

  readonly property bool isDragging: internal.isDragging
  readonly property bool isScaling: internal.isScaling

  // All Desktop widgets have these settings, but fallback just in case
  readonly property var _metadata: widgetData?.id ? DesktopWidgetRegistry.widgetMetadata[widgetData.id] : null
  property bool showBackground: widgetData.showBackground !== undefined ? widgetData.showBackground : (_metadata?.showBackground ?? true)
  property bool roundedCorners: widgetData.roundedCorners !== undefined ? widgetData.roundedCorners : (_metadata?.roundedCorners ?? true)

  property real widgetScale: 1.0
  property real widgetScaleX: 1.0
  property real widgetScaleY: 1.0
  property real minScale: 0.5
  property real maxScale: 5.0

  readonly property real scaleSensitivity: 0.0015
  readonly property real scaleUpdateThreshold: 0.015
  readonly property real cornerScaleSensitivity: 0.0003  // Much lower sensitivity for corner handles

  // Grid size ensures lines pass through screen center on both axes
  readonly property int gridSize: {
    if (!screen)
      return 30;
    var baseSize = Math.round(screen.width * 0.015);
    baseSize = Math.max(20, Math.min(60, baseSize));

    var centerX = screen.width / 2;
    var centerY = screen.height / 2;
    var bestSize = baseSize;
    var bestDistance = Infinity;

    for (var offset = -10; offset <= 10; offset++) {
      var candidate = baseSize + offset;
      if (candidate < 20 || candidate > 60)
        continue;

      var remainderX = centerX % candidate;
      var remainderY = centerY % candidate;

      if (remainderX === 0 && remainderY === 0) {
        return candidate;
      }

      var distance = Math.abs(remainderX) + Math.abs(remainderY);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestSize = candidate;
      }
    }

    var gcd = function (a, b) {
      while (b !== 0) {
        var temp = b;
        b = a % b;
        a = temp;
      }
      return a;
    };

    var centerGcd = gcd(Math.round(centerX), Math.round(centerY));
    if (centerGcd > 0) {
      for (var divisor = Math.floor(centerGcd / 60); divisor <= Math.ceil(centerGcd / 20); divisor++) {
        if (centerGcd % divisor !== 0)
          continue;
        var candidate = centerGcd / divisor;
        if (candidate >= 20 && candidate <= 60) {
          if (Math.abs(candidate - baseSize) < Math.abs(bestSize - baseSize)) {
            bestSize = candidate;
          }
        }
      }
    }

    return bestSize;
  }

  QtObject {
    id: internal
    property bool isDragging: false
    property bool isScaling: false
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real baseX: (root.widgetData && root.widgetData.x !== undefined) ? root.widgetData.x : root.defaultX
    property real baseY: (root.widgetData && root.widgetData.y !== undefined) ? root.widgetData.y : root.defaultY
    property real initialWidth: 0
    property real initialHeight: 0
    property point initialMousePos: Qt.point(0, 0)
    property real initialScale: 1.0
    property real initialScaleX: 1.0
    property real initialScaleY: 1.0
    property real lastScale: 1.0
    property real lastScaleX: 1.0
    property real lastScaleY: 1.0
    // Locks operation type to prevent switching between drag/scale mid-operation
    property string operationType: ""  // "drag" or "scale" or ""
  }

  function snapToGrid(coord) {
    if (!Settings.data.desktopWidgets.gridSnap) {
      return coord;
    }
    return Math.round(coord / root.gridSize) * root.gridSize;
  }

  function snapScaleXToGrid(scale) {
    if (!Settings.data.desktopWidgets.gridSnap || !Settings.data.desktopWidgets.gridSnapScale) {
      return scale;
    }

    var initialWidth = internal.initialWidth;
    var initialScaleX = internal.initialScaleX;
    if (initialWidth <= 0 || initialScaleX <= 0) {
      return scale;
    }

    var baseWidth = initialWidth / initialScaleX;
    var resultingWidth = baseWidth * scale;
    var snappedWidth = root.snapToGrid(resultingWidth);

    if (snappedWidth < root.gridSize) {
      snappedWidth = root.gridSize;
    }

    var snappedScale = snappedWidth / baseWidth;
    return Math.max(minScale, Math.min(maxScale, snappedScale));
  }

  function snapScaleYToGrid(scale) {
    if (!Settings.data.desktopWidgets.gridSnap || !Settings.data.desktopWidgets.gridSnapScale) {
      return scale;
    }

    var initialHeight = internal.initialHeight;
    var initialScaleY = internal.initialScaleY;
    if (initialHeight <= 0 || initialScaleY <= 0) {
      return scale;
    }

    var baseHeight = initialHeight / initialScaleY;
    var resultingHeight = baseHeight * scale;
    var snappedHeight = root.snapToGrid(resultingHeight);

    if (snappedHeight < root.gridSize) {
      snappedHeight = root.gridSize;
    }

    var snappedScale = snappedHeight / baseHeight;
    return Math.max(minScale, Math.min(maxScale, snappedScale));
  }

  function snapScaleToGrid(scale) {
    if (!Settings.data.desktopWidgets.gridSnap || !Settings.data.desktopWidgets.gridSnapScale) {
      return scale;
    }

    // Get widget's base width
    var initialWidth = internal.initialWidth;
    var initialScale = internal.initialScale;
    if (initialWidth <= 0 || initialScale <= 0) {
      return scale;
    }

    // Since initialWidth = baseWidth * initialScale
    var baseWidth = initialWidth / initialScale;

    // Snap the resulting width with the scale
    var resultingWidth = baseWidth * scale;
    var snappedWidth = root.snapToGrid(resultingWidth);

    // Check that the snappedWidth isn't smaller than one grid size
    if (snappedWidth < root.gridSize) {
      snappedWidth = root.gridSize;
    }

    // Return the ratio of the snappedWidth and the baseWidth, which is the new snapped scale
    var snappedScale = snappedWidth / baseWidth;
    return Math.max(minScale, Math.min(maxScale, snappedScale));
  }

  function updateWidgetData(properties) {
    if (widgetIndex < 0 || !screen || !screen.name) {
      return;
    }
    DesktopWidgetRegistry.updateWidgetData(screen.name, widgetIndex, properties);
  }

  function removeWidget() {
    if (widgetIndex < 0 || !screen || !screen.name) {
      return;
    }

    var monitorWidgets = Settings.data.desktopWidgets.monitorWidgets || [];
    var newMonitorWidgets = monitorWidgets.slice();

    for (var i = 0; i < newMonitorWidgets.length; i++) {
      if (newMonitorWidgets[i].name === screen.name) {
        var widgets = (newMonitorWidgets[i].widgets || []).slice();
        if (widgetIndex >= 0 && widgetIndex < widgets.length) {
          widgets.splice(widgetIndex, 1);
          newMonitorWidgets[i] = Object.assign({}, newMonitorWidgets[i], {
                                                 "widgets": widgets
                                               });
          Settings.data.desktopWidgets.monitorWidgets = newMonitorWidgets;
        }
        break;
      }
    }
  }

  function raiseToTop() {
    if (widgetIndex < 0 || !screen || !screen.name) {
      return;
    }

    var monitorWidgets = Settings.data.desktopWidgets.monitorWidgets || [];
    var newMonitorWidgets = monitorWidgets.slice();

    for (var i = 0; i < newMonitorWidgets.length; i++) {
      if (newMonitorWidgets[i].name === screen.name) {
        var widgets = (newMonitorWidgets[i].widgets || []).slice();
        if (widgetIndex < widgets.length && widgetIndex < widgets.length - 1) {
          var widget = widgets.splice(widgetIndex, 1)[0];
          widgets.push(widget);
          newMonitorWidgets[i] = Object.assign({}, newMonitorWidgets[i], {
                                                 "widgets": widgets
                                               });
          Settings.data.desktopWidgets.monitorWidgets = newMonitorWidgets;
        }
        break;
      }
    }
  }

  function lowerToBottom() {
    if (widgetIndex < 0 || !screen || !screen.name) {
      return;
    }

    var monitorWidgets = Settings.data.desktopWidgets.monitorWidgets || [];
    var newMonitorWidgets = monitorWidgets.slice();

    for (var i = 0; i < newMonitorWidgets.length; i++) {
      if (newMonitorWidgets[i].name === screen.name) {
        var widgets = (newMonitorWidgets[i].widgets || []).slice();
        if (widgetIndex < widgets.length && widgetIndex > 0) {
          var widget = widgets.splice(widgetIndex, 1)[0];
          widgets.unshift(widget);
          newMonitorWidgets[i] = Object.assign({}, newMonitorWidgets[i], {
                                                 "widgets": widgets
                                               });
          Settings.data.desktopWidgets.monitorWidgets = newMonitorWidgets;
        }
        break;
      }
    }
  }

  function openWidgetSettings() {
    DesktopWidgetRegistry.openWidgetSettings(screen, widgetIndex, widgetData.id, widgetData);
  }

  function handleContextMenuAction(action) {
    if (action === "widget-settings") {
      // Don't close - openWidgetSettings will use the popup window for the dialog
      root.openWidgetSettings();
      return true; // Signal that we're handling close ourselves
    } else if (action === "reset") {
      // Reset scale and position to defaults
      root.widgetScale = 1.0;
      internal.baseX = root.defaultX;
      internal.baseY = root.defaultY;
      root.updateWidgetData({
                              "scale": 1.0,
                              "x": Math.round(root.defaultX),
                              "y": Math.round(root.defaultY)
                            });
      return false;
    } else if (action === "raise-to-top") {
      root.raiseToTop();
      return false;
    } else if (action === "lower-to-bottom") {
      root.lowerToBottom();
      return false;
    } else if (action === "delete") {
      root.removeWidget();
      return false; // Let caller close the popup
    }
    return false;
  }

  x: Math.round(internal.isDragging ? internal.dragOffsetX : internal.baseX)
  y: Math.round(internal.isDragging ? internal.dragOffsetY : internal.baseY)

  // Note: We no longer use transform-based scaling (scale property)
  // Instead, child widgets multiply their dimensions by widgetScale
  // This prevents blurry text at fractional scale values

  Component.onCompleted: {
    if (widgetData) {
      if (widgetData.scaleX !== undefined) {
        widgetScaleX = widgetData.scaleX;
      } else if (widgetData.scale !== undefined) {
        widgetScaleX = widgetData.scale;
      }
      if (widgetData.scaleY !== undefined) {
        widgetScaleY = widgetData.scaleY;
      } else if (widgetData.scale !== undefined) {
        widgetScaleY = widgetData.scale;
      }
      if (widgetData.scale !== undefined) {
        widgetScale = widgetData.scale;
      }
    }
  }

  onWidgetDataChanged: {
    if (!internal.isDragging && !internal.isScaling) {
      internal.baseX = (widgetData && widgetData.x !== undefined) ? widgetData.x : defaultX;
      internal.baseY = (widgetData && widgetData.y !== undefined) ? widgetData.y : defaultY;
      if (widgetData) {
        if (widgetData.scaleX !== undefined) {
          widgetScaleX = widgetData.scaleX;
        } else if (widgetData.scale !== undefined) {
          widgetScaleX = widgetData.scale;
        } else {
          widgetScaleX = 1.0;
        }

        if (widgetData.scaleY !== undefined) {
          widgetScaleY = widgetData.scaleY;
        } else if (widgetData.scale !== undefined) {
          widgetScaleY = widgetData.scale;
        } else {
          widgetScaleY = 1.0;
        }

        if (widgetData.scale !== undefined) {
          widgetScale = widgetData.scale;
        } else {
          widgetScale = 1.0;
        }
      }
    }
  }

  Rectangle {
    id: decorationRect
    anchors.fill: parent
    anchors.margins: -outlineMargin
    color: DesktopWidgetRegistry.editMode ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.1) : "transparent"
    border.color: (DesktopWidgetRegistry.editMode || internal.isDragging) ? (internal.isDragging ? Color.mOutline : Color.mPrimary) : "transparent"
    border.width: DesktopWidgetRegistry.editMode ? 3 : 0
    radius: Math.min(Math.round(Style.radiusL * root.widgetScale), Style.radiusL, width / 2, height / 2)
    z: -1
  }

  Rectangle {
    id: container
    anchors.fill: parent
    radius: root.roundedCorners ? Math.min(Math.round(Style.radiusL * root.widgetScale), Style.radiusL, width / 2, height / 2) : 0
    color: Qt.alpha(Color.mSurface, Settings.data.ui.panelBackgroundOpacity)
    border {
      width: 1
      color: Qt.alpha(Color.mOutline, 0.12)
    }
    clip: true
    visible: root.showBackground

    layer.enabled: Settings.data.general.enableShadows && !internal.isDragging && root.showBackground
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowBlur: Style.shadowBlur * 1.5
      shadowOpacity: Style.shadowOpacity * 0.6
      shadowColor: "black"
      shadowHorizontalOffset: Settings.data.general.shadowOffsetX
      shadowVerticalOffset: Settings.data.general.shadowOffsetY
      blurMax: Style.shadowBlurMax
    }
  }

  Item {
    id: contentContainer
    anchors.fill: parent
    z: 1
    clip: true
  }

  // Context menu model and handler - menu is created dynamically in PopupMenuWindow
  property var contextMenuModel: {
    var hasSettings = false;
    if (widgetData && widgetData.id) {
      var widgetId = widgetData.id;
      if (DesktopWidgetRegistry.isPluginWidget(widgetId)) {
        var pluginId = widgetId.replace("plugin:", "");
        var manifest = PluginRegistry.getPluginManifest(pluginId);
        hasSettings = manifest && manifest.entryPoints && (manifest.entryPoints.settings || manifest.entryPoints.desktopWidgetSettings);
      } else {
        hasSettings = DesktopWidgetRegistry.widgetSettingsMap[widgetId] !== undefined;
      }
    }

    var items = [];
    if (hasSettings) {
      items.push({
                   "label": I18n.tr("actions.widget-settings"),
                   "action": "widget-settings",
                   "icon": "settings"
                 });
    }
    items.push({
                 "label": I18n.tr("common.reset"),
                 "action": "reset",
                 "icon": "restore"
               });
    items.push({
                 "label": I18n.tr("actions.raise-to-top"),
                 "action": "raise-to-top",
                 "icon": "stack-front"
               });
    items.push({
                 "label": I18n.tr("actions.lower-to-bottom"),
                 "action": "lower-to-bottom",
                 "icon": "stack-back"
               });
    items.push({
                 "label": I18n.tr("common.delete"),
                 "action": "delete",
                 "icon": "trash"
               });
    return items;
  }

  // Drag MouseArea - handles dragging (left-click)
  MouseArea {
    id: dragArea
    anchors.fill: parent
    z: 1000
    visible: DesktopWidgetRegistry.editMode
    cursorShape: internal.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    property point pressPos: Qt.point(0, 0)

    onPressed: mouse => {
                 // Prevent starting new operation if one is already in progress
                 if (internal.operationType !== "") {
                   return;
                 }

                 pressPos = Qt.point(mouse.x, mouse.y);
                 internal.operationType = "drag";
                 internal.dragOffsetX = root.x;
                 internal.dragOffsetY = root.y;
                 internal.isDragging = true;
               }

    onPositionChanged: mouse => {
                         if (internal.isDragging && pressed && internal.operationType === "drag") {
                           var globalPressPos = mapToItem(root.parent, pressPos.x, pressPos.y);
                           var globalCurrentPos = mapToItem(root.parent, mouse.x, mouse.y);

                           var deltaX = globalCurrentPos.x - globalPressPos.x;
                           var deltaY = globalCurrentPos.y - globalPressPos.y;

                           var newX = internal.dragOffsetX + deltaX;
                           var newY = internal.dragOffsetY + deltaY;

                           // Boundary clamping - allow widgets to go partially off-screen (75% can clip)
                           // This gives users more control over positioning while keeping widgets accessible
                           var scaledWidth = root.width;
                           var scaledHeight = root.height;
                           if (root.parent && scaledWidth > 0 && scaledHeight > 0) {
                             var minVisibleX = scaledWidth * 0.25;
                             var minVisibleY = scaledHeight * 0.25;
                             newX = Math.max(-scaledWidth + minVisibleX, Math.min(newX, root.parent.width - minVisibleX));
                             newY = Math.max(-scaledHeight + minVisibleY, Math.min(newY, root.parent.height - minVisibleY));
                           }

                           if (Settings.data.desktopWidgets.gridSnap) {
                             newX = root.snapToGrid(newX);
                             newY = root.snapToGrid(newY);
                             // Re-clamp after snapping
                             if (root.parent && scaledWidth > 0 && scaledHeight > 0) {
                               var minVisibleX = scaledWidth * 0.25;
                               var minVisibleY = scaledHeight * 0.25;
                               newX = Math.max(-scaledWidth + minVisibleX, Math.min(newX, root.parent.width - minVisibleX));
                               newY = Math.max(-scaledHeight + minVisibleY, Math.min(newY, root.parent.height - minVisibleY));
                             }
                           }

                           internal.dragOffsetX = newX;
                           internal.dragOffsetY = newY;
                         }
                       }

    onReleased: mouse => {
                  if (internal.isDragging && internal.operationType === "drag" && widgetIndex >= 0 && screen && screen.name) {
                    var roundedX = Math.round(internal.dragOffsetX);
                    var roundedY = Math.round(internal.dragOffsetY);
                    root.updateWidgetData({
                                            "x": roundedX,
                                            "y": roundedY
                                          });

                    internal.baseX = roundedX;
                    internal.baseY = roundedY;
                    internal.isDragging = false;
                    internal.operationType = "";
                  }
                }

    onCanceled: {
      internal.isDragging = false;
      internal.operationType = "";
    }
  }

  // Right-click MouseArea for context menu
  MouseArea {
    id: contextMenuArea
    anchors.fill: parent
    z: 1001
    visible: DesktopWidgetRegistry.editMode
    acceptedButtons: Qt.RightButton
    hoverEnabled: true

    onPressed: mouse => {
                 if (mouse.button === Qt.RightButton) {
                   var popupMenuWindow = PanelService.getPopupMenuWindow(root.screen);
                   if (popupMenuWindow) {
                     // Map click position to screen coordinates
                     var globalPos = root.mapToItem(null, mouse.x, mouse.y);
                     // Use dynamic context menu (created in PopupMenuWindow's Top layer)
                     // This ensures input events work correctly for desktop widgets (Bottom layer)
                     popupMenuWindow.showDynamicContextMenu(root.contextMenuModel, globalPos.x, globalPos.y, root.handleContextMenuAction);
                   }
                 }
               }
  }

  // Corner handles for scaling - using Repeater to avoid code duplication
  readonly property real cornerHandleSize: 8 * widgetScale
  readonly property real outlineMargin: Style.marginS * widgetScale
  readonly property color colorHandle: Color.mSecondary

  // Corner handle model: defines position, direction, cursor, and triangle points for each corner
  // xMult/yMult: multipliers for position (0 = left/top edge, 1 = right/bottom edge)
  // xDir/yDir: direction multiplier for scaling (-1 = left/up increases, 1 = right/down increases)
  // cursor: resize cursor type (FDiag for TL-BR diagonal, BDiag for TR-BL diagonal)
  // points: triangle vertices as [x, y] pairs normalized to cornerHandleSize
  readonly property var cornerHandleModel: [
    {
      xMult: 0,
      yMult: 0,
      xDir: -1,
      yDir: -1,
      cursor: Qt.SizeFDiagCursor,
      points: [[0, 0], [1, 0], [0, 1]]
    },
    {
      xMult: 1,
      yMult: 0,
      xDir: 1,
      yDir: -1,
      cursor: Qt.SizeBDiagCursor,
      points: [[1, 0], [1, 1], [0, 0]]
    },
    {
      xMult: 0,
      yMult: 1,
      xDir: -1,
      yDir: 1,
      cursor: Qt.SizeBDiagCursor,
      points: [[0, 1], [0, 0], [1, 1]]
    },
    {
      xMult: 1,
      yMult: 1,
      xDir: 1,
      yDir: 1,
      cursor: Qt.SizeFDiagCursor,
      points: [[1, 1], [1, 0], [0, 1]]
    }
  ]

  Repeater {
    model: root.cornerHandleModel

    delegate: Canvas {
      id: cornerHandle
      required property var modelData
      required property int index

      visible: DesktopWidgetRegistry.editMode && !internal.isDragging
      // Position handles at corners of decoration rectangle (which extends by outlineMargin)
      x: modelData.xMult === 0 ? -outlineMargin : (root.width + outlineMargin - cornerHandleSize)
      y: modelData.yMult === 0 ? -outlineMargin : (root.height + outlineMargin - cornerHandleSize)
      width: cornerHandleSize
      height: cornerHandleSize
      z: 2000

      onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = colorHandle;
        ctx.beginPath();
        ctx.moveTo(modelData.points[0][0] * cornerHandleSize, modelData.points[0][1] * cornerHandleSize);
        ctx.lineTo(modelData.points[1][0] * cornerHandleSize, modelData.points[1][1] * cornerHandleSize);
        ctx.lineTo(modelData.points[2][0] * cornerHandleSize, modelData.points[2][1] * cornerHandleSize);
        ctx.closePath();
        ctx.fill();
      }

      Component.onCompleted: requestPaint()
      onVisibleChanged: if (visible)
                          requestPaint()

      Connections {
        target: root
        function onWidthChanged() {
          if (cornerHandle.visible)
            cornerHandle.requestPaint();
        }
        function onHeightChanged() {
          if (cornerHandle.visible)
            cornerHandle.requestPaint();
        }
      }

      MouseArea {
        id: scaleMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: cornerHandle.modelData.cursor
        property point pressPos: Qt.point(0, 0)

        onPressed: mouse => {
                     if (internal.operationType !== "") {
                       return;
                     }
                     pressPos = mapToItem(root.parent, mouse.x, mouse.y);
                     internal.operationType = "scale";
                     internal.isScaling = true;
                     internal.initialScale = root.widgetScale;
                     internal.initialScaleX = root.widgetScaleX;
                     internal.initialScaleY = root.widgetScaleY;
                     internal.lastScale = root.widgetScale;
                     internal.lastScaleX = root.widgetScaleX;
                     internal.lastScaleY = root.widgetScaleY;
                     internal.initialWidth = root.width;
                     internal.initialHeight = root.height;
                   }

        onPositionChanged: mouse => {
                             if (internal.isScaling && pressed && internal.operationType === "scale") {
                               var currentPos = mapToItem(root.parent, mouse.x, mouse.y);
                               var deltaX = currentPos.x - pressPos.x;
                               var deltaY = currentPos.y - pressPos.y;

                               // Project delta onto the diagonal direction for this corner
                               // xDir/yDir indicate which direction increases scale
                               var diagonalDelta = (deltaX * cornerHandle.modelData.xDir + deltaY * cornerHandle.modelData.yDir) / Math.sqrt(2);

                               // Scale sensitivity: pixels of drag per 1.0 scale change
                               var sensitivity = 150;
                               var scaleDelta = diagonalDelta / sensitivity;
                               
                               var initialScale = Math.max(internal.initialScaleX, internal.initialScaleY);
                               var newScale = Math.max(root.minScale, Math.min(root.maxScale, initialScale + scaleDelta));

                               newScale = root.snapScaleXToGrid(newScale);

                               if (!isNaN(newScale) && newScale > 0) {
                                 root.widgetScaleX = newScale;
                                 root.widgetScaleY = newScale;
                                 root.widgetScale = newScale;
                                 internal.lastScale = newScale;
                                 internal.lastScaleX = newScale;
                                 internal.lastScaleY = newScale;
                               }
                             }
                           }

        onReleased: mouse => {
                      if (internal.isScaling && internal.operationType === "scale") {
                        root.updateWidgetData({
                                                "scale": root.widgetScale,
                                                "scaleX": root.widgetScaleX,
                                                "scaleY": root.widgetScaleY
                                              });
                        internal.isScaling = false;
                        internal.operationType = "";
                        var snappedX = root.snapScaleXToGrid(root.widgetScaleX);
                        var snappedY = root.snapScaleYToGrid(root.widgetScaleY);
                        root.widgetScaleX = snappedX;
                        root.widgetScaleY = snappedY;
                        root.widgetScale = (snappedX + snappedY) / 2;
                        internal.lastScale = root.widgetScale;
                        internal.lastScaleX = snappedX;
                        internal.lastScaleY = snappedY;
                      }
                    }

        onCanceled: {
          internal.isScaling = false;
          internal.operationType = "";
          internal.lastScale = root.widgetScale;
          internal.lastScaleX = root.widgetScaleX;
          internal.lastScaleY = root.widgetScaleY;
        }
      }
    }
  }

  // Side handles for scaling horizontally and vertically separately
  Repeater {
    model: 4 // Four sides

    delegate: Rectangle {
      id: sideHandle
      visible: DesktopWidgetRegistry.editMode && !internal.isDragging
      
      // Determine values based on index
      // 0: Left, 1: Right, 2: Top, 3: Bottom
      readonly property int side: index
      
      x: {
        if (side === 0) return -outlineMargin;
        if (side === 1) return root.width + outlineMargin - cornerHandleSize;
        return outlineMargin;
      }
      
      y: {
        if (side === 2) return -outlineMargin;
        if (side === 3) return root.height + outlineMargin - cornerHandleSize;
        return outlineMargin;
      }
      
      width: (side === 0 || side === 1) ? cornerHandleSize : (root.width - outlineMargin * 2)
      height: (side === 2 || side === 3) ? cornerHandleSize : (root.height - outlineMargin * 2)
      
      color: "transparent"
      z: 1999

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: (sideHandle.side === 0 || sideHandle.side === 1) ? Qt.SizeHorCursor : Qt.SizeVerCursor
        property point pressPos: Qt.point(0, 0)

        onPressed: mouse => {
                     if (internal.operationType !== "") {
                       return;
                     }
                     pressPos = mapToItem(root.parent, mouse.x, mouse.y);
                     internal.operationType = "scale";
                     internal.isScaling = true;
                     internal.initialScaleX = root.widgetScaleX;
                     internal.initialScaleY = root.widgetScaleY;
                     internal.initialWidth = root.width;
                     internal.initialHeight = root.height;
                   }

        onPositionChanged: mouse => {
                             if (internal.isScaling && pressed && internal.operationType === "scale") {
                               var currentPos = mapToItem(root.parent, mouse.x, mouse.y);
                               var deltaX = currentPos.x - pressPos.x;
                               var deltaY = currentPos.y - pressPos.y;

                               var sensitivity = 150;
                               if (sideHandle.side === 0 || sideHandle.side === 1) {
                                 var xDir = (sideHandle.side === 0) ? -1 : 1;
                                 var scaleDeltaX = (deltaX * xDir) / sensitivity;
                                 var newScaleX = Math.max(root.minScale, Math.min(root.maxScale, internal.initialScaleX + scaleDeltaX));
                                 newScaleX = root.snapScaleXToGrid(newScaleX);
                                 if (!isNaN(newScaleX) && newScaleX > 0) {
                                   root.widgetScaleX = newScaleX;
                                 }
                               } else {
                                 var yDir = (sideHandle.side === 2) ? -1 : 1;
                                 var scaleDeltaY = (deltaY * yDir) / sensitivity;
                                 var newScaleY = Math.max(root.minScale, Math.min(root.maxScale, internal.initialScaleY + scaleDeltaY));
                                 newScaleY = root.snapScaleYToGrid(newScaleY);
                                 if (!isNaN(newScaleY) && newScaleY > 0) {
                                   root.widgetScaleY = newScaleY;
                                 }
                               }
                             }
                           }

        onReleased: mouse => {
                      if (internal.isScaling && internal.operationType === "scale") {
                        root.updateWidgetData({
                                                "scaleX": root.widgetScaleX,
                                                "scaleY": root.widgetScaleY
                                              });
                        internal.isScaling = false;
                        internal.operationType = "";
                      }
                    }

        onCanceled: {
          internal.isScaling = false;
          internal.operationType = "";
        }
      }
    }
  }
}
