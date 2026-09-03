import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    visibilityCommand: "pgrep -x wf-recorder"
    visibilityInterval: 2

    pillClickAction: () => {
        Quickshell.execDetached([
            "sh", "-c", Quickshell.env("HOME") + "/.local/bin/eco-screenrecording.sh"
        ]);
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: dot.width
            implicitHeight: dot.height

            DankIcon {
                id: dot
                anchors.centerIn: parent
                name: "fiber_manual_record"
                filled: true
                size: Theme.barIconSize(root.barThickness, -4)
                color: Theme.error

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { from: 1.0; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.35; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: dotV.width
            implicitHeight: dotV.height

            DankIcon {
                id: dotV
                anchors.centerIn: parent
                name: "fiber_manual_record"
                filled: true
                size: Theme.barIconSize(root.barThickness, -4)
                color: Theme.error

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { from: 1.0; to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.35; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                }
            }
        }
    }
}
