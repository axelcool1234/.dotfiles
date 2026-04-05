import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: overlay

    property var targetScreen: null
    property string frozenImagePath: ""
    readonly property string frozenImageSource: frozenImagePath.length === 0
        ? ""
        : (frozenImagePath.indexOf("file://") === 0 ? frozenImagePath : "file://" + frozenImagePath)
    readonly property bool freezeFileReady: frozenImagePath.length > 0
    readonly property bool usingFrozenImage: freezeFileReady && frozenImage.status === Image.Ready
    readonly property bool previewReady: liveFreeze.hasContent || usingFrozenImage
    readonly property int sourceWidth: usingFrozenImage ? frozenImage.sourceSize.width : liveFreeze.sourceSize.width
    readonly property int sourceHeight: usingFrozenImage ? frozenImage.sourceSize.height : liveFreeze.sourceSize.height

    signal accepted(var selection)
    signal canceled()

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
        return Math.max(0, Math.min(Math.round(value), width));
    }

    function clampY(value) {
        return Math.max(0, Math.min(Math.round(value), height));
    }

    function requestRepaint() {
        if (selectionCanvas) {
            selectionCanvas.requestPaint();
        }

        if (handleCanvas) {
            handleCanvas.requestPaint();
        }
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

        var localGeometry =
            selection.x1
            + ","
            + selection.y1
            + " "
            + selection.selectionWidth
            + "x"
            + selection.selectionHeight;

        accepted({
            localGeometry: localGeometry,
            scaleX: overlay.sourceWidth > 0 && overlay.width > 0
                ? overlay.sourceWidth / overlay.width
                : 1,
            scaleY: overlay.sourceHeight > 0 && overlay.height > 0
                ? overlay.sourceHeight / overlay.height
                : 1,
        });
        destroy();
    }

    QtObject {
        id: selection

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

    ScreencopyView {
        id: liveFreeze

        anchors.fill: parent
        captureSource: overlay.targetScreen
        visible: !overlay.usingFrozenImage
    }

    Image {
        id: frozenImage

        anchors.fill: parent
        source: overlay.frozenImageSource
        fillMode: Image.Stretch
        cache: false
        smooth: false
        visible: overlay.usingFrozenImage
    }

    Timer {
        interval: 80
        running: !overlay.previewReady
        repeat: true

        onTriggered: {
            if (overlay.previewReady) {
                stop();
                return;
            }

            liveFreeze.captureFrame();
        }
    }

    Canvas {
        id: selectionCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
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
        anchors.fill: parent
        visible: true
        anchorX: 0
        anchorY: 0
        pullX: selection.x1
        pullY: selection.y1
        strokeColor: Color.mPrimary
    }

    Rope {
        anchors.fill: parent
        visible: true
        anchorX: parent.width
        anchorY: 0
        pullX: selection.x2
        pullY: selection.y1
        strokeColor: Color.mPrimary
    }

    Rope {
        anchors.fill: parent
        visible: true
        anchorX: 0
        anchorY: parent.height
        pullX: selection.x1
        pullY: selection.y2
        strokeColor: Color.mPrimary
    }

    Rope {
        anchors.fill: parent
        visible: true
        anchorX: parent.width
        anchorY: parent.height
        pullX: selection.x2
        pullY: selection.y2
        strokeColor: Color.mPrimary
    }

    Canvas {
        id: handleCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Color.mPrimary;

            function drawCorner(x, y) {
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
