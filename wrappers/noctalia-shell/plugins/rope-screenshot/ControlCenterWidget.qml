import QtQuick
import Quickshell
import qs.Widgets

NIconButtonHot {
    property ShellScreen screen
    property var pluginApi: null

    icon: "camera"
    tooltipText: "Take a region screenshot"

    onClicked: {
        pluginApi?.mainInstance?.takeScreenshot("region");
    }
}
