import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services

/*
 * WallhavenFilter — Filter bar overlay (similar to SettingsPanel).
 * Opens upward from the status bar when Wallhaven mode is active.
 */
Item {
  id: root

  property bool filterVisible: false
  property var whService: null
  property var adapter: null
  property real _lastSearchMs: 0
  property bool _initialSearchDone: false

  signal closeRequested

  onFilterVisibleChanged: {
    if (filterVisible && !_initialSearchDone && root.whService) {
      _initialSearchDone = true;
      root.whService.search(1);
    }
  }

  function _triggerSearch() {
    // Prevent rapid-fire requests (500ms cooldown)
    var now = new Date().getTime();
    if (now - root._lastSearchMs < 500)
      return;
    root._lastSearchMs = now;
    if (root.whService)
      root.whService.search(1);
  }

  // Simple show/hide — no animation for now
  visible: filterVisible
  width: filterRow.implicitWidth + Style.spaceXXXL * 2
  height: Style.barSearchHeight + Style.spaceS

  // ── Background ──────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Style.barRadius
    color: Color.mSurfaceContainerLowest
  }

  RowLayout {
    id: filterRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.spaceS

    // Categories
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: "CAT"
      font.pixelSize: Style.fontXXS
      font.weight: Font.Bold
      color: Color.mOutline
    }

    Repeater {
      model: ["General", "Anime", "People"]
      delegate: MouseArea {
        width: filterText.implicitWidth + Style.spaceXXXL
        height: Style.barSearchHeight
        cursorShape: Qt.PointingHandCursor
        property int bit: index
        property bool active: root.whService && root.whService.categories[bit] === "1"

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: parent.active ? Color.mPrimary : Color.mSurfaceContainer
          Behavior on color { ColorAnimation { duration: Style.animFast } }
        }

        Text {
          id: filterText
          anchors.centerIn: parent
          text: modelData
          color: parent.parent.active ? Color.mSurfaceContainerLowest : Color.mOutlineVariant
          font.pixelSize: Style.barTabFontSize
          font.weight: Font.Medium
        }

        onClicked: {
          if (!root.whService) return;
          var c = root.whService.categories.split("");
          c[bit] = c[bit] === "1" ? "0" : "1";
          if (c.join("") === "000") return;
          root.whService.categories = c.join("");
          root._triggerSearch();
        }
      }
    }

    // Divider
    Rectangle {
      Layout.preferredWidth: Style.borderS
      Layout.preferredHeight: Style.barDividerHeight
      color: Color.mOutlineVariant
      opacity: Style.opacityDivider
    }

    // Purity
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: "PUR"
      font.pixelSize: Style.fontXXS
      font.weight: Font.Bold
      color: Color.mOutline
    }

    Repeater {
      model: [{ label: "SFW", bit: 0 }, { label: "Sketchy", bit: 1 }, { label: "NSFW", bit: 2 }]
      delegate: MouseArea {
        width: purText.implicitWidth + Style.spaceXXXL
        height: Style.barSearchHeight
        cursorShape: Qt.PointingHandCursor
        property bool active: root.whService && root.whService.purity[modelData.bit] === "1"

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: parent.active ? Color.mPrimary : Color.mSurfaceContainer
          Behavior on color { ColorAnimation { duration: Style.animFast } }
        }

        Text {
          id: purText
          anchors.centerIn: parent
          text: modelData.label
          color: parent.parent.active ? Color.mSurfaceContainerLowest : Color.mOutlineVariant
          font.pixelSize: Style.barTabFontSize
          font.weight: Font.Medium
        }

        onClicked: {
          if (!root.whService) return;
          var c = root.whService.purity.split("");
          c[modelData.bit] = c[modelData.bit] === "1" ? "0" : "1";
          if (c.join("") === "000") return;
          root.whService.purity = c.join("");
          root._triggerSearch();
        }
      }
    }

    // Divider
    Rectangle {
      Layout.preferredWidth: Style.borderS
      Layout.preferredHeight: Style.barDividerHeight
      color: Color.mOutlineVariant
      opacity: Style.opacityDivider
    }

    // Sort
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: "SORT"
      font.pixelSize: Style.fontXXS
      font.weight: Font.Bold
      color: Color.mOutline
    }

    Repeater {
      model: [{ key: "toplist", label: "Top" }, { key: "date_added", label: "New" }, { key: "views", label: "Views" }, { key: "random", label: "Random" }]
      delegate: MouseArea {
        width: sortText.implicitWidth + Style.spaceXXXL
        height: Style.barSearchHeight
        cursorShape: Qt.PointingHandCursor
        property bool active: root.whService && root.whService.sorting === modelData.key

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: parent.active ? Color.mPrimary : Color.mSurfaceContainer
          Behavior on color { ColorAnimation { duration: Style.animFast } }
        }

        Text {
          id: sortText
          anchors.centerIn: parent
          text: modelData.label
          color: parent.parent.active ? Color.mSurfaceContainerLowest : Color.mOutlineVariant
          font.pixelSize: Style.barTabFontSize
          font.weight: Font.Medium
        }

        onClicked: {
          if (!root.whService) return;
          root.whService.sorting = modelData.key;
          root._triggerSearch();
        }
      }
    }

    // Divider
    Rectangle {
      Layout.preferredWidth: Style.borderS
      Layout.preferredHeight: Style.barDividerHeight
      color: Color.mOutlineVariant
      opacity: Style.opacityDivider
    }

    // Resolution
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: "MIN RES"
      font.pixelSize: Style.fontXXS
      font.weight: Font.Bold
      color: Color.mOutline
    }

    Repeater {
      model: [{ label: "Any", value: "" }, { label: "1080p", value: "1920x1080" }, { label: "2K", value: "2560x1440" }, { label: "4K", value: "3840x2160" }]
      delegate: MouseArea {
        width: resText.implicitWidth + Style.spaceXXXL
        height: Style.barSearchHeight
        cursorShape: Qt.PointingHandCursor
        property bool active: root.whService && root.whService.atleast === modelData.value

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: parent.active ? Color.mPrimary : Color.mSurfaceContainer
          Behavior on color { ColorAnimation { duration: Style.animFast } }
        }

        Text {
          id: resText
          anchors.centerIn: parent
          text: modelData.label
          color: parent.parent.active ? Color.mSurfaceContainerLowest : Color.mOutlineVariant
          font.pixelSize: Style.barTabFontSize
          font.weight: Font.Medium
        }

        onClicked: {
          if (!root.whService) return;
          root.whService.atleast = modelData.value;
          root._triggerSearch();
        }
      }
    }

    // Results indicator
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: {
        if (!root.whService) return "";
        if (root.whService.loading) return "Searching...";
        if (root.whService.errorText) return root.whService.errorText;
        return root.whService.results.length + " results";
      }
      color: {
        if (!root.whService) return Color.mOutlineVariant;
        if (root.whService.errorText) return "#ff5555";
        return Color.mOutlineVariant;
      }
      font.pixelSize: Style.fontS
    }
  }
}
