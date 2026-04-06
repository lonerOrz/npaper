import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    height: 40
    width: parent ? parent.width : 300

    property alias text: label.text
    property alias label: label.text
    property real value: 0
    property real min: 0
    property real max: 100
    property real step: 1
    
    signal commit(real val)

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Text {
            id: label
            Layout.fillWidth: true
            color: "#cccccc"
            font.pixelSize: 13
        }

        TextInput {
            id: input
            Layout.preferredWidth: 80
            Layout.alignment: Qt.AlignRight
            color: "#6a9eff"
            font.pixelSize: 13
            font.family: "monospace"
            horizontalAlignment: Text.AlignRight
            text: root.value.toFixed(root.step < 1 ? 2 : 0)
            
            onEditingFinished: {
                var val = parseFloat(text)
                if (!isNaN(val)) {
                    val = Math.max(root.min, Math.min(root.max, val))
                    root.commit(val)
                }
                text = root.value.toFixed(root.step < 1 ? 2 : 0)
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: 4
                color: input.focus ? "#333333" : "transparent"
            }
        }

        Slider {
            Layout.fillWidth: true
            from: root.min
            to: root.max
            stepSize: root.step
            value: root.value
            onMoved: {
                input.text = value.toFixed(root.step < 1 ? 2 : 0)
                root.commit(value)
            }
            
            background: Rectangle {
                implicitHeight: 4
                color: "#222222"
                radius: 2
                Rectangle {
                    width: parent.visualPosition * parent.width
                    height: parent.height
                    color: "#6a9eff"
                    radius: 2
                }
            }
            handle: Rectangle {
                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                implicitWidth: 14; implicitHeight: 14
                radius: 7
                color: "#6a9eff"
            }
        }
    }
}
