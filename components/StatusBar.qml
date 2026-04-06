import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var folders
    required property string activeFolder
    signal folderClicked(string folder)

    required property int wallpaperCount
    required property int cachedCount
    required property int queueCount

    property bool settingsOpen: false
    signal settingsToggled()

    // Fixed height, Layout controlled width
    Layout.preferredWidth: 600
    height: 44

    // Background Pill
    Rectangle {
        anchors.fill: parent
        radius: 22
        color: "#18181b"
        border.color: "#3f3f46"
        border.width: 1
        
        // Inner highlight for glass effect
        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "transparent"
            border.color: "#ffffff"
            border.width: 1
            opacity: 0.05
        }
    }

    // Content
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        // Folder Tabs
        Repeater {
            model: root.folders
            delegate: MouseArea {
                required property string modelData
                property bool isActive: root.activeFolder === modelData
                width: tabLabel.implicitWidth + 16
                height: 28
                
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: isActive ? "#3b82f6" : "transparent"
                    opacity: isActive ? 0.2 : 1.0
                }

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: modelData
                    color: isActive ? "#60a5fa" : "#a1a1aa"
                    font.pixelSize: 12
                    font.weight: isActive ? Font.Bold : Font.Medium
                }
                onClicked: root.folderClicked(modelData)
            }
        }

        // Divider
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 20
            color: "#3f3f46"
            visible: root.folders.length > 0
        }

        // Spacer
        Item { Layout.fillWidth: true }

        // Info Text
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.wallpaperCount + "  |  cache: " + root.cachedCount
            color: "#71717a"
            font.pixelSize: 11
            font.family: "monospace"
        }

        // Settings Button
        MouseArea {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingsToggled()

            Rectangle {
                anchors.centerIn: parent
                width: 32; height: 32
                radius: 16
                color: settingsHover.containsMouse ? "#27272a" : "transparent"
                MouseArea { id: settingsHover; anchors.fill: parent; hoverEnabled: true }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                anchors.centerIn: parent
                text: "⚙"
                font.pixelSize: 15
                color: root.settingsOpen ? "#3b82f6" : "#a1a1aa"
            }
        }
    }
}
