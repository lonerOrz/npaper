import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SettingsSlider.qml"
import "SettingsToggle.qml"
import "SectionHeader.qml"

Rectangle {
    id: root
    color: "transparent"
    visible: isOpen && viewModel

    property var viewModel
    property bool isOpen: false
    property int activeTab: 0

    signal closed

    // Safe accessors
    function get(key, def) { return viewModel ? viewModel.get(key, def) : def }
    function set(key, val) { if (viewModel) viewModel.set(key, val) }

    // Background Overlay
    Rectangle {
        id: dimOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: isOpen ? 0.6 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.isOpen = false
                root.closed()
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    // Main Panel
    Rectangle {
        id: panel
        width: 640
        height: 540
        anchors.centerIn: parent
        radius: 16
        color: "#1a1a1a"
        border.color: "#333333"
        border.width: 1

        scale: isOpen ? 1.0 : 0.95
        opacity: isOpen ? 1.0 : 0
        y: isOpen ? 0 : 20

        Behavior on scale {
            NumberAnimation { duration: 250; easing.type: Easing.OutBack }
        }
        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Settings"
                    color: "#ffffff"
                    font.pixelSize: 22
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                MouseArea {
                    width: 36; height: 36
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.isOpen = false; root.closed() }

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: closeMouse.containsMouse ? "#333333" : "transparent"
                        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#888888"
                        font.pixelSize: 16
                    }
                }
            }

            // Tabs
            Row {
                id: tabBar
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Repeater {
                    model: ["Carousel", "Animation", "Appearance"]
                    delegate: MouseArea {
                        required property string modelData
                        required property int index
                        property bool isActive: root.activeTab === index

                        width: tabText.implicitWidth + 24
                        height: 36
                        cursorShape: Qt.PointingHandCursor

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 6
                            color: isActive ? "#ffffff" : "transparent"
                            visible: isActive
                        }

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: modelData
                            color: isActive ? "#000000" : "#888888"
                            font.pixelSize: 14
                            font.weight: isActive ? Font.DemiBold : Font.Normal
                        }

                        onClicked: root.activeTab = index
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#333333" }

            // Content
            StackLayout {
                id: stackContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.activeTab

                // 1. Carousel
                ScrollView {
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    Column {
                        spacing: 20
                        width: stackContent.width - 20
                        leftPadding: 10; rightPadding: 10

                        SectionHeader { text: "Dimensions" }
                        SettingsSlider { text: "Item Width"; value: get("carouselItemWidth"); from: 200; to: 800; onUserValueChanged: set("carouselItemWidth", value) }
                        SettingsSlider { text: "Item Height"; value: get("carouselItemHeight"); from: 150; to: 600; onUserValueChanged: set("carouselItemHeight", value) }
                        SettingsSlider { text: "Spacing"; value: get("carouselSpacing"); from: 0; to: 100; onUserValueChanged: set("carouselSpacing", value) }

                        SectionHeader { text: "3D Perspective" }
                        SettingsSlider { text: "Rotation"; value: get("carouselRotation"); from: 0; to: 90; onUserValueChanged: set("carouselRotation", value) }
                        SettingsSlider { text: "Perspective"; value: get("carouselPerspective"); from: 0.1; to: 1.0; stepSize: 0.05; onUserValueChanged: set("carouselPerspective", value) }
                    }
                }

                // 2. Animation
                ScrollView {
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    Column {
                        spacing: 20
                        width: stackContent.width - 20
                        leftPadding: 10; rightPadding: 10

                        SectionHeader { text: "Timing" }
                        SettingsSlider { text: "Scroll Duration"; value: get("scrollDuration"); from: 100; to: 800; stepSize: 10; onUserValueChanged: set("scrollDuration", value) }
                        SettingsSlider { text: "BG Slide Speed"; value: get("bgSlideDuration"); from: 100; to: 1000; stepSize: 10; onUserValueChanged: set("bgSlideDuration", value) }

                        SectionHeader { text: "Parallax" }
                        SettingsSlider { text: "BG Parallax Factor"; value: get("bgParallaxFactor"); from: 0; to: 100; onUserValueChanged: set("bgParallaxFactor", value) }
                    }
                }

                // 3. Appearance
                ScrollView {
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    Column {
                        spacing: 20
                        width: stackContent.width - 20
                        leftPadding: 10; rightPadding: 10

                        SectionHeader { text: "Visual Effects" }
                        SettingsToggle { text: "Show Border Glow"; checked: get("showBorderGlow"); onToggled: set("showBorderGlow", val) }
                        SettingsToggle { text: "Show Shadow"; checked: get("showShadow"); onToggled: set("showShadow", val) }
                        SettingsToggle { text: "Show BG Preview"; checked: get("showBgPreview"); onToggled: set("showBgPreview", val) }

                        SectionHeader { text: "Overlay" }
                        SettingsSlider { text: "BG Overlay Opacity"; value: get("bgOverlayOpacity"); from: 0.0; to: 1.0; stepSize: 0.05; onUserValueChanged: set("bgOverlayOpacity", value) }

                        SectionHeader { text: "Debug" }
                        SettingsToggle { text: "Debug Mode"; checked: get("debugMode"); onToggled: set("debugMode", val) }
                    }
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.isOpen = false
            root.closed()
            event.accepted = true
        }
    }
}
