import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: overlay

    property var targetScreen: null

    signal accepted(string geometry)
    signal canceled()

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    screen: targetScreen

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    function clampX(value) {
        return Math.max(0, Math.min(Math.round(value), width));
    }

    function clampY(value) {
        return Math.max(0, Math.min(Math.round(value), height));
    }

    function cancelSelection() {
        selection.active = false;
        canceled();
        destroy();
    }

    function completeSelection() {
        selection.active = false;

        if (selection.selectionWidth < 2 || selection.selectionHeight < 2) {
            cancelSelection();
            return;
        }

        var screenX = targetScreen && targetScreen.x !== undefined ? targetScreen.x : 0;
        var screenY = targetScreen && targetScreen.y !== undefined ? targetScreen.y : 0;
        var geometry =
            (screenX + selection.x1)
            + ","
            + (screenY + selection.y1)
            + " "
            + selection.selectionWidth
            + "x"
            + selection.selectionHeight;

        accepted(geometry);
        destroy();
    }

    QtObject {
        id: selection

        property bool active: false
        property int startX: 0
        property int startY: 0
        property int currentX: 0
        property int currentY: 0
        property int x1: Math.min(startX, currentX)
        property int y1: Math.min(startY, currentY)
        property int x2: Math.max(startX, currentX)
        property int y2: Math.max(startY, currentY)
        property int selectionWidth: x2 - x1
        property int selectionHeight: y2 - y1
        property int handleRadius: Math.max(10, Math.round(12 * Style.uiScaleRatio))
        property int borderWidth: Math.max(4, Math.round(5 * Style.uiScaleRatio))

        onActiveChanged: if (canvas) canvas.requestPaint()
        onStartXChanged: if (canvas) canvas.requestPaint()
        onStartYChanged: if (canvas) canvas.requestPaint()
        onCurrentXChanged: if (canvas) canvas.requestPaint()
        onCurrentYChanged: if (canvas) canvas.requestPaint()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor
        hoverEnabled: true

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                overlay.cancelSelection();
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

    Canvas {
        id: canvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Color.mSurface;
            ctx.globalAlpha = 0.82;
            ctx.fillRect(0, 0, width, height);

            if (!selection.active) {
                return;
            }

            ctx.globalAlpha = 1;
            ctx.fillStyle = Color.mPrimary;
            ctx.fillRect(
                selection.x1 - selection.borderWidth,
                selection.y1 - selection.borderWidth,
                selection.selectionWidth + selection.borderWidth * 2,
                selection.selectionHeight + selection.borderWidth * 2
            );

            function drawCorner(x, y) {
                ctx.beginPath();
                ctx.arc(x, y, selection.handleRadius, 0, 2 * Math.PI);
                ctx.fill();
            }

            drawCorner(selection.x1, selection.y1);
            drawCorner(selection.x2, selection.y1);
            drawCorner(selection.x1, selection.y2);
            drawCorner(selection.x2, selection.y2);

            ctx.clearRect(selection.x1, selection.y1, selection.selectionWidth, selection.selectionHeight);
        }
    }

    Rope {
        anchors.fill: parent
        visible: selection.active
        anchorX: 0
        anchorY: 0
        pullX: selection.x1
        pullY: selection.y1
        strokeColor: Color.mPrimary
    }

    Rope {
        anchors.fill: parent
        visible: selection.active
        anchorX: parent.width
        anchorY: 0
        pullX: selection.x2
        pullY: selection.y1
        strokeColor: Color.mPrimary
    }

    Rope {
        anchors.fill: parent
        visible: selection.active
        anchorX: 0
        anchorY: parent.height
        pullX: selection.x1
        pullY: selection.y2
        strokeColor: Color.mPrimary
    }

    Rope {
        anchors.fill: parent
        visible: selection.active
        anchorX: parent.width
        anchorY: parent.height
        pullX: selection.x2
        pullY: selection.y2
        strokeColor: Color.mPrimary
    }
}
