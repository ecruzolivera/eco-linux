import QtQuick
import QtQuick.Controls
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

            DankIcon {
                anchors.centerIn: parent
                name: "smart_toy"
                size: root.iconSize
                filled: root.snapshot.filled
                color: root.stateColor
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
