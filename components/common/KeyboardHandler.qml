import QtQuick

Item {
  id: root

  property var appViewModel: null
  property var wallhavenFilter: null

  signal applyRequested()
  signal randomRequested()
  signal wallhavenToggled()

  function handleKeyPress(event) {
    if (event.key === Qt.Key_Escape) {
      appViewModel.handleRequestQuit();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_S && !event.modifiers) {
      appViewModel.toggleSettings();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_W && !event.modifiers) {
      appViewModel.handleRequestToggleWallhaven(wallhavenFilter);
      wallhavenToggled();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      event.key === Qt.Key_Tab ? appViewModel.nextFolder() : appViewModel.prevFolder();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft || event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
      appViewModel.handleRequestToggleViewMode();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
      appViewModel.focusSearch();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      applyRequested();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_R && !event.modifiers) {
      randomRequested();
      appViewModel.handleRequestRandom();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_F5) {
      appViewModel.refreshCache();
      event.accepted = true;
      return;
    }
  }
}
