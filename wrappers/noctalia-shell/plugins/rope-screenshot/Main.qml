import QtQuick
import QtCore
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property var activeOverlay: null
    property var pendingFreezeScreen: null
    property var pendingSelection: null
    property string pendingFreezePath: ""
    property bool previewReady: false
    property bool selectionAccepted: false
    property bool freezeFileReady: false
    property bool captureStarted: false
    property bool captureFinished: false
    property bool ignoreFreezeResult: false
    property string freezeErrorText: ""
    property string captureErrorText: ""

    readonly property bool overlayVisible: activeOverlay !== null
    readonly property bool busy: overlayVisible || freezeProcess.running || captureProcess.running || selectionAccepted

    function clearOverlay(overlay) {
        if (activeOverlay === overlay) {
            activeOverlay = null;
        }
    }

    function resetFlow() {
        pendingFreezeScreen = null;
        pendingSelection = null;
        pendingFreezePath = "";
        previewReady = false;
        selectionAccepted = false;
        freezeFileReady = false;
        captureStarted = false;
        captureFinished = false;
        ignoreFreezeResult = false;
        freezeErrorText = "";
        captureErrorText = "";
    }

    function abortFlow() {
        if (freezeProcess.running) {
            ignoreFreezeResult = true;
        }

        cleanupFrozenFrame(pendingFreezePath);
        pendingFreezeScreen = null;
        pendingSelection = null;
        pendingFreezePath = "";
        previewReady = false;
        selectionAccepted = false;
        freezeFileReady = false;
        captureStarted = false;
        captureFinished = false;
        freezeErrorText = "";
        captureErrorText = "";
    }

    function appendError(existingText, data) {
        var trimmed = (data || "").trim();
        if (trimmed.length === 0) {
            return existingText;
        }

        return existingText.length > 0 ? existingText + "\n" + trimmed : trimmed;
    }

    function normalizeLocalPath(path) {
        var text = (path || "").toString();
        if (text.indexOf("file://") === 0) {
            return text.slice(7);
        }

        return text;
    }

    function makeFreezePath() {
        var runtimeDir = normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.RuntimeLocation));
        if (!runtimeDir || runtimeDir.length === 0) {
            runtimeDir = normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.TempLocation));
        }

        var suffix = Date.now().toString() + "-" + Math.floor(Math.random() * 1000000).toString();
        return runtimeDir + "/rope-screenshot-freeze-" + suffix + ".png";
    }

    function runCapture(args) {
        if (captureProcess.running) {
            return false;
        }

        captureErrorText = "";
        captureProcess.command = [pluginApi.pluginDir + "/capture.sh"].concat(args || []);
        captureProcess.running = true;
        return true;
    }

    function maybeStartPendingCapture() {
        if (
            captureStarted
            || captureProcess.running
            || !selectionAccepted
            || !freezeFileReady
            || !pendingSelection
            || pendingFreezePath.length === 0
        ) {
            return false;
        }

        captureStarted = true;
        captureFinished = false;

        if (!runCapture([
            "region-frozen",
            pendingFreezePath,
            pendingSelection.localGeometry,
            String(pendingSelection.scaleX),
            String(pendingSelection.scaleY),
        ])) {
            captureStarted = false;
            return false;
        }

        return true;
    }

    function cleanupFrozenFrame(path) {
        if (!path || cleanupProcess.running) {
            return;
        }

        cleanupProcess.command = [pluginApi.pluginDir + "/capture.sh", "cleanup", path];
        cleanupProcess.running = true;
    }

    function openRegionSelector(screen, frozenImagePath) {
        if (!screen || activeOverlay) {
            return null;
        }

        var overlay = selectionOverlay.createObject(null, {
            targetScreen: screen,
            frozenImagePath: frozenImagePath || "",
        });

        if (!overlay) {
            cleanupFrozenFrame(frozenImagePath);
            ToastService.showError("Screenshot", "Failed to open the region selector.", 3000);
            return null;
        }

        activeOverlay = overlay;
        previewReady = overlay.previewReady;

        overlay.previewReadyChanged.connect(function () {
            if (root.activeOverlay === overlay) {
                root.previewReady = overlay.previewReady;
            }
        });

        overlay.accepted.connect(function (selection) {
            clearOverlay(overlay);
            root.previewReady = false;
            root.selectionAccepted = true;
            root.pendingSelection = selection;
            root.maybeStartPendingCapture();
        });

        overlay.canceled.connect(function () {
            clearOverlay(overlay);
            root.abortFlow();
        });

        return overlay;
    }

    function beginFrozenRegionSelection(screen) {
        if (!screen || busy) {
            return false;
        }

        resetFlow();

        var overlay = openRegionSelector(screen, "");
        if (!overlay) {
            resetFlow();
            return false;
        }

        pendingFreezeScreen = screen;
        pendingFreezePath = makeFreezePath();
        freezeErrorText = "";
        freezeProcess.command = [pluginApi.pluginDir + "/capture.sh", "freeze", screen.name, pendingFreezePath];
        freezeProcess.running = true;
        return true;
    }

    function takeScreenshot(mode) {
        if (!pluginApi) {
            return false;
        }

        var normalizedMode = (mode || "region").toLowerCase();

        if (activeOverlay) {
            activeOverlay.cancelSelection();
            return false;
        }

        if (captureProcess.running || freezeProcess.running || selectionAccepted) {
            return false;
        }

        if (normalizedMode === "screen" || normalizedMode === "fullscreen" || normalizedMode === "output") {
            return runCapture(["screen"]);
        }

        pluginApi.withCurrentScreen(function (screen) {
            beginFrozenRegionSelection(screen);
        });

        return true;
    }

    Process {
        id: freezeProcess

        stderr: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                root.freezeErrorText = root.appendError(root.freezeErrorText, data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            var screen = root.pendingFreezeScreen;
            var frozenPath = root.pendingFreezePath;
            var overlay = root.activeOverlay;
            var shouldIgnore = root.ignoreFreezeResult;
            var freezeMessage = root.freezeErrorText;

            root.pendingFreezeScreen = null;
            root.ignoreFreezeResult = false;

            if (shouldIgnore) {
                root.cleanupFrozenFrame(frozenPath);
                root.pendingFreezePath = "";
                root.freezeFileReady = false;
                return;
            }

            if (exitCode === 0 && screen && frozenPath.length > 0) {
                root.freezeFileReady = true;

                if (overlay && overlay.targetScreen === screen) {
                    overlay.frozenImagePath = frozenPath;
                } else if (!root.selectionAccepted) {
                    root.cleanupFrozenFrame(frozenPath);
                    root.resetFlow();
                    return;
                }

                root.maybeStartPendingCapture();
            } else {
                root.cleanupFrozenFrame(frozenPath);
                root.pendingFreezePath = "";
                root.freezeFileReady = false;

                if (overlay) {
                    overlay.cancelSelection();
                } else {
                    root.resetFlow();
                }

                ToastService.showError(
                    "Screenshot",
                    freezeMessage.length > 0 ? freezeMessage : "Failed to freeze the screen.",
                    5000
                );
            }
        }
    }

    Process {
        id: captureProcess

        stderr: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                root.captureErrorText = root.appendError(root.captureErrorText, data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            var frozenPath = root.pendingFreezePath;

            root.captureFinished = true;
            root.cleanupFrozenFrame(frozenPath);

            if (exitCode === 0) {
                ToastService.showNotice("Screenshot", "Copied to the clipboard and saved to Pictures/Screenshots.", "camera", 3000);
            } else {
                ToastService.showError(
                    "Screenshot",
                    root.captureErrorText.length > 0 ? root.captureErrorText : "Capture failed.",
                    5000
                );
            }

            root.resetFlow();
        }
    }

    Process {
        id: cleanupProcess
    }

    IpcHandler {
        target: "plugin:rope-screenshot"

        function takeScreenshot(mode: string): bool {
            return root.takeScreenshot(mode);
        }

        function cancel(): bool {
            if (!root.activeOverlay) {
                return false;
            }

            root.activeOverlay.cancelSelection();
            return true;
        }
    }

    Component {
        id: selectionOverlay

        SelectionOverlay {
        }
    }
}
