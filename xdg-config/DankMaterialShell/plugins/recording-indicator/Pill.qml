import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    visibilityCommand: "pgrep -x wf-recorder"
    visibilityInterval: 2

    horizontalBarPill: Component {
        Item {
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight || 24

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached([
                    "sh", "-c", "~/.local/bin/eco-screenrecording.sh"
                ])
            }

            Row {
                id: pillRow
                spacing: Theme.spacingS
                anchors.centerIn: parent

                DankIcon {
                    name: "stop_circle"
                    size: Theme.barIconSize(root.barThickness, -2)
                    color: Theme.errorText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            width: parent.width || 24
            implicitHeight: pillCol.height

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached([
                    "sh", "-c", "~/.local/bin/eco-screenrecording.sh"
                ])
            }

            Column {
                id: pillCol
                spacing: Theme.spacingXS
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: "stop_circle"
                    size: Theme.barIconSize(root.barThickness, -2)
                    color: Theme.errorText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
