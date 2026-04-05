import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// The overlay is intentionally dumb: it only draws the frozen image, collects a
// rectangle, and reports the chosen region back to `Main.qml`.
//
// Keeping the selection window focused on presentation makes the async flow much
// easier to reason about. The controller decides when the overlay exists; the
// overlay only decides what rectangle the user selected.
PanelWindow {
    id: overlay

    property var targetScreen: null
    property string frozenImagePath: ""
    readonly property string frozenImageSource: frozenImagePath.length === 0
        ? ""
        : (frozenImagePath.indexOf("file://") === 0 ? frozenImagePath : "file://" + frozenImagePath)
    readonly property bool freezeFileReady: frozenImagePath.length > 0
    readonly property bool usingFrozenImage: freezeFileReady && frozenImage.status === Image.Ready
    readonly property bool previewReady: usingFrozenImage
    readonly property int sourceWidth: frozenImage.sourceSize.width
    readonly property int sourceHeight: frozenImage.sourceSize.height

    // `closing` keeps cancel/accept idempotent so repeated inputs cannot make the
    // overlay emit contradictory signals during teardown.
    property bool closing: false

    signal accepted(var selection)
    signal canceled()

    // This explicit teardown signal is easier for the controller to consume than
    // relying on QObject destruction timing from QML internals.
    signal finished()

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rope-screenshot"
    color: "transparent"
    screen: targetScreen

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    function clampX(value) {
        // Clamp all geometry to the overlay bounds so drag math stays valid.
        return Math.max(0, Math.min(Math.round(value), width));
    }

    function clampY(value) {
        return Math.max(0, Math.min(Math.round(value), height));
    }

    function requestRepaint() {
        // These canvases are imperative, so property changes need explicit repaints.
        if (selectionCanvas) {
            selectionCanvas.requestPaint();
        }

        if (handleCanvas) {
            handleCanvas.requestPaint();
        }
    }

    function cancelSelection() {
        if (closing) {
            return;
        }

        // Cancel keeps no geometry; it simply notifies the controller that this
        // selection should be abandoned and the temp freeze can be cleaned up.
        closing = true;
        selection.active = false;
        canceled();
        finished();
        destroy();
    }

    function completeSelection() {
        if (closing) {
            return;
        }

        // Snapshot the final rectangle before flipping `active` off. Earlier bugs
        // came from reading geometry after bindings had already collapsed.
        var x1 = Math.min(selection.startX, selection.currentX);
        var y1 = Math.min(selection.startY, selection.currentY);
        var x2 = Math.max(selection.startX, selection.currentX);
        var y2 = Math.max(selection.startY, selection.currentY);
        var selectionWidth = x2 - x1;
        var selectionHeight = y2 - y1;

        closing = true;
        selection.active = false;

        if (selectionWidth < 2 || selectionHeight < 2) {
            // Tiny drags are treated as cancellations rather than degenerate crops.
            canceled();
            finished();
            destroy();
            return;
        }

        var localGeometry =
            x1
            + ","
            + y1
            + " "
            + selectionWidth
            + "x"
            + selectionHeight;

        accepted({
            // The helper script crops against the frozen image, not the scaled UI.
            // Pass both the logical geometry and the overlay-to-image scale factors.
            localGeometry: localGeometry,
            scaleX: overlay.sourceWidth > 0 && overlay.width > 0
                ? overlay.sourceWidth / overlay.width
                : 1,
            scaleY: overlay.sourceHeight > 0 && overlay.height > 0
                ? overlay.sourceHeight / overlay.height
                : 1,
        });
        finished();
        destroy();
    }

    QtObject {
        id: selection

        // Start centered so the initial ropes have a deterministic resting point.
        property bool active: false
        property int startX: overlay.clampX(overlay.width / 2)
        property int startY: overlay.clampY(overlay.height / 2)
        property int currentX: overlay.clampX(overlay.width / 2)
        property int currentY: overlay.clampY(overlay.height / 2)
        property int x1: Math.min(startX, currentX)
        property int y1: Math.min(startY, currentY)
        property int x2: Math.max(startX, currentX)
        property int y2: Math.max(startY, currentY)
        property int selectionWidth: x2 - x1
        property int selectionHeight: y2 - y1
        property int handleRadius: Math.max(10, Math.round(12 * Style.uiScaleRatio))
        property int borderWidth: Math.max(4, Math.round(5 * Style.uiScaleRatio))

        onActiveChanged: overlay.requestRepaint()
        onStartXChanged: overlay.requestRepaint()
        onStartYChanged: overlay.requestRepaint()
        onCurrentXChanged: overlay.requestRepaint()
        onCurrentYChanged: overlay.requestRepaint()
    }

    MouseArea {
        // The overlay only needs simple drag semantics: press starts a rectangle,
        // move updates it, release finalizes it, and right-click cancels it.
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: overlay.previewReady ? Qt.CrossCursor : Qt.WaitCursor
        hoverEnabled: true

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                overlay.cancelSelection();
                return;
            }

            if (!overlay.previewReady) {
                return;
            }

            selection.active = true;
            selection.startX = overlay.clampX(mouse.x);
            selection.startY = overlay.clampY(mouse.y);
            selection.currentX = selection.startX;
            selection.currentY = selection.startY;
        }

        onPositionChanged: mouse => {
            if (!selection.active) {
                return;
            }

            selection.currentX = overlay.clampX(mouse.x);
            selection.currentY = overlay.clampY(mouse.y);
        }

        onReleased: mouse => {
            if (mouse.button !== Qt.LeftButton || !selection.active) {
                return;
            }

            selection.currentX = overlay.clampX(mouse.x);
            selection.currentY = overlay.clampY(mouse.y);
            overlay.completeSelection();
        }
    }

    Image {
        id: frozenImage

        anchors.fill: parent
        source: overlay.frozenImageSource

        // Stretch the preview to the overlay size, then use scale factors above to
        // map the final selection back into the real image coordinates.
        fillMode: Image.Stretch
        cache: false
        smooth: false
        visible: overlay.usingFrozenImage
    }

    Canvas {
        id: selectionCanvas

        anchors.fill: parent
        visible: overlay.previewReady

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            // First dim the whole screen, then punch out the selected area so the
            // user is effectively looking through a spotlight.
            ctx.fillStyle = Color.mSurface;
            ctx.globalAlpha = 0.82;
            ctx.fillRect(0, 0, width, height);

            ctx.globalAlpha = 1;
            ctx.fillStyle = Color.mPrimary;
            ctx.fillRect(
                selection.x1 - selection.borderWidth,
                selection.y1 - selection.borderWidth,
                selection.selectionWidth + selection.borderWidth * 2,
                selection.selectionHeight + selection.borderWidth * 2
            );

            ctx.clearRect(selection.x1, selection.y1, selection.selectionWidth, selection.selectionHeight);
        }
    }

    Rope {
        // Each corner rope is decorative, but they also make the origin of the
        // dragged rectangle visually obvious as it grows and shrinks.
        anchors.fill: parent
        visible: overlay.previewReady
        anchorX: 0
        anchorY: 0
        pullX: selection.x1
        pullY: selection.y1
        strokeColor: Color.mPrimary
    }

    Rope {
        anchors.fill: parent
        visible: overlay.previewReady
        anchorX: parent.width
        anchorY: 0
        pullX: selection.x2
        pullY: selection.y1
        strokeColor: Color.mPrimary
    }

    Rope {
        anchors.fill: parent
        visible: overlay.previewReady
        anchorX: 0
        anchorY: parent.height
        pullX: selection.x1
        pullY: selection.y2
        strokeColor: Color.mPrimary
    }

    Rope {
        anchors.fill: parent
        visible: overlay.previewReady
        anchorX: parent.width
        anchorY: parent.height
        pullX: selection.x2
        pullY: selection.y2
        strokeColor: Color.mPrimary
    }

    Canvas {
        id: handleCanvas

        anchors.fill: parent
        visible: overlay.previewReady

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Color.mPrimary;

            function drawCorner(x, y) {
                // Corner handles are visual affordances only; dragging still happens
                // through the full-screen mouse area above.
                ctx.beginPath();
                ctx.arc(x, y, selection.handleRadius, 0, 2 * Math.PI);
                ctx.fill();
            }

            drawCorner(selection.x1, selection.y1);
            drawCorner(selection.x2, selection.y1);
            drawCorner(selection.x1, selection.y2);
            drawCorner(selection.x2, selection.y2);
        }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: !overlay.previewReady

        // A tiny status card avoids the "why is the screen dimmed?" confusion while
        // the frozen preview is still being prepared.
        radius: Math.round(18 * Style.uiScaleRatio)
        color: Color.mSurface
        opacity: 0.92
        border.width: 2
        border.color: Color.mPrimary
        implicitWidth: loadingLabel.implicitWidth + Math.round(28 * Style.uiScaleRatio)
        implicitHeight: loadingLabel.implicitHeight + Math.round(20 * Style.uiScaleRatio)

        Text {
            id: loadingLabel

            anchors.centerIn: parent
            color: Color.mPrimary
            text: overlay.freezeFileReady ? "Preparing preview..." : "Freezing screen..."
            font.pixelSize: Math.max(16, Math.round(18 * Style.uiScaleRatio))
        }
    }
}
