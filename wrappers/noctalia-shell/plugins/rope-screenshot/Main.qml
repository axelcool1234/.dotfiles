import QtQuick
import QtCore
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// This controller owns the screenshot state machine.
//
// The region flow intentionally happens in three phases:
// 1. Freeze the current output into a temporary PNG.
// 2. Let the overlay select a rectangle against that frozen image.
// 3. Crop the frozen image in a helper script and save the final PNG.
//
// Splitting the work this way keeps the selection UI visually stable and avoids
// compositor timing issues where the overlay itself leaks into the first frame.
Item {
    id: root

    // `pluginApi` is provided by Noctalia when the plugin is instantiated.
    property var pluginApi: null

    // `activeOverlay` is the currently visible selector window, if any.
    property var activeOverlay: null

    // These fields describe the in-flight region capture, not a completed shot.
    property var pendingFreezeScreen: null
    property var pendingSelection: null
    property string pendingFreezePath: ""

    // The booleans below are deliberately explicit. This flow has a few async
    // edges, and separate flags make it easier to reason about the current phase.
    property bool previewReady: false
    property bool overlayClosing: false
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
        // The overlay tells us when it is fully finished. We only clear the
        // "closing" guard once teardown is actually done.
        if (activeOverlay === overlay) {
            activeOverlay = null;
        }

        overlayClosing = false;
    }

    function resetFlow() {
        // Return to the fully idle state after success, failure, or cancellation.
        pendingFreezeScreen = null;
        pendingSelection = null;
        pendingFreezePath = "";
        previewReady = false;
        overlayClosing = false;
        selectionAccepted = false;
        freezeFileReady = false;
        captureStarted = false;
        captureFinished = false;
        ignoreFreezeResult = false;
        freezeErrorText = "";
        captureErrorText = "";
    }

    function abortFlow() {
        // Cancel behaves differently depending on where we are in the pipeline.
        // While freezing, we cannot stop the helper process directly, so we mark
        // its result as ignorable and let `freezeProcess.onExited` clean up.
        if (freezeProcess.running) {
            ignoreFreezeResult = true;

            pendingFreezeScreen = null;
            pendingSelection = null;
            previewReady = false;
            selectionAccepted = false;
            freezeFileReady = false;
            captureStarted = false;
            captureFinished = false;
            freezeErrorText = "";
            captureErrorText = "";
            return;
        }

        cleanupFrozenFrame(pendingFreezePath);
        resetFlow();
    }

    function appendError(existingText, data) {
        // Helper processes may emit several stderr lines; keep the toast useful.
        var trimmed = (data || "").trim();
        if (trimmed.length === 0) {
            return existingText;
        }

        return existingText.length > 0 ? existingText + "\n" + trimmed : trimmed;
    }

    function normalizeLocalPath(path) {
        // Quickshell paths sometimes arrive as `file://...`; the helper script
        // wants plain filesystem paths.
        var text = (path || "").toString();
        if (text.indexOf("file://") === 0) {
            return text.slice(7);
        }

        return text;
    }

    function makeFreezePath() {
        // The frozen frame is a temporary implementation detail, so it belongs in
        // the runtime dir when possible and the temp dir as a fallback.
        var runtimeDir = normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.RuntimeLocation));
        if (!runtimeDir || runtimeDir.length === 0) {
            runtimeDir = normalizeLocalPath(StandardPaths.writableLocation(StandardPaths.TempLocation));
        }

        var suffix = Date.now().toString() + "-" + Math.floor(Math.random() * 1000000).toString();
        return runtimeDir + "/rope-screenshot-freeze-" + suffix + ".png";
    }

    function runCapture(args) {
        // All actual image IO lives in `capture.sh`. QML coordinates state and UI,
        // the script deals with grim/ImageMagick/clipboard interaction.
        if (captureProcess.running) {
            return false;
        }

        captureErrorText = "";
        captureProcess.command = [pluginApi.pluginDir + "/capture.sh"].concat(args || []);
        captureProcess.running = true;
        return true;
    }

    function maybeStartPendingCapture() {
        // Region capture only starts once we have both halves of the job:
        // a frozen source image and a user-approved rectangle.
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
        // The frozen image is temporary and should disappear after any exit path.
        if (!path || cleanupProcess.running) {
            return;
        }

        cleanupProcess.command = [pluginApi.pluginDir + "/capture.sh", "cleanup", path];
        cleanupProcess.running = true;
    }

    function openRegionSelector(screen, frozenImagePath) {
        // The selector is only opened once the frozen frame already exists.
        // That avoids showing a half-initialized overlay while the screen is still
        // being captured underneath it.
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
        overlayClosing = false;
        previewReady = overlay.previewReady;

        // `finished` is our own explicit teardown signal. Using it is more robust
        // than depending on the QObject destruction timing from QML internals.
        overlay.finished.connect(function () {
            root.clearOverlay(overlay);
            root.previewReady = false;
        });

        // Keep root state in sync with the overlay so the rest of the plugin can
        // make decisions without peeking into overlay internals.
        overlay.previewReadyChanged.connect(function () {
            if (root.activeOverlay === overlay) {
                root.previewReady = overlay.previewReady;
            }
        });

        overlay.accepted.connect(function (selection) {
            // Once the user releases the selection, the overlay is done; from here
            // on we only wait for the crop/save helper to finish.
            root.overlayClosing = true;
            root.previewReady = false;
            root.selectionAccepted = true;
            root.pendingSelection = selection;
            root.maybeStartPendingCapture();
        });

        overlay.canceled.connect(function () {
            // Cancel is intentionally idempotent. Repeated hotkey presses should
            // collapse into a single cancellation path instead of racing.
            root.overlayClosing = true;
            root.abortFlow();
        });

        return overlay;
    }

    function beginFrozenRegionSelection(screen) {
        // Region capture starts by freezing the selected output to a temporary file.
        if (!screen || busy) {
            return false;
        }

        resetFlow();

        pendingFreezeScreen = screen;
        pendingFreezePath = makeFreezePath();
        freezeErrorText = "";
        freezeProcess.command = [pluginApi.pluginDir + "/capture.sh", "freeze", screen.name, pendingFreezePath];
        freezeProcess.running = true;
        return true;
    }

    function takeScreenshot(mode) {
        // The hotkey doubles as a toggle: if the overlay is already open, pressing
        // it again cancels the current operation instead of spawning another one.
        if (!pluginApi) {
            return false;
        }

        var normalizedMode = (mode || "region").toLowerCase();

        if (activeOverlay) {
            if (!overlayClosing) {
                overlayClosing = true;
                activeOverlay.cancelSelection();
            }

            return false;
        }

        if (freezeProcess.running) {
            // Pressing the shortcut during the freeze stage means "never mind".
            abortFlow();
            return false;
        }

        if (overlayClosing || captureProcess.running || selectionAccepted) {
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

        // `freezeProcess` produces the temporary full-output PNG used by the overlay.
        stderr: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                root.freezeErrorText = root.appendError(root.freezeErrorText, data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            var screen = root.pendingFreezeScreen;
            var frozenPath = root.pendingFreezePath;
            var shouldIgnore = root.ignoreFreezeResult;
            var freezeMessage = root.freezeErrorText;

            root.pendingFreezeScreen = null;
            root.ignoreFreezeResult = false;

            if (shouldIgnore) {
                root.cleanupFrozenFrame(frozenPath);
                root.resetFlow();
                return;
            }

            if (exitCode === 0 && screen && frozenPath.length > 0) {
                // Success means we can now show the selector against the frozen frame.
                root.freezeFileReady = true;

                if (!root.openRegionSelector(screen, frozenPath)) {
                    root.cleanupFrozenFrame(frozenPath);
                    root.resetFlow();
                    return;
                }
            } else {
                root.cleanupFrozenFrame(frozenPath);
                root.resetFlow();

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

        // `captureProcess` performs the final crop/save/clipboard step.
        stderr: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                root.captureErrorText = root.appendError(root.captureErrorText, data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            var frozenPath = root.pendingFreezePath;

            root.captureFinished = true;

            // The crop helper uses the frozen frame as input, so it is safe to clean
            // up once the process exits regardless of success or failure.
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

        // The hotkey and any external automation both enter through this IPC API.
        function takeScreenshot(mode: string): bool {
            return root.takeScreenshot(mode);
        }

        function cancel(): bool {
            if (!root.activeOverlay || root.overlayClosing) {
                return false;
            }

            root.overlayClosing = true;
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
