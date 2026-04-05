import QtQuick
import QtQuick.Shapes

Rectangle {
    id: ropeRect

    property int anchorX: 0
    property int anchorY: 0
    property int pullX: 100
    property int pullY: 100
    property int segments: 10
    property int segmentLength: 18
    property color strokeColor: "white"
    property real gravity: 6.0

    anchors.fill: parent
    color: "transparent"

    Shape {
        id: rope
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        Instantiator {
            model: ropeRect.segments

            onObjectAdded: (_, pathCurve) => {
                ropePath.pathElements.push(pathCurve);
            }

            delegate: PathCurve {
            }
        }

        ShapePath {
            id: ropePath
            strokeColor: ropeRect.strokeColor
            fillColor: "transparent"
            strokeWidth: 5
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

        Timer {
            interval: 1000 / 60
            running: true
            repeat: true

            onTriggered: {
                for (var i = ropeRect.segments; i > 0; i--) {
                    var point = dotPath.pathElements[i];
                    var line = ropePath.pathElements[i - 1];
                    var prev = dotPath.pathElements[i - 1];

                    if (!point || !line || !prev) {
                        continue;
                    }

                    var prevDx = prev.centerX - point.centerX;
                    var prevDy = prev.centerY - point.centerY;
                    var prevDist = Math.sqrt(Math.pow(prevDx, 2) + Math.pow(prevDy, 2));
                    var prevExtend = prevDist - ropeRect.segmentLength;

                    var vx = (prevDx / prevDist) * prevExtend;
                    var vy = (prevDy / prevDist) * prevExtend + ropeRect.gravity;

                    if (isNaN(vx)) vx = 0;
                    if (isNaN(vy)) vy = 0;

                    if (i < ropeRect.segments - 3) {
                        var next = dotPath.pathElements[i + 1];
                        if (!next) {
                            continue;
                        }
                        var nextDx = next.centerX - point.centerX;
                        var nextDy = next.centerY - point.centerY;
                        var nextDist = Math.sqrt(Math.pow(nextDx, 2) + Math.pow(nextDy, 2));
                        var nextExtend = nextDist - ropeRect.segmentLength;

                        vx += (nextDx / nextDist) * nextExtend;
                        vy += (nextDy / nextDist) * nextExtend;
                    } else {
                        point.centerX = ropeRect.pullX;
                        point.centerY = ropeRect.pullY;
                    }

                    point.vx = point.vx * 0.5 + vx * 0.45;
                    point.vy = point.vy * 0.5 + vy * 0.45;
                    point.centerX += point.vx;
                    point.centerY += point.vy;

                    line.x = point.centerX;
                    line.y = point.centerY;
                }
            }
        }

        Instantiator {
            model: ropeRect.segments

            onObjectAdded: (_, pathCurve) => {
                dotPath.pathElements.push(pathCurve);
            }

            delegate: PathAngleArc {
                property int index: model.index
                property double vx: 0
                property double vy: 0

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
