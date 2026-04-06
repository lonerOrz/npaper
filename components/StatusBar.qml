import QtQuick

Item {
  id: root

  required property int wallpaperCount
  required property int cachedCount
  required property int queueCount
  required property string activeFolder

  Text {
    anchors.right: parent.right
    text: (root.activeFolder ? root.activeFolder + " · " : "") +
          root.wallpaperCount + " wallpapers | cache: " +
          root.cachedCount + " | queue: " + root.queueCount
    color: "#666666"
    font.pixelSize: 11
  }
}
