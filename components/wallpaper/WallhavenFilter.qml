import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components.common
import qs.services

Item {
  id: root

  property bool filterVisible: false
  property var whService: null
  property var adapter: null
  property bool _initialSearchDone: false

  signal closeRequested

  Timer {
    id: searchDebounceTimer
    interval: 350
    repeat: false
    onTriggered: {
      if (root.whService)
        root.whService.search(1);
    }
  }

  function _triggerSearch() {
    searchDebounceTimer.restart();
  }

  onFilterVisibleChanged: {
    if (filterVisible) {
      root.visible = true;
    }
    _animTarget = filterVisible ? 1.0 : 0.0;
    _anim.restart();

    if (filterVisible && !_initialSearchDone && root.whService) {
      _initialSearchDone = true;
      try {
        root.whService.search(1);
      } catch (e) {
        console.error("Wallhaven initial search error:", e);
        _initialSearchDone = false;
      }
    }
  }

  z: 998
  width: Style.filterFlowWidth
  clip: true

  property real _animTarget: 0.0
  property real _animProgress: 0.0
  height: (filterFlow.implicitHeight + Style.spaceL) * _animProgress
  opacity: _animProgress

  NumberAnimation {
    id: _anim
    target: root
    properties: "_animProgress"
    from: _animProgress
    to: _animTarget
    duration: filterVisible ? Style.animNormal : Style.animFast
    easing.type: Style.easingOutCubic
    onFinished: {
      root.visible = _animProgress > 0.01;
    }
  }

  Component.onCompleted: visible = filterVisible

  Rectangle {
    anchors.fill: parent
    radius: Style.barRadius
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Qt.rgba(Qt.lighter(Color.mSurfaceContainerLowest, 1.04).r, Qt.lighter(Color.mSurfaceContainerLowest, 1.04).g, Qt.lighter(Color.mSurfaceContainerLowest, 1.04).b, Style.filterBlurAlpha)
      }
      GradientStop {
        position: 1.0
        color: Qt.rgba(Color.mSurfaceContainerLowest.r, Color.mSurfaceContainerLowest.g, Color.mSurfaceContainerLowest.b, Style.filterBlurAlpha)
      }
    }
    border.width: 1
    border.color: Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.filterBlurAlpha * 0.5)
  }

  Flow {
    id: filterFlow
    x: (parent.width - implicitWidth) / 2
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.spaceM
    spacing: Style.spaceM
    layoutDirection: Qt.LeftToRight

    FilterGroup {
      label: "CAT"
      FilterPill {
        label: "General"
        active: root.whService && root.whService.categories[0] === "1"
        onClicked: {
          _toggleBit(root.whService, "categories", 0);
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.categories", root.whService.categories);
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "Anime"
        active: root.whService && root.whService.categories[1] === "1"
        onClicked: {
          _toggleBit(root.whService, "categories", 1);
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.categories", root.whService.categories);
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "People"
        active: root.whService && root.whService.categories[2] === "1"
        onClicked: {
          _toggleBit(root.whService, "categories", 2);
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.categories", root.whService.categories);
          root._triggerSearch();
        }
      }
    }

    FilterGroup {
      label: "PUR"
      FilterPill {
        label: "SFW"
        active: root.whService && root.whService.purity[0] === "1"
        onClicked: {
          _toggleBit(root.whService, "purity", 0);
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.purity", root.whService.purity);
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "Sketchy"
        active: root.whService && root.whService.purity[1] === "1"
        onClicked: {
          _toggleBit(root.whService, "purity", 1);
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.purity", root.whService.purity);
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "NSFW"
        active: root.whService && root.whService.purity[2] === "1"
        onClicked: {
          _toggleBit(root.whService, "purity", 2);
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.purity", root.whService.purity);
          root._triggerSearch();
        }
      }
    }

    FilterGroup {
      label: "SORT"
      FilterPill {
        label: "Top"
        active: root.whService && root.whService.sorting === "toplist"
        onClicked: {
          if (root.whService)
            root.whService.sorting = "toplist";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.sorting", "toplist");
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "New"
        active: root.whService && root.whService.sorting === "date_added"
        onClicked: {
          if (root.whService)
            root.whService.sorting = "date_added";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.sorting", "date_added");
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "Views"
        active: root.whService && root.whService.sorting === "views"
        onClicked: {
          if (root.whService)
            root.whService.sorting = "views";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.sorting", "views");
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "Random"
        active: root.whService && root.whService.sorting === "random"
        onClicked: {
          if (root.whService)
            root.whService.sorting = "random";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.sorting", "random");
          root._triggerSearch();
        }
      }
    }

    FilterGroup {
      label: "RANGE"
      opacity: (root.whService && root.whService.sorting === "toplist") ? 1.0 : 0.45
      FilterPill {
        label: "1M"
        active: root.whService && root.whService.topRange === "1M"
        onClicked: {
          if (root.whService)
            root.whService.topRange = "1M";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.topRange", "1M");
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "3M"
        active: root.whService && root.whService.topRange === "3M"
        onClicked: {
          if (root.whService)
            root.whService.topRange = "3M";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.topRange", "3M");
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "6M"
        active: root.whService && root.whService.topRange === "6M"
        onClicked: {
          if (root.whService)
            root.whService.topRange = "6M";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.topRange", "6M");
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "1Y"
        active: root.whService && root.whService.topRange === "1Y"
        onClicked: {
          if (root.whService)
            root.whService.topRange = "1Y";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.topRange", "1Y");
          root._triggerSearch();
        }
      }
    }

    FilterGroup {
      label: "MIN RES"
      FilterPill {
        label: "Any"
        active: root.whService && root.whService.atleast === ""
        onClicked: {
          if (root.whService)
            root.whService.atleast = "";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.atleast", "");
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "1080p"
        active: root.whService && root.whService.atleast === "1920x1080"
        onClicked: {
          if (root.whService)
            root.whService.atleast = "1920x1080";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.atleast", "1920x1080");
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "2K"
        active: root.whService && root.whService.atleast === "2560x1440"
        onClicked: {
          if (root.whService)
            root.whService.atleast = "2560x1440";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.atleast", "2560x1440");
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "4K"
        active: root.whService && root.whService.atleast === "3840x2160"
        onClicked: {
          if (root.whService)
            root.whService.atleast = "3840x2160";
          if (root.adapter && root.adapter.configViewModel)
            root.adapter.configViewModel.set("wallhaven.atleast", "3840x2160");
          root._triggerSearch();
        }
      }
    }

    FilterGroup {
      label: "PAGE"

      MouseArea {
        width: prevText.implicitWidth + Style.spaceXXL
        height: Style.barSearchHeight
        cursorShape: root.whService && root.whService.currentPage > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.whService && root.whService.currentPage > 1
        hoverEnabled: true
        onClicked: {
          if (root.whService)
            root.whService.search(root.whService.currentPage - 1);
        }

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: parent.enabled && parent.containsMouse ? Qt.rgba(Color.mSurfaceContainerHigh.r, Color.mSurfaceContainerHigh.g, Color.mSurfaceContainerHigh.b, Style.childHoverAlpha) : Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
          opacity: parent.enabled ? 1.0 : 0.4
        }
        Text {
          id: prevText
          anchors.centerIn: parent
          text: "‹"
          color: parent.enabled ? Color.mOnSurface : Color.mOnSurfaceVariant
          font.pixelSize: Style.barTabFontSize + 2
          font.weight: Font.Bold
        }
      }

      Rectangle {
        height: Style.barSearchHeight
        width: pageText.implicitWidth + Style.spaceXXL
        radius: height / 2
        color: Color.mPrimaryContainer
        opacity: 0.75

        Text {
          id: pageText
          anchors.centerIn: parent
          text: {
            if (!root.whService)
              return "";
            return root.whService.currentPage + "/" + root.whService.lastPage;
          }
          color: Color.mOnPrimaryContainer
          font.pixelSize: Style.barTabFontSize
          font.weight: Font.Bold
        }
      }

      MouseArea {
        width: nextText.implicitWidth + Style.spaceXXL
        height: Style.barSearchHeight
        cursorShape: root.whService && root.whService.hasMore ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.whService && root.whService.hasMore
        hoverEnabled: true
        onClicked: {
          if (root.whService)
            root.whService.search(root.whService.currentPage + 1);
        }

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: parent.enabled && parent.containsMouse ? Qt.rgba(Color.mSurfaceContainerHigh.r, Color.mSurfaceContainerHigh.g, Color.mSurfaceContainerHigh.b, Style.childHoverAlpha) : Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
          opacity: parent.enabled ? 1.0 : 0.4
        }
        Text {
          id: nextText
          anchors.centerIn: parent
          text: "›"
          color: parent.enabled ? Color.mOnSurface : Color.mOnSurfaceVariant
          font.pixelSize: Style.barTabFontSize + 2
          font.weight: Font.Bold
        }
      }
    }

    Item {
      height: Style.barSearchHeight + Style.spaceM
      width: resText.implicitWidth + Style.spaceXL * 2
      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
        border.color: Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.childBgAlpha * 0.5)
        border.width: 1

        Text {
          id: resText
          anchors.centerIn: parent
          text: {
            if (!root.whService)
              return "";
            if (root.whService.loading)
              return "Searching…";
            if (root.whService.errorText)
              return root.whService.errorText;
            return root.whService.results.length + " results";
          }
          color: root.whService && root.whService.errorText ? "#ff5555" : Color.mOnSurface
          font.pixelSize: Style.barTabFontSize
          font.weight: Font.Bold
        }
      }
    }
  }

  Keys.onPressed: event => {
    if (event.key === Qt.Key_Escape) {
      root.filterVisible = false;
      root.closeRequested();
      event.accepted = true;
      return;
    }
    if (!root.whService)
      return;
    if (event.key === Qt.Key_PageDown) {
      if (root.whService.hasMore)
        root.whService.search(root.whService.currentPage + 1);
      event.accepted = true;
    }
    if (event.key === Qt.Key_PageUp) {
      if (root.whService.currentPage > 1)
        root.whService.search(root.whService.currentPage - 1);
      event.accepted = true;
    }
  }

  function _toggleBit(service, prop, bit) {
    if (!service)
      return;
    var c = service[prop].split("");
    c[bit] = (c[bit] === "1") ? "0" : "1";
    if (c.join("") === "000")
      return;
    service[prop] = c.join("");
  }
}
