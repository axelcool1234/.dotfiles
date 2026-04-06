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
//
// Tuning guide for this file:
// - `decorationRevealDelayMs`: how long to hide ropes/handles after the preview appears
// - `decorationRevealFadeDurationMs`: how long the decorative layer takes to fade in
// - if both reveal values are `0`, the reveal effect is effectively disabled
// - `selectionAnchorRadius`: size of the circular corner anchors/handles
// - `selectionBorderWidth`: thickness of the highlighted selection border
// - `selectionMaskOpacity`: how dark the outside area feels
// - `minimumSelectionSize`: smallest accepted drag before it counts as cancel
// - `rope*`: all decorative rope feel/appearance knobs are surfaced here
// - `Color.mPrimary`: main accent used for ropes, handles, and selection border
PanelWindow {
    id: overlay

    property var targetScreen: null
    property string frozenImagePath: ""

    // -----------------------------------------------------------------------
    // Top-level tuning knobs
    // -----------------------------------------------------------------------
    // These properties are intentionally gathered near the top of the file so you
    // can tune the whole overlay from one place without hunting through the tree.
    //
    // Decorative reveal timing:
    // - increase `decorationRevealDelayMs` to hide more of the rope settle wobble
    // - increase `decorationRevealFadeDurationMs` for a softer reveal
    // - set both to `0` to disable the feature and show decorations immediately
    property int decorationRevealDelayMs: 25
    property int decorationRevealFadeDurationMs: 500

    // Selector appearance:
    // - larger `selectionAnchorRadius` = chunkier corner anchors/handles
    // - larger `selectionBorderWidth` = more prominent selection border
    //   By default this is a touch thicker than `ropeStrokeWidth`, because the
    //   `Rectangle` border renderer reads slightly thinner than the rope's
    //   `ShapePath` stroke at the same numeric width.
    // - larger `selectionMaskOpacity` = darker area outside the crop box
    // - larger `minimumSelectionSize` = less likely to accept tiny accidental drags
    property int selectionAnchorRadius: Math.max(6, Math.round(8 * Style.uiScaleRatio))
    // Rope appearance + feel. These are forwarded into each `Rope` instance.
    // - more `ropeSegments` = smoother but heavier and usually laggier
    // - more `ropeSegmentLength` = longer/deeper rope curves
    // - more `ropeGravity` = more sag
    // - more `ropeVelocityCarry` = more trailing / inertia
    // - more `ropeSpringStrength` = snappier follow
    // - more `ropeSubstepsPerFrame` = tighter/stabler, but more CPU work
    // - more `ropeStrokeWidth` = thicker rope line only
    property int ropeSegments: 8
    property int ropeSegmentLength: 16
    property real ropeGravity: 4.5
    property real ropeVelocityCarry: 0.3
    property real ropeSpringStrength: 0.7
    property int ropeSubstepsPerFrame: 2
    property real ropeStrokeWidth: 2.5
    property real selectionBorderWidth: ropeStrokeWidth * 2
    property real selectionMaskOpacity: 0.82
    property int minimumSelectionSize: 2

    readonly property string frozenImageSource: frozenImagePath.length === 0
        ? ""
        : (frozenImagePath.indexOf("file://") === 0 ? frozenImagePath : "file://" + frozenImagePath)
    readonly property bool freezeFileReady: frozenImagePath.length > 0
    readonly property bool usingFrozenImage: freezeFileReady && frozenImage.status === Image.Ready
    readonly property bool previewReady: usingFrozenImage
    readonly property int sourceWidth: frozenImage.sourceSize.width
    readonly property int sourceHeight: frozenImage.sourceSize.height
    readonly property bool decorationRevealEnabled:
        decorationRevealDelayMs > 0 || decorationRevealFadeDurationMs > 0

    // Delay decorative elements very slightly so the rope solver can settle
    // before the user sees it. This avoids the initial "pop into place" wobble.
    property bool decorationsShown: false

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

    onPreviewReadyChanged: {
        // Reset decorative visibility every time a preview becomes available.
        // The mask/border still appear immediately; only the ropes/handles wait.
        if (previewReady) {
            if (decorationRevealEnabled) {
                decorationsShown = false;
                decorationRevealTimer.restart();
            } else {
                // If both timing knobs are zero, treat the feature as disabled and
                // show decorations immediately with no delayed fade-in.
                decorationsShown = true;
                decorationRevealTimer.stop();
            }
        } else {
            decorationsShown = false;
            decorationRevealTimer.stop();
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

        if (selectionWidth < minimumSelectionSize || selectionHeight < minimumSelectionSize) {
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

        // Mirror the top-level tuning knobs into the geometry object so the rest of
        // the overlay can keep reading `selection.*` values naturally.
        property int handleRadius: overlay.selectionAnchorRadius
        property real borderWidth: overlay.selectionBorderWidth

        // These "outer" edges describe the visible selection border rather than
        // the raw drag rectangle. Using them everywhere keeps the ropes, border,
        // and mask aligned to the same geometry.
        readonly property real outerLeft: x1 - borderWidth / 2
        readonly property real outerTop: y1 - borderWidth / 2
        readonly property real outerRight: x2 + borderWidth / 2
        readonly property real outerBottom: y2 + borderWidth / 2
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

    Timer {
        id: decorationRevealTimer

        // Roughly 6-8 frames on a high-refresh display: enough time for the rope
        // to relax a bit, short enough that the UI still feels immediate.
        interval: overlay.decorationRevealDelayMs
        repeat: false

        onTriggered: overlay.decorationsShown = true
    }

    Item {
        // Use regular scenegraph rectangles instead of a full-screen canvas so
        // drag updates only change geometry, not repaint an entire texture.
        anchors.fill: parent
        visible: overlay.previewReady

        // These derived edges define the "hole" around the selected area.
        // The four rectangles below cover everything outside that hole.
        readonly property real topEdge: Math.max(0, selection.outerTop)
        readonly property real leftEdge: Math.max(0, selection.outerLeft)
        readonly property real rightEdge: Math.min(parent.width, selection.outerRight)
        readonly property real bottomEdge: Math.min(parent.height, selection.outerBottom)
        readonly property real middleHeight: Math.max(0, bottomEdge - topEdge)

        Rectangle {
            x: 0
            y: 0
            width: parent.width
            height: parent.topEdge
            color: Color.mSurface

            // This opacity is the main "how dark should the rest of the screen be?"
            // tuning knob for the overlay mask.
            opacity: overlay.selectionMaskOpacity
        }

        Rectangle {
            x: 0
            y: parent.topEdge
            width: parent.leftEdge
            height: parent.middleHeight
            color: Color.mSurface
            opacity: overlay.selectionMaskOpacity
        }

        Rectangle {
            x: parent.rightEdge
            y: parent.topEdge
            width: Math.max(0, parent.width - parent.rightEdge)
            height: parent.middleHeight
            color: Color.mSurface
            opacity: overlay.selectionMaskOpacity
        }

        Rectangle {
            x: 0
            y: parent.bottomEdge
            width: parent.width
            height: Math.max(0, parent.height - parent.bottomEdge)
            color: Color.mSurface
            opacity: overlay.selectionMaskOpacity
        }

        Rectangle {
            // Keep the border mostly outside the clear region like the old canvas
            // version by offsetting the stroke half a border width outward.
            x: selection.outerLeft
            y: selection.outerTop
            width: selection.outerRight - selection.outerLeft
            height: selection.outerBottom - selection.outerTop
            color: "transparent"
            border.width: selection.borderWidth
            border.color: Color.mPrimary
        }
    }

    Item {
        anchors.fill: parent
        visible: overlay.previewReady
        opacity: overlay.decorationsShown ? 1 : 0

        // Fade only the decorative layer. The selection mask and border remain
        // immediate so the user gets instant feedback that screenshot mode started.
        Behavior on opacity {
            NumberAnimation {
                duration: overlay.decorationRevealFadeDurationMs
                easing.type: Easing.InOutQuad
            }
        }

        Rope {
            // Each corner rope is decorative, but they also make the origin of the
            // dragged rectangle visually obvious as it grows and shrinks.
            // Changing `anchor*` changes where the rope is nailed to the screen.
            // Changing `pull*` changes which selection corner the rope follows.
            anchors.fill: parent
            visible: overlay.previewReady
            anchorX: 0
            anchorY: 0
            pullX: selection.outerLeft
            pullY: selection.outerTop
            strokeColor: Color.mPrimary
            strokeWidth: overlay.ropeStrokeWidth
            segments: overlay.ropeSegments
            segmentLength: overlay.ropeSegmentLength
            gravity: overlay.ropeGravity
            velocityCarry: overlay.ropeVelocityCarry
            springStrength: overlay.ropeSpringStrength
            substepsPerFrame: overlay.ropeSubstepsPerFrame
        }

        Rope {
            anchors.fill: parent
            visible: overlay.previewReady
            anchorX: parent.width
            anchorY: 0
            pullX: selection.outerRight
            pullY: selection.outerTop
            strokeColor: Color.mPrimary
            strokeWidth: overlay.ropeStrokeWidth
            segments: overlay.ropeSegments
            segmentLength: overlay.ropeSegmentLength
            gravity: overlay.ropeGravity
            velocityCarry: overlay.ropeVelocityCarry
            springStrength: overlay.ropeSpringStrength
            substepsPerFrame: overlay.ropeSubstepsPerFrame
        }

        Rope {
            anchors.fill: parent
            visible: overlay.previewReady
            anchorX: 0
            anchorY: parent.height
            pullX: selection.outerLeft
            pullY: selection.outerBottom
            strokeColor: Color.mPrimary
            strokeWidth: overlay.ropeStrokeWidth
            segments: overlay.ropeSegments
            segmentLength: overlay.ropeSegmentLength
            gravity: overlay.ropeGravity
            velocityCarry: overlay.ropeVelocityCarry
            springStrength: overlay.ropeSpringStrength
            substepsPerFrame: overlay.ropeSubstepsPerFrame
        }

        Rope {
            anchors.fill: parent
            visible: overlay.previewReady
            anchorX: parent.width
            anchorY: parent.height
            pullX: selection.outerRight
            pullY: selection.outerBottom
            strokeColor: Color.mPrimary
            strokeWidth: overlay.ropeStrokeWidth
            segments: overlay.ropeSegments
            segmentLength: overlay.ropeSegmentLength
            gravity: overlay.ropeGravity
            velocityCarry: overlay.ropeVelocityCarry
            springStrength: overlay.ropeSpringStrength
            substepsPerFrame: overlay.ropeSubstepsPerFrame
        }

        Item {
            // This is the more principled fix for ropes visually intruding into the
            // clear selection area: repaint the frozen preview over that area after
            // the ropes are drawn. The screenshot output was already correct, but
            // this keeps the on-screen presentation clean without distorting the
            // rope physics or forcing awkward endpoint offsets.
            x: selection.x1
            y: selection.y1
            width: selection.selectionWidth
            height: selection.selectionHeight
            clip: true

            Image {
                // Reuse the same frozen frame, but position it so only the exact
                // selected region is shown inside this clipped cover item.
                x: -selection.x1
                y: -selection.y1
                width: overlay.width
                height: overlay.height
                source: overlay.frozenImageSource
                fillMode: Image.Stretch
                cache: false
                smooth: false
            }
        }

        // Corner handles are visual affordances only; dragging still happens
        // through the full-screen mouse area above.
        // If you want a subtler look, reduce `selectionAnchorRadius` at the top of
        // the file rather than tweaking these rectangles individually.
        Rectangle {
            x: selection.x1 - selection.handleRadius
            y: selection.y1 - selection.handleRadius
            width: selection.handleRadius * 2
            height: selection.handleRadius * 2
            radius: selection.handleRadius
            color: Color.mPrimary
        }

        Rectangle {
            x: selection.x2 - selection.handleRadius
            y: selection.y1 - selection.handleRadius
            width: selection.handleRadius * 2
            height: selection.handleRadius * 2
            radius: selection.handleRadius
            color: Color.mPrimary
        }

        Rectangle {
            x: selection.x1 - selection.handleRadius
            y: selection.y2 - selection.handleRadius
            width: selection.handleRadius * 2
            height: selection.handleRadius * 2
            radius: selection.handleRadius
            color: Color.mPrimary
        }

        Rectangle {
            x: selection.x2 - selection.handleRadius
            y: selection.y2 - selection.handleRadius
            width: selection.handleRadius * 2
            height: selection.handleRadius * 2
            radius: selection.handleRadius
            color: Color.mPrimary
        }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: !overlay.previewReady

        // A tiny status card avoids the "why is the screen dimmed?" confusion while
        // the frozen preview is still being prepared.
        // This is a pure UX affordance; it can be removed without affecting the
        // actual screenshot flow if a more minimal look is preferred.
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
