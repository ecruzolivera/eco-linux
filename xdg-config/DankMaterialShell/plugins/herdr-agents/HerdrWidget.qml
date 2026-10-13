import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "AgentState.js" as AgentState

PluginComponent {
    id: root

    layerNamespacePlugin: "herdr-agents"
    readonly property var snapshot: sharedSnapshot.value
    readonly property var palette: Theme.dank16?.[SessionData.isLightMode ? "light" : "dark"]
    readonly property color stateColor: colorForState(snapshot.state)

    function colorForState(state) {
        switch (state) {
        case "blocked": return palette?.color1 ?? Theme.error;
        case "done":
        case "idle": return palette?.color2 ?? Theme.success;
        case "working": return palette?.color3 ?? (SessionData.isLightMode ? "#8c6d00" : "#ffda72");
        default: return Theme.surfaceVariantText;
        }
    }

    function updateVisibility() {
        setVisibilityOverride(snapshot.visible);
        if (!snapshot.visible) {
            closePopout();
        }
    }

    function triggerHoverPopout(widgetHostId) {
        // Details are click-only, even when DankBar hover popouts are enabled.
    }

    onSnapshotChanged: updateVisibility()
    Component.onCompleted: updateVisibility()

    PluginGlobalVar {
        id: sharedSnapshot
        varName: "snapshot"
        defaultValue: AgentState.unavailable("Connecting to Herdr…")
    }

    Component {
        id: iconComponent
        Item {
            id: iconItem
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize
            Accessible.role: Accessible.Button
            Accessible.name: "Herdr agents: " + AgentState.summary(root.snapshot)
            Accessible.onPressAction: root.triggerPopout()

            Item {
                id: robotIcon
                anchors.centerIn: parent
                width: root.iconSize
                height: root.iconSize

                Shape {
                    width: 24
                    height: 24
                    scale: robotIcon.width / 24
                    transformOrigin: Item.TopLeft
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.stateColor
                        fillRule: ShapePath.WindingFill
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            // Adapted from Pictogrammers' Apache-2.0 robot icons.
                            // Eye radii reduced by 25%; centers and body unchanged.
                            // Original paths and license are retained in icons/.
                            path: root.snapshot.filled
                                ? "M12,2A2,2 0 0,1 14,4C14,4.74 13.6,5.39 13,5.73V7H14A7,7 0 0,1 21,14H22A1,1 0 0,1 23,15V18A1,1 0 0,1 22,19H21V20A2,2 0 0,1 19,22H5A2,2 0 0,1 3,20V19H2A1,1 0 0,1 1,18V15A1,1 0 0,1 2,14H3A7,7 0 0,1 10,7H11V5.73C10.4,5.39 10,4.74 10,4A2,2 0 0,1 12,2M7.5,13.625A1.875,1.875 0 0,0 5.625,15.5A1.875,1.875 0 0,0 7.5,17.375A1.875,1.875 0 0,0 9.375,15.5A1.875,1.875 0 0,0 7.5,13.625M16.5,13.625A1.875,1.875 0 0,0 14.625,15.5A1.875,1.875 0 0,0 16.5,17.375A1.875,1.875 0 0,0 18.375,15.5A1.875,1.875 0 0,0 16.5,13.625Z"
                                : "M15.5,14A1.5,1.5 0 0,0 14,15.5A1.5,1.5 0 0,0 15.5,17A1.5,1.5 0 0,0 17,15.5A1.5,1.5 0 0,0 15.5,14M8.5,14A1.5,1.5 0 0,0 7,15.5A1.5,1.5 0 0,0 8.5,17A1.5,1.5 0 0,0 10,15.5A1.5,1.5 0 0,0 8.5,14M23 15V18C23 18.55 22.55 19 22 19H21V20C21 21.11 20.11 22 19 22H5C3.9 22 3 21.11 3 20V19H2C1.45 19 1 18.55 1 18V15C1 14.45 1.45 14 2 14H3C3 10.13 6.13 7 10 7H11V5.73C10.4 5.39 10 4.74 10 4C10 2.9 10.9 2 12 2S14 2.9 14 4C14 4.74 13.6 5.39 13 5.73V7H14C17.87 7 21 10.13 21 14H22C22.55 14 23 14.45 23 15M21 16H19V14C19 11.24 16.76 9 14 9H10C7.24 9 5 11.24 5 14V16H3V17H5V20H19V17H21V16Z"
                        }
                    }
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    horizontalBarPill: iconComponent
    verticalBarPill: iconComponent
    popoutWidth: 440

    popoutContent: Component {
        PopoutComponent {
            id: details
            headerText: "Herdr agents"
            detailsText: AgentState.summary(root.snapshot)
            showCloseButton: true

            ListView {
                id: agentList
                width: parent.width
                implicitHeight: Math.min(contentHeight, Math.max(100, Math.min(500, (root.parentScreen?.height ?? 800) * 0.65) - details.headerHeight - details.detailsHeight))
                height: implicitHeight
                clip: true
                model: root.snapshot.agents
                spacing: Theme.spacingS
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                delegate: Item {
                    required property var modelData
                    width: agentList.width
                    implicitHeight: agentInfo.implicitHeight + Theme.spacingM * 2
                    height: implicitHeight

                    Rectangle {
                        x: Theme.spacingS
                        y: Theme.spacingM
                        width: 3
                        height: agentInfo.implicitHeight
                        radius: 1
                        color: root.colorForState(modelData.state)
                    }

                    Column {
                        id: agentInfo
                        x: Theme.spacingM + Theme.spacingS
                        y: Theme.spacingM
                        width: parent.width - x - Theme.spacingM
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            text: modelData.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            width: parent.width
                            text: modelData.kind + " · " + AgentState.stateLabel(modelData.state) + " · " + modelData.paneId
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.colorForState(modelData.state)
                        }

                        StyledText {
                            width: parent.width
                            text: modelData.directory
                            textFormat: Text.PlainText
                            visible: text.length > 0
                            elide: Text.ElideMiddle
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }
    }
}
