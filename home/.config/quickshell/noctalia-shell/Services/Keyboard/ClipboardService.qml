pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// Clipboard history service using cliphist + local content cache
Singleton {
  id: root

  // Public API
  property bool active: Settings.data.appLauncher.enableClipboardHistory && cliphistAvailable
  property bool loading: false
  property var items: [] // [{id, preview, mime, isImage}]

  // Check if cliphist is available on the system
  property bool cliphistAvailable: false
  property bool dependencyChecked: false

  // Optional automatic watchers to feed cliphist DB
  property bool autoWatch: true
  property bool watchersStarted: false

  // Expose decoded thumbnails by id and a revision to notify bindings
  property var imageDataById: ({})
  property var _imageDataInsertOrder: [] // insertion-order IDs for LRU eviction
  readonly property int _imageDataMaxEntries: 20 // max decoded images held in RAM at once
  property int revision: 0

  // Local content cache - stores full text content by ID
  // This avoids relying on cliphist decode which can be unreliable
  property var contentCache: ({})

  // Track the most recent clipboard content for instant access
  property string _latestTextContent: ""
  property string _latestTextId: ""

  // Approximate first-seen timestamps for entries this session (seconds)
  property var firstSeenById: ({})

  readonly property string pinnedFilePath: Settings.configDir + "pinned_clipboard.json"
  property var pinnedItems: [] // [{id, originalId, preview, mime, isImage, contentType, content}]

  FileView {
    id: pinnedFileView
    path: root.pinnedFilePath
    watchChanges: true
    printErrors: false

    adapter: JsonAdapter {
      id: pinnedAdapter
      property var pinnedItems: []
    }

    onLoaded: {
      try {
        const parsed = JSON.parse(pinnedFileView.text());
        root.pinnedItems = Array.isArray(parsed.pinnedItems) ? parsed.pinnedItems : [];
      } catch (e) {
        root.pinnedItems = [];
      }
    }

    onLoadFailed: function (error) {
      root.pinnedItems = [];
    }
  }

  function savePinned() {
    Quickshell.execDetached(["mkdir", "-p", Settings.configDir]);
    pinnedAdapter.pinnedItems = root.pinnedItems;
    pinnedFileView.writeAdapter();
  }

  // Check if an item is currently pinned
  function isPinned(item) {
    if (!item) return false;
    const itemOriginalId = String(item.clipboardId || item.id);
    for (let i = 0; i < root.pinnedItems.length; i++) {
      let p = root.pinnedItems[i];
      if (p.originalId === itemOriginalId) {
        return true;
      }
      if (!p.isImage && !item.isImage && p.preview === item.preview) {
        return true;
      }
    }
    return false;
  }

  // Toggle pinning of an item
  function togglePin(item) {
    if (!item) return;
    const itemOriginalId = String(item.clipboardId || item.id);
    
    // Check if already pinned
    let pinIdx = -1;
    for (let i = 0; i < root.pinnedItems.length; i++) {
      let p = root.pinnedItems[i];
      if (p.originalId === itemOriginalId || (!p.isImage && !item.isImage && p.preview === item.preview)) {
        pinIdx = i;
        break;
      }
    }

    if (pinIdx !== -1) {
      // Unpin
      root.pinnedItems.splice(pinIdx, 1);
      root.pinnedItems = root.pinnedItems;
      savePinned();
      list();
    } else {
      // Pin
      if (item.isImage) {
        root.decodeToDataUrl(itemOriginalId, item.mime, function(dataUrl) {
          if (!dataUrl) return;
          const newPin = {
            "id": "pinned_" + Date.now(),
            "originalId": itemOriginalId,
            "preview": item.preview,
            "isImage": true,
            "mime": item.mime,
            "contentType": item.contentType || "image",
            "content": dataUrl
          };
          root.pinnedItems.push(newPin);
          root.pinnedItems = root.pinnedItems;
          savePinned();
          list();
        });
      } else {
        root.decode(itemOriginalId, function(content) {
          const newPin = {
            "id": "pinned_" + Date.now(),
            "originalId": itemOriginalId,
            "preview": item.preview,
            "isImage": false,
            "mime": item.mime || "text/plain",
            "contentType": item.contentType || "text",
            "content": content || item.preview
          };
          root.pinnedItems.push(newPin);
          root.pinnedItems = root.pinnedItems;
          savePinned();
          list();
        });
      }
    }
  }

  // Internal: store callback for decode
  property var _decodeCallback: null
  property int _decodeRequestId: 0

  // Queue for base64 decodes
  property var _b64Queue: []
  property var _b64CurrentCb: null
  property string _b64CurrentMime: ""
  property string _b64CurrentId: ""

  signal listCompleted

  // Check if cliphist is available
  Component.onCompleted: {
    checkCliphistAvailability();
  }

  // Check dependency availability
  function checkCliphistAvailability() {
    if (dependencyChecked)
      return;
    dependencyCheckProcess.command = ["sh", "-c", "command -v cliphist"];
    dependencyCheckProcess.running = true;
  }

  // Process to check if cliphist is available
  Process {
    id: dependencyCheckProcess
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      root.dependencyChecked = true;
      if (exitCode === 0) {
        root.cliphistAvailable = true;
        // Start watchers if feature is enabled
        if (root.active) {
          startWatchers();
        }
      } else {
        root.cliphistAvailable = false;
        // Show toast notification if feature is enabled but cliphist is missing
        if (Settings.data.appLauncher.enableClipboardHistory) {
          ToastService.showWarning(I18n.tr("toast.clipboard.unavailable"), I18n.tr("toast.clipboard.unavailable-desc"), 6000);
        }
      }
    }
  }

  // Start/stop watchers when enabled changes
  onActiveChanged: {
    if (root.active) {
      startWatchers();
    } else {
      stopWatchers();
      loading = false;
      items = [];
    }
  }

  // Fallback: periodically refresh list so UI updates even if not in clip mode
  Timer {
    interval: 5000
    repeat: true
    running: root.active
    onTriggered: list()
  }

  // Internal process objects
  Process {
    id: listProc
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      const out = String(stdout.text);
      const lines = out.split('\n').filter(l => l.length > 0);
      // cliphist list default format: "<id> <preview>" or "<id>\t<preview>"
      const parsed = lines.map((l, i) => {
                                 let id = "";
                                 let preview = "";
                                 const m = l.match(/^(\d+)\s+(.+)$/);
                                 if (m) {
                                   id = m[1];
                                   preview = m[2];
                                 } else {
                                   const tab = l.indexOf('\t');
                                   id = tab > -1 ? l.slice(0, tab) : l;
                                   preview = tab > -1 ? l.slice(tab + 1) : "";
                                 }
                                 const lower = preview.toLowerCase();
                                 const isImage = lower.startsWith("[image]") || lower.includes(" binary data ");
                                 // Best-effort mime guess from preview
                                 var mime = "text/plain";
                                 if (isImage) {
                                   if (lower.includes(" png"))
                                   mime = "image/png";
                                   else if (lower.includes(" jpg") || lower.includes(" jpeg"))
                                   mime = "image/jpeg";
                                   else if (lower.includes(" webp"))
                                   mime = "image/webp";
                                   else if (lower.includes(" gif"))
                                   mime = "image/gif";
                                   else
                                   mime = "image/*";
                                 }
                                 // Record first seen time for new ids (approximate copy time)
                                 if (!root.firstSeenById[id]) {
                                   const assumedAge = i * 15 * 60;
                                   root.firstSeenById[id] = Time.timestamp - assumedAge;
                                 }
                                 // Smart type detection
                                 var contentType = "text";
                                 if (isImage) {
                                   contentType = "image";
                                 } else {
                                   const t = preview.trim();
                                   const tLower = t.toLowerCase();
                                   if (/^#([a-f0-9]{3}|[a-f0-9]{6}|[a-f0-9]{8})$/.test(tLower)) {
                                     contentType = "color";
                                   } else if (/^https?:\/\//i.test(t)) {
                                     contentType = "link";
                                   } else if (/^(\/|~\/|file:\/\/)/i.test(t) && !t.startsWith('//') && !t.includes('\n')) {
                                     contentType = "file";
                                   } else if ((t.includes('{') && t.includes('}') && (t.includes(';') || t.includes('='))) || t.includes('</') || t.includes('/>') || t.includes('=>') || t.includes('===') || t.includes('!==') || t.includes('::') || t.includes('->') ||
                                              /^(?:const|let|var|function|class|struct|interface|type|enum|import|export|func|fn|pub|def|using|namespace|property|public|private|protected)\b/i.test(t) || /^(?:#include|#define|#\[|@|\/\/|\/\*|<\?|<html|<body|<!DOCTYPE)/i.test(t) || /\b(?:require\(|module\.exports)\b/i.test(t)) {
                                     contentType = "code";
                                   }
                                 }

                                 return {
                                   "id": id,
                                   "preview": preview,
                                   "isImage": isImage,
                                   "mime": mime,
                                   "contentType": contentType
                                 };
                               });

      // Filter out browser junk when copying images
      const filtered = parsed.filter(item => {
                                       if (item.isImage)
                                       return true;
                                       const p = item.preview;
                                       // Skip UTF-16 encoded text (has null bytes between chars), chromium browser artifact
                                       const nullCount = (p.match(/\x00/g) || []).length;
                                       if (nullCount > p.length * 0.2)
                                       return false;
                                       // Skip browser-generated HTML wrapper, firefox
                                       if (p.toLowerCase().startsWith("<meta http-equiv="))
                                       return false;
                                       return true;
                                     });

      // Merge pinned items at the top
      const finalItems = [];
      root.pinnedItems.forEach(p => {
        finalItems.push({
          "id": p.id,
          "preview": p.preview,
          "isImage": p.isImage,
          "mime": p.mime,
          "contentType": p.contentType,
          "isPinned": true
        });
      });

      filtered.forEach(item => {
        // Check if item is already pinned (by originalId or content)
        let alreadyPinned = false;
        for (let i = 0; i < root.pinnedItems.length; i++) {
          let p = root.pinnedItems[i];
          if (p.originalId === String(item.id) || (!p.isImage && !item.isImage && p.preview === item.preview)) {
            alreadyPinned = true;
            break;
          }
        }
        if (!alreadyPinned) {
          finalItems.push({
            "id": item.id,
            "preview": item.preview,
            "isImage": item.isImage,
            "mime": item.mime,
            "contentType": item.contentType,
            "isPinned": false
          });
        }
      });

      items = finalItems;
      loading = false;

      // Try to capture current clipboard and associate with newest item
      if (filtered.length > 0 && !filtered[0].isImage && !root.contentCache[filtered[0].id]) {
        root.captureCurrentClipboard();
      }

      root.listCompleted();
    }
  }

  Process {
    id: decodeProc
    property int requestId: 0
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (requestId === root._decodeRequestId && root._decodeCallback) {
        const out = String(stdout.text);
        try {
          root._decodeCallback(out);
        } finally {
          root._decodeCallback = null;
        }
      }
    }
  }

  Process {
    id: copyProc
    stdout: StdioCollector {}
  }

  Process {
    id: pasteProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      Logger.d("ClipboardService", `pasteProc command: ${command.join(" ")}`);
      Logger.d("ClipboardService", `pasteProc exited with code: ${exitCode}, status: ${exitStatus}`);
      if (exitCode !== 0) {
        Logger.e("ClipboardService", `pasteProc stderr: ${stderr.text}`);
      }
    }
  }

  Process {
    id: deleteProc
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      revision++;
      Qt.callLater(() => list());
    }
  }

  // Base64 decode pipeline (queued)
  Process {
    id: decodeB64Proc
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      const b64 = String(stdout.text).trim();
      if (root._b64CurrentCb) {
        const url = `data:${root._b64CurrentMime};base64,${b64}`;
        try {
          root._b64CurrentCb(url);
        } catch (e) {}
      }
      if (root._b64CurrentId !== "") {
        const entryId = root._b64CurrentId;
        root.imageDataById[entryId] = `data:${root._b64CurrentMime};base64,${b64}`;
        // Track insertion order and evict oldest entries beyond the cap
        root._imageDataInsertOrder.push(entryId);
        while (root._imageDataInsertOrder.length > root._imageDataMaxEntries) {
          const evicted = root._imageDataInsertOrder.shift();
          delete root.imageDataById[evicted];
        }
        root.revision += 1;
      }
      root._b64CurrentCb = null;
      root._b64CurrentMime = "";
      root._b64CurrentId = "";
      Qt.callLater(root._startNextB64);
    }
  }

  // Text watcher - stores to cliphist and triggers content capture
  Process {
    id: watchText
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (root.autoWatch && root.watchersStarted && Settings.data.appLauncher.clipboardWatchTextCommand.trim() !== "") {
        watchTextRestartTimer.restart();
      }
    }
  }

  Timer {
    id: watchTextRestartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (root.autoWatch && root.watchersStarted)
      watchText.running = true;
    }
  }

  // Image watcher
  Process {
    id: watchImage
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (root.autoWatch && root.watchersStarted && Settings.data.appLauncher.clipboardWatchImageCommand.trim() !== "") {
        watchImageRestartTimer.restart();
      }
    }
  }

  Timer {
    id: watchImageRestartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (root.autoWatch && root.watchersStarted)
      watchImage.running = true;
    }
  }

  // Capture current clipboard text when needed
  Process {
    id: captureTextProc
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        const content = String(stdout.text);
        if (content.length > 0) {
          root._latestTextContent = content;
          // Associate with newest item if we have one
          if (root.items.length > 0 && !root.items[0].isImage) {
            const newestId = root.items[0].id;
            if (!root.contentCache[newestId]) {
              root.contentCache[newestId] = content;
              root.revision++;
            }
          }
        }
      }
    }
  }

  function startWatchers() {
    if (!root.active || !autoWatch || watchersStarted || !root.cliphistAvailable)
      return;
    watchersStarted = true;

    // Text watcher
    watchText.command = ["sh", "-c", Settings.data.appLauncher.clipboardWatchTextCommand];
    watchText.running = true;

    // Image watcher
    watchImage.command = ["sh", "-c", Settings.data.appLauncher.clipboardWatchImageCommand];
    watchImage.running = true;
  }

  function stopWatchers() {
    if (!watchersStarted)
      return;
    watchText.running = false;
    watchImage.running = false;
    watchersStarted = false;
  }

  // Capture current clipboard text and cache it
  function captureCurrentClipboard() {
    if (captureTextProc.running)
      return;
    captureTextProc.command = ["wl-paste", "--no-newline"];
    captureTextProc.running = true;
  }

  function list(maxPreviewWidth) {
    if (!root.active || !root.cliphistAvailable) {
      return;
    }
    if (listProc.running)
      return;
    loading = true;
    const width = maxPreviewWidth || 100;
    listProc.command = ["cliphist", "list", "-preview-width", String(width)];
    listProc.running = true;
  }

  // Get content for an ID - uses cache first, falls back to cliphist decode
  function getContent(id) {
    const idStr = String(id);
    if (idStr.startsWith("pinned_")) {
      let pin = root.pinnedItems.find(p => p.id === idStr);
      return pin ? pin.content : null;
    }
    if (root.contentCache[id]) {
      return root.contentCache[id];
    }
    return null;
  }

  // Async decode - checks cache first, then falls back to cliphist
  function decode(id, cb) {
    const idStr = String(id);
    if (idStr.startsWith("pinned_")) {
      let pin = root.pinnedItems.find(p => p.id === idStr);
      if (cb) cb(pin ? pin.content : "");
      return;
    }

    if (!root.cliphistAvailable) {
      if (cb)
        cb("");
      return;
    }

    // Check cache first
    const cached = root.contentCache[id];
    if (cached) {
      if (cb)
        cb(cached);
      return;
    }

    // Fall back to cliphist decode
    if (decodeProc.running) {
      decodeProc.running = false;
    }
    root._decodeRequestId++;
    decodeProc.requestId = root._decodeRequestId;
    root._decodeCallback = function (content) {
      // Cache the result if successful
      if (content && content.trim()) {
        root.contentCache[id] = content;
      }
      if (cb)
        cb(content);
    };
    decodeProc.command = ["cliphist", "decode", idStr];
    decodeProc.running = true;
  }

  function decodeToDataUrl(id, mime, cb) {
    const idStr = String(id);
    if (idStr.startsWith("pinned_")) {
      let pin = root.pinnedItems.find(p => p.id === idStr);
      if (cb) cb(pin ? pin.content : "");
      return;
    }

    if (!root.cliphistAvailable) {
      if (cb)
        cb("");
      return;
    }
    // If cached, return immediately
    if (root.imageDataById[id]) {
      if (cb)
        cb(root.imageDataById[id]);
      return;
    }
    // Queue request; ensures single process handles sequentially
    root._b64Queue.push({
                          "id": id,
                          "mime": mime || "image/*",
                          "cb": cb
                        });
    if (!decodeB64Proc.running && root._b64CurrentCb === null) {
      _startNextB64();
    }
  }

  function getImageData(id) {
    if (id === undefined) {
      return null;
    }
    const idStr = String(id);
    if (idStr.startsWith("pinned_")) {
      let pin = root.pinnedItems.find(p => p.id === idStr);
      return pin ? pin.content : null;
    }
    return root.imageDataById[id];
  }

  function _startNextB64() {
    if (root._b64Queue.length === 0 || !root.cliphistAvailable)
      return;
    const job = root._b64Queue.shift();
    root._b64CurrentCb = job.cb;
    root._b64CurrentMime = job.mime;
    root._b64CurrentId = job.id;
    decodeB64Proc.command = ["sh", "-c", `cliphist decode ${job.id} | base64 -w 0`];
    decodeB64Proc.running = true;
  }

  function copyToClipboard(id) {
    if (!root.cliphistAvailable) {
      return;
    }
    const idStr = String(id);
    if (idStr.startsWith("pinned_")) {
      let pin = root.pinnedItems.find(p => p.id === idStr);
      if (pin) {
        if (pin.isImage) {
          const parts = pin.content.split(",");
          const b64 = parts[1] || "";
          const typeArg = pin.mime ? ` --type ${pin.mime}` : "";
          copyProc.command = ["sh", "-c", `echo -n '${b64}' | base64 -d | wl-copy${typeArg}`];
        } else {
          const escaped = pin.content.replace(/'/g, "'\\''");
          copyProc.command = ["sh", "-c", `printf '%s' '${escaped}' | wl-copy`];
        }
        copyProc.running = true;
        return;
      }
    }
    copyProc.command = ["sh", "-c", `cliphist decode ${id} | wl-copy`];
    copyProc.running = true;
  }

  function pasteFromClipboard(id, mime) {
    if (!root.cliphistAvailable) {
      return;
    }
    const idStr = String(id);
    const isImage = mime && mime.startsWith("image/");
    const typeArg = isImage ? ` --type ${mime}` : "";
    const pasteKeys = isImage ? "sleep 0.15 && wtype -M ctrl -k v" : "sleep 0.15 && wtype -M ctrl v";

    if (idStr.startsWith("pinned_")) {
      let pin = root.pinnedItems.find(p => p.id === idStr);
      if (pin) {
        let copyCmd = "";
        if (pin.isImage) {
          const parts = pin.content.split(",");
          const b64 = parts[1] || "";
          copyCmd = `echo -n '${b64}' | base64 -d | wl-copy${typeArg}`;
        } else {
          const escaped = pin.content.replace(/'/g, "'\\''");
          copyCmd = `printf '%s' '${escaped}' | wl-copy`;
        }
        pasteProc.command = ["sh", "-c", `${copyCmd} && ${pasteKeys}`];
        pasteProc.running = true;
        return;
      }
    }

    const cmd = `cliphist decode ${id} | wl-copy${typeArg} && ${pasteKeys}`;
    pasteProc.command = ["sh", "-c", cmd];
    pasteProc.running = true;
  }

  function pasteText(text) {
    if (!text)
      return;
    const escaped = text.replace(/'/g, "'\\''");
    const cmd = `printf '%s' '${escaped}' | wl-copy && sleep 0.15 && wtype -M ctrl v`;
    pasteProc.command = ["sh", "-c", cmd];
    pasteProc.running = true;
  }

  function deleteById(id) {
    if (!root.cliphistAvailable) {
      return;
    }
    const idStr = String(id).trim();
    if (idStr.startsWith("pinned_")) {
      let pinIdx = root.pinnedItems.findIndex(p => p.id === idStr);
      if (pinIdx !== -1) {
        root.pinnedItems.splice(pinIdx, 1);
        root.pinnedItems = root.pinnedItems;
        savePinned();
        revision++;
        Qt.callLater(() => list());
      }
      return;
    }
    if (deleteProc.running) {
      return;
    }
    // Remove from caches
    delete root.contentCache[idStr];
    delete root.imageDataById[idStr];
    const orderIdx = root._imageDataInsertOrder.indexOf(idStr);
    if (orderIdx !== -1)
      root._imageDataInsertOrder.splice(orderIdx, 1);
    deleteProc.command = ["sh", "-c", `echo ${idStr} | cliphist delete`];
    deleteProc.running = true;
  }

  function wipeAll() {
    if (!root.cliphistAvailable) {
      return;
    }
    // Clear caches
    root.contentCache = {};
    root.imageDataById = {};
    root._imageDataInsertOrder = [];
    root._latestTextContent = "";
    root._latestTextId = "";

    Quickshell.execDetached(["cliphist", "wipe"]);
    revision++;
    Qt.callLater(() => list());
  }

  // Parse image metadata from cliphist preview string
  function parseImageMeta(preview) {
    const re = /\[\[\s*binary data\s+([\d\.]+\s*(?:KiB|MiB|GiB|B))\s+(\w+)\s+(\d+)x(\d+)\s*\]\]/i;
    const match = (preview || "").match(re);
    if (!match)
      return null;
    return {
      "size": match[1],
      "fmt": (match[2] || "").toUpperCase(),
      "w": Number(match[3]),
      "h": Number(match[4])
    };
  }

  IpcHandler {
    target: "clipboard"

    function togglePin(id: string) {
      const idStr = String(id).trim();
      if (idStr.startsWith("pinned_")) {
        let pin = root.pinnedItems.find(p => p.id === idStr);
        if (pin) {
          root.togglePin({ "clipboardId": pin.id, "id": pin.id, "isImage": pin.isImage, "mime": pin.mime, "preview": pin.preview });
        }
      } else {
        let item = root.items.find(i => String(i.id) === idStr);
        if (item) {
          root.togglePin({ "clipboardId": item.id, "id": item.id, "isImage": item.isImage, "mime": item.mime, "preview": item.preview });
        }
      }
    }

    function pin(id: string) {
      const idStr = String(id).trim();
      let item = root.items.find(i => String(i.id) === idStr);
      if (item && !root.isPinned(item)) {
        root.togglePin({ "clipboardId": item.id, "id": item.id, "isImage": item.isImage, "mime": item.mime, "preview": item.preview });
      }
    }

    function unpin(id: string) {
      const idStr = String(id).trim();
      let item = root.items.find(i => String(i.id) === idStr);
      if (item && root.isPinned(item)) {
        root.togglePin({ "clipboardId": item.id, "id": item.id, "isImage": item.isImage, "mime": item.mime, "preview": item.preview });
      }
    }

    function listPinned(): string {
      return JSON.stringify(root.pinnedItems.map(p => ({
        id: p.id,
        originalId: p.originalId,
        mime: p.mime,
        isImage: p.isImage,
        contentType: p.contentType,
        preview: p.preview,
        content: p.contentType === "image" ? "" : p.content
      })));
    }
  }
}
