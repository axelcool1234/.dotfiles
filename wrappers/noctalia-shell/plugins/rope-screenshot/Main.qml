import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property var activeOverlay: null
    property var pendingFreezeScreen: null
    property string pendingFreezePath: ""

    readonly property bool busy: captureProcess.running || freezeProcess.running || activeOverlay !== null

    function clearOverlay(overlay) {
        if (activeOverlay === overlay) {
            activeOverlay = null;
        }
    }

    function runCapture(args) {
        if (captureProcess.running) {
            return false;
        }

        captureProcess.command = [pluginApi.pluginDir + "/capture.sh"].concat(args || []);
        captureProcess.running = true;
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
            return false;
        }

        var overlay = selectionOverlay.createObject(null, {
            targetScreen: screen,
            frozenImagePath: frozenImagePath,
        });

        if (!overlay) {
            cleanupFrozenFrame(frozenImagePath);
            ToastService.showError("Screenshot", "Failed to open the region selector.", 3000);
            return false;
        }

        activeOverlay = overlay;

        overlay.accepted.connect(function (selection) {
            clearOverlay(overlay);
            runCapture([
                "region-frozen",
                frozenImagePath,
                selection.localGeometry,
                String(selection.scaleX),
                String(selection.scaleY),
            ]);
        });

        overlay.canceled.connect(function () {
            clearOverlay(overlay);
            cleanupFrozenFrame(frozenImagePath);
        });

        overlay.destroyed.connect(function () {
            clearOverlay(overlay);
        });

        return true;
    }

    function beginFrozenRegionSelection(screen) {
        if (!screen || activeOverlay || freezeProcess.running) {
            return false;
        }

        pendingFreezeScreen = screen;
        pendingFreezePath = "";
        freezeProcess.command = [pluginApi.pluginDir + "/capture.sh", "freeze", screen.name];
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

        if (captureProcess.running) {
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

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                var line = (data || "").trim();
                if (line.length > 0) {
                    root.pendingFreezePath = line;
                }
            }
        }

        onExited: code => {
            var screen = root.pendingFreezeScreen;
            var frozenPath = root.pendingFreezePath;

            root.pendingFreezeScreen = null;
            root.pendingFreezePath = "";

            if (code === 0 && screen && frozenPath.length > 0) {
                if (!root.openRegionSelector(screen, frozenPath)) {
                    root.cleanupFrozenFrame(frozenPath);
                    ToastService.showError("Screenshot", "Failed to show the frozen selector.", 3000);
                }
            } else {
                root.cleanupFrozenFrame(frozenPath);
                ToastService.showError("Screenshot", "Failed to freeze the screen.", 3000);
            }
        }
    }

    Process {
        id: captureProcess

        onExited: code => {
            if (code === 0) {
                ToastService.showNotice("Screenshot", "Copied to the clipboard and saved to Pictures/Screenshots.", "camera", 3000);
            } else {
                ToastService.showError("Screenshot", "Capture failed.", 3000);
            }
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
