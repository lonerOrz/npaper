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

    width: Math.max(450, contentRow.width + 32)
    height: 44

    // Background pill
    Rectangle {
        anchors.fill: parent
        radius: 22
        color: "#111111"
        border.color: "#444444"
        border.width: 1
    }

    // Content Row
    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 16

        // Folder Tabs
        Repeater {
            model: root.folders
            delegate: MouseArea {
                required property string modelData
                property bool isActive: root.activeFolder === modelData
                width: tabLabel.implicitWidth + 16
                height: 28
                
                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: modelData
                    color: isActive ? "#ffffff" : "#888888"
                    font.pixelSize: 13
                    font.weight: isActive ? Font.Bold : Font.Normal
                }
                onClicked: root.folderClicked(modelData)
            }
        }

        // Divider
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 20
            color: "#333333"
            visible: root.folders.length > 0
        }

        // Info Text
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.wallpaperCount + " wallpapers | cache: " + root.cachedCount
            color: "#666666"
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        // Settings Button
        MouseArea {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingsToggled()

            Text {
                anchors.centerIn: parent
                text: "⚙"
                font.pixelSize: 14
                color: root.settingsOpen ? "#6a9eff" : "#888888"
            }
        }
    }
}
