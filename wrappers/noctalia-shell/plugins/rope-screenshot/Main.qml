import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property var activeOverlay: null

    readonly property bool busy: captureProcess.running || activeOverlay !== null

    function clearOverlay(overlay) {
        if (activeOverlay === overlay) {
            activeOverlay = null;
        }
    }

    function runCapture(mode, geometry) {
        if (captureProcess.running) {
            return false;
        }

        var command = [pluginApi.pluginDir + "/capture.sh", mode];
        if (geometry) {
            command.push(geometry);
        }

        captureProcess.command = command;
        captureProcess.running = true;
        return true;
    }

    function openRegionSelector(screen) {
        if (!screen || activeOverlay) {
            return false;
        }

        var overlay = selectionOverlay.createObject(null, {
            targetScreen: screen,
        });

        if (!overlay) {
            ToastService.showError("Screenshot", "Failed to open the region selector.", 3000);
            return false;
        }

        activeOverlay = overlay;

        overlay.accepted.connect(function (geometry) {
            clearOverlay(overlay);
            runCapture("region", geometry);
        });

        overlay.canceled.connect(function () {
            clearOverlay(overlay);
        });

        overlay.destroyed.connect(function () {
            clearOverlay(overlay);
        });

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
            return runCapture("screen", "");
        }

        pluginApi.withCurrentScreen(function (screen) {
            openRegionSelector(screen);
        });

        return true;
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
