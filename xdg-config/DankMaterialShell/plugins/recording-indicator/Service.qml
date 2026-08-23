import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins

PluginComponent {
    id: root

    pluginId: "recording-indicator"

    property string recordState: "idle"

    visibilityCommand: "pgrep -x wf-recorder"
    visibilityInterval: 2

    horizontalBarPill: null
    verticalBarPill: null

    Component.onCompleted: {
        if (pluginService) {
            var widgetComp = Qt.createComponent(
                Qt.resolvedUrl("Pill.qml"),
                Component.PreferSynchronous,
                root
            )
            if (widgetComp.status === Component.Ready) {
                var newWc = Object.assign({}, pluginService.pluginWidgetComponents)
                newWc["recording-indicator"] = widgetComp
                pluginService.pluginWidgetComponents = newWc
            }
        }
    }
}
