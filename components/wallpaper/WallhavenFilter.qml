import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components.common
import qs.services

/*
* WallhavenFilter — Staggered filter panel (npaper pill style).
* Each filter group is an independent pill bar, arranged in a
* natural flow layout with horizontal stagger.
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
    if (filterVisible) {
      root.visible = true;
      root.focus = true;
    }
    _animTarget = filterVisible ? 1.0 : 0.0;
    _anim.restart();
  }

  function _triggerSearch() {
    var now = new Date().getTime();
    if (now - root._lastSearchMs < 500)
      return;
    root._lastSearchMs = now;
    if (root.whService)
      root.whService.search(1);
  }

  // ── Animated open/close ─────────────────────────────────
  z: 998
  width: Style.filterFlowWidth
  clip: true

  property real _animTarget: 0.0
  property real _animProgress: 0.0
  height: (filterFlow.implicitHeight + Style.spaceL) * _animProgress

  NumberAnimation {
    id: _anim
    target: root
    properties: "_animProgress"
    from: _animProgress
    to: _animTarget
    duration: filterVisible ? Style.animNormal : Style.animFast
    easing.type: Style.easingOutCubic
    onFinished: root.visible = _animProgress > 0.01
  }

  Component.onCompleted: visible = filterVisible

  // ── Background ──────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Style.barRadius
    color: Color.mSurfaceContainerLowest
  }

  // ── Flow Layout: groups stagger naturally ───────────────
  Flow {
    id: filterFlow
    x: (parent.width - implicitWidth) / 2
    anchors.top: parent.top
    anchors.topMargin: Style.spaceM
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.spaceM
    spacing: Style.spaceM
    layoutDirection: Qt.LeftToRight

    // ── Group: Categories ─────────────────────────────────
    FilterGroup {
      label: "CAT"
      FilterPill {
        label: "General"
        active: root.whService && root.whService.categories[0] === "1"
        onClicked: {
          _toggleBit(root.whService, "categories", 0);
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "Anime"
        active: root.whService && root.whService.categories[1] === "1"
        onClicked: {
          _toggleBit(root.whService, "categories", 1);
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "People"
        active: root.whService && root.whService.categories[2] === "1"
        onClicked: {
          _toggleBit(root.whService, "categories", 2);
          root._triggerSearch();
        }
      }
    }

    // ── Group: Purity ─────────────────────────────────────
    FilterGroup {
      label: "PUR"
      FilterPill {
        label: "SFW"
        active: root.whService && root.whService.purity[0] === "1"
        onClicked: {
          _toggleBit(root.whService, "purity", 0);
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "Sketchy"
        active: root.whService && root.whService.purity[1] === "1"
        onClicked: {
          _toggleBit(root.whService, "purity", 1);
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "NSFW"
        active: root.whService && root.whService.purity[2] === "1"
        onClicked: {
          _toggleBit(root.whService, "purity", 2);
          root._triggerSearch();
        }
      }
    }

    // ── Group: Sort ───────────────────────────────────────
    FilterGroup {
      label: "SORT"
      FilterPill {
        label: "Top"
        active: root.whService && root.whService.sorting === "toplist"
        onClicked: {
          if (root.whService)
            root.whService.sorting = "toplist";
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "New"
        active: root.whService && root.whService.sorting === "date_added"
        onClicked: {
          if (root.whService)
            root.whService.sorting = "date_added";
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "Views"
        active: root.whService && root.whService.sorting === "views"
        onClicked: {
          if (root.whService)
            root.whService.sorting = "views";
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "Random"
        active: root.whService && root.whService.sorting === "random"
        onClicked: {
          if (root.whService)
            root.whService.sorting = "random";
          root._triggerSearch();
        }
      }
    }

    // ── Group: Top Range ──────────────────────────────────
    FilterGroup {
      label: "RANGE"
      FilterPill {
        label: "1M"
        active: root.whService && root.whService.topRange === "1M"
        onClicked: {
          if (root.whService)
            root.whService.topRange = "1M";
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "3M"
        active: root.whService && root.whService.topRange === "3M"
        onClicked: {
          if (root.whService)
            root.whService.topRange = "3M";
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "6M"
        active: root.whService && root.whService.topRange === "6M"
        onClicked: {
          if (root.whService)
            root.whService.topRange = "6M";
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "1Y"
        active: root.whService && root.whService.topRange === "1Y"
        onClicked: {
          if (root.whService)
            root.whService.topRange = "1Y";
          root._triggerSearch();
        }
      }
    }

    // ── Group: Resolution ─────────────────────────────────
    FilterGroup {
      label: "MIN RES"
      FilterPill {
        label: "Any"
        active: root.whService && root.whService.atleast === ""
        onClicked: {
          if (root.whService)
            root.whService.atleast = "";
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "1080p"
        active: root.whService && root.whService.atleast === "1920x1080"
        onClicked: {
          if (root.whService)
            root.whService.atleast = "1920x1080";
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "2K"
        active: root.whService && root.whService.atleast === "2560x1440"
        onClicked: {
          if (root.whService)
            root.whService.atleast = "2560x1440";
          root._triggerSearch();
        }
      }
      FilterPill {
        label: "4K"
        active: root.whService && root.whService.atleast === "3840x2160"
        onClicked: {
          if (root.whService)
            root.whService.atleast = "3840x2160";
          root._triggerSearch();
        }
      }
    }

    // ── Pagination ────────────────────────────────────────
    FilterGroup {
      label: "PAGE"
      FilterPill {
        label: "‹"
        active: false
        enabled: root.whService && root.whService.currentPage > 1
        onClicked: {
          if (root.whService)
            root.whService.search(root.whService.currentPage - 1);
        }
      }
      Text {
        id: pageText
        text: {
          if (!root.whService)
            return "";
          return root.whService.currentPage + "/" + root.whService.lastPage;
        }
        color: Color.mOutline
        font.pixelSize: Style.barTabFontSize
        font.weight: Font.Medium
      }
      FilterPill {
        label: "›"
        active: false
        enabled: root.whService && root.whService.hasMore
        onClicked: {
          if (root.whService)
            root.whService.search(root.whService.currentPage + 1);
        }
      }
    }

    // ── Results indicator ─────────────────────────────────
    Item {
      height: Style.barSearchHeight + Style.spaceM
      width: resText.implicitWidth + Style.spaceXXXL
      Rectangle {
        anchors.fill: parent
        radius: Style.barRadius
        color: Color.mSurfaceContainerLow
      }
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
        color: root.whService && root.whService.errorText ? "#ff5555" : Color.mOutline
        font.pixelSize: Style.barTabFontSize
        font.weight: Font.Medium
      }
    }
  }

  // ── Keyboard: Page navigation ───────────────────────────
  Keys.onPressed: event => {
                    if (!root.whService)
                    return;
                    if (event.key === Qt.Key_PageDown || event.key === Qt.Key_BracketRight) {
                      if (root.whService.hasMore)
                      root.whService.search(root.whService.currentPage + 1);
                      event.accepted = true;
                    }
                    if (event.key === Qt.Key_PageUp || event.key === Qt.Key_BracketLeft) {
                      if (root.whService.currentPage > 1)
                      root.whService.search(root.whService.currentPage - 1);
                      event.accepted = true;
                    }
                  }

  // ── Helper ──────────────────────────────────────────────
  function _toggleBit(service, prop, bit) {
    if (!service)
      return;
    var c = service[prop].split("");
    c[bit] = c[bit] === "1" ? "0" : "1";
    if (c.join("") === "000")
      return;
    service[prop] = c.join("");
  }
}
