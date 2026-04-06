import QtQuick
import QtQuick.Shapes

// This component draws one decorative rope between a fixed corner anchor and a
// moving pull point.
//
// The implementation is intentionally split in two layers:
// - `dotPath` stores the invisible simulation points (the rope "joints")
// - `ropePath` draws the visible smoothed line that follows those points
//
// Tuning guide:
// - `segments`: more segments = smoother bend, but more work per frame and more lag
// - `segmentLength`: larger values = physically longer rope with deeper curves
// - `gravity`: larger values = more sag, smaller values = flatter rope
// - `velocityCarry`: larger values = more inertia/trailing, smaller values = snappier rope
// - `springStrength`: larger values = rope chases the cursor more aggressively
// - `substepsPerFrame`: more substeps = tighter, more stable rope at higher CPU cost
// - `strokeWidth`: purely visual thickness; does not affect the simulation
Rectangle {
    id: ropeRect

    // -----------------------------------------------------------------------
    // Top-level tuning knobs
    // -----------------------------------------------------------------------
    // These properties are grouped here on purpose so you can tune the rope feel
    // from one place without digging through the solver below.
    //
    // Shape / appearance:
    // - more `segments` = smoother curve, more CPU work, often more visible lag
    // - more `segmentLength` = longer rope spans and deeper curves
    // - more `strokeWidth` = thicker line only; no physics impact
    //
    // Motion / feel:
    // - more `gravity` = more sag
    // - more `velocityCarry` = more inertia / trailing
    // - more `springStrength` = snappier follow
    // - more `substepsPerFrame` = tighter/stabler rope at higher CPU cost

    // `anchor*` is the fixed point at the screen corner.
    property int anchorX: 0
    property int anchorY: 0

    // `pull*` is the moving end attached to the selection rectangle corner.
    property int pullX: 100
    property int pullY: 100

    // These are the main "feel" knobs. See the tuning guide above.
    property int segments: 8
    property int segmentLength: 16
    property color strokeColor: "white"
    property real strokeWidth: 5
    property real gravity: 4.5
    property real velocityCarry: 0.3
    property real springStrength: 0.7
    property int substepsPerFrame: 2

    anchors.fill: parent
    color: "transparent"

    function stepPhysicsOnce() {
        // Walk the rope from the pulled end back toward the anchor and adjust each
        // joint based on its neighbors. This is a cheap spring-ish approximation,
        // not a real physical solver.
        for (var i = segments; i > 0; i--) {
            var point = dotPath.pathElements[i];
            var line = ropePath.pathElements[i - 1];
            var prev = dotPath.pathElements[i - 1];

            if (!point || !line || !prev) {
                continue;
            }

            var prevDx = prev.centerX - point.centerX;
            var prevDy = prev.centerY - point.centerY;
            var prevDist = Math.sqrt(Math.pow(prevDx, 2) + Math.pow(prevDy, 2));
            var prevExtend = prevDist - segmentLength;

            // `vx`/`vy` are the corrective impulses that try to pull the current
            // joint back toward the target rope length.
            var vx = (prevDx / prevDist) * prevExtend;
            var vy = (prevDy / prevDist) * prevExtend + gravity;

            if (isNaN(vx)) vx = 0;
            if (isNaN(vy)) vy = 0;

            if (i < segments - 3) {
                var next = dotPath.pathElements[i + 1];
                if (!next) {
                    continue;
                }

                // Middle joints are influenced by both neighbors so the rope bends
                // smoothly instead of acting like a one-sided chain.
                var nextDx = next.centerX - point.centerX;
                var nextDy = next.centerY - point.centerY;
                var nextDist = Math.sqrt(Math.pow(nextDx, 2) + Math.pow(nextDy, 2));
                var nextExtend = nextDist - segmentLength;

                vx += (nextDx / nextDist) * nextExtend;
                vy += (nextDy / nextDist) * nextExtend;
            } else {
                point.centerX = pullX;
                point.centerY = pullY;
                point.vx = 0;
                point.vy = 0;
                line.x = point.centerX;
                line.y = point.centerY;
                continue;
            }

            // `velocityCarry` controls how much last-frame motion survives.
            // Higher values make the rope feel heavy and delayed.
            // `springStrength` controls how strongly the rope snaps toward the
            // corrective impulses computed above.
            point.vx = point.vx * velocityCarry + vx * springStrength;
            point.vy = point.vy * velocityCarry + vy * springStrength;
            point.centerX += point.vx;
            point.centerY += point.vy;

            line.x = point.centerX;
            line.y = point.centerY;
        }
    }

    function stepPhysics() {
        // A couple of smaller substeps per rendered frame makes the rope feel
        // less delayed without needing time-based integration.
        // If the rope jitters or looks unstable, reducing `substepsPerFrame`
        // lowers CPU work; increasing it makes the rope feel tighter.
        for (var step = 0; step < substepsPerFrame; step++) {
            stepPhysicsOnce();
        }
    }

    Shape {
        id: rope
        anchors.fill: parent

        // CurveRenderer gives the rope a smoother look than a polyline renderer.
        preferredRendererType: Shape.CurveRenderer

        Instantiator {
            model: ropeRect.segments

            // Create one visible curve control point per rope segment.
            onObjectAdded: (_, pathCurve) => {
                ropePath.pathElements.push(pathCurve);
            }

            delegate: PathCurve {
            }
        }

        ShapePath {
            id: ropePath

            // Visible rope styling knobs:
            // - `strokeWidth` changes visual thickness
            // - `strokeColor` is inherited from the overlay theme
            strokeColor: ropeRect.strokeColor
            fillColor: "transparent"
            strokeWidth: ropeRect.strokeWidth
            startX: ropeRect.anchorX
            startY: ropeRect.anchorY
        }

        ShapePath {
            id: dotPath

            // These arcs are only the rope simulation points; the visible rope is
            // drawn by `ropePath`, so keep the joints themselves invisible.
            strokeColor: "transparent"
            fillColor: "transparent"
            strokeWidth: 0

            PathAngleArc {
                id: startPoint

                // Each simulation point stores its own velocity so the rope can
                // keep some motion between frames.
                property double vx: 0
                property double vy: 0

                onCenterXChanged: ropePath.startX = centerX
                onCenterYChanged: ropePath.startY = centerY

                centerX: ropeRect.anchorX
                centerY: ropeRect.anchorY
                radiusX: 2
                radiusY: 2
                startAngle: 0
                sweepAngle: 360
            }
        }

        FrameAnimation {
            // This runs once per rendered frame, so the rope updates at the
            // monitor/compositor cadence instead of a fixed 60 Hz timer.
            running: ropeRect.visible

            onTriggered: ropeRect.stepPhysics()
        }

        Instantiator {
            model: ropeRect.segments

            // Create the invisible simulation joints that the visible curve follows.
            onObjectAdded: (_, pathCurve) => {
                dotPath.pathElements.push(pathCurve);
            }

            delegate: PathAngleArc {
                property int index: model.index
                property double vx: 0
                property double vy: 0

                // Keep the visible rope control points mirrored to the simulated
                // joints so the rendered curve automatically follows the solver.
                onCenterXChanged: {
                    var point = ropePath.pathElements[index];
                    if (point) {
                        point.x = centerX;
                    }
                }

                onCenterYChanged: {
                    var point = ropePath.pathElements[index];
                    if (point) {
                        point.y = centerY;
                    }
                }

                Component.onCompleted: {
                    var point = ropePath.pathElements[index];
                    if (point) {
                        point.x = centerX;
                        point.y = centerY;
                    }
                }

                // Seed points diagonally away from the anchor so the rope has a
                // deterministic initial shape before the first animation frame.
                centerX: ropeRect.anchorX + index
                centerY: ropeRect.anchorY + index
                radiusX: 1
                radiusY: 1
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
}
