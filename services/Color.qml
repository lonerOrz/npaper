pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Color palette singleton — loads ~/.config/npaper/color.json
 *
 * Defaults are defined in _defaults. When color.json exists,
 * it overrides matching keys. FileView watches for hot-reload.
 *
 * Usage:
 *   import qs.services
 *   color: Color.mPrimary
 */
Singleton {
  id: root

  // ── Defaults ──────────────────────────────────────────────
  readonly property var _defaults: ({
    "mPrimary": "#6a9eff",
    "mOnPrimary": "#001E2C",
    "mPrimaryContainer": "#3b82f6",
    "mOnPrimaryContainer": "#60a5fa",
    "mSecondary": "#B2CADD",
    "mOnSecondary": "#1C3342",
    "mSecondaryContainer": "#354C5C",
    "mOnSecondaryContainer": "#CFE7FB",
    "mTertiary": "#92CDFD",
    "mOnTertiary": "#003450",
    "mTertiaryContainer": "#5B96C4",
    "mOnTertiaryContainer": "#000000",
    "mError": "#FFB4AB",
    "mOnError": "#690005",
    "mErrorContainer": "#93000A",
    "mOnErrorContainer": "#FFDAD6",
    "mSurface": "#101416",
    "mOnSurface": "#E0E3E6",
    "mSurfaceVariant": "#40484D",
    "mOnSurfaceVariant": "#BFC8CE",
    "mSurfaceContainerLowest": "#0B0F11",
    "mSurfaceContainerLow": "#191C1E",
    "mSurfaceContainer": "#1D2022",
    "mSurfaceContainerHigh": "#272A2D",
    "mSurfaceContainerHighest": "#323538",
    "mInverseSurface": "#E0E3E6",
    "mInverseOnSurface": "#2D3133",
    "mInversePrimary": "#076689",
    "mSurfaceDim": "#101416",
    "mSurfaceBright": "#363A3C",
    "mOutline": "#899298",
    "mOutlineVariant": "#40484D",
    "mShadow": "#000000",
    "mScrim": "#000000",
    "mPrimaryFixed": "#C3E8FF",
    "mPrimaryFixedDim": "#89CFF7",
    "mOnPrimaryFixed": "#001E2C",
    "mOnPrimaryFixedVariant": "#004C68",
    "mSecondaryFixed": "#CDE6F9",
    "mSecondaryFixedDim": "#B2CADD",
    "mOnSecondaryFixed": "#041E2C",
    "mOnSecondaryFixedVariant": "#334959",
    "mTertiaryFixed": "#CBE6FF",
    "mTertiaryFixedDim": "#92CDFD",
    "mOnTertiaryFixed": "#001E30",
    "mOnTertiaryFixedVariant": "#004B71"
  })

  // ── Live color properties ─────────────────────────────────
  property color mPrimary: _defaults.mPrimary
  property color mOnPrimary: _defaults.mOnPrimary
  property color mPrimaryContainer: _defaults.mPrimaryContainer
  property color mOnPrimaryContainer: _defaults.mOnPrimaryContainer
  property color mSecondary: _defaults.mSecondary
  property color mOnSecondary: _defaults.mOnSecondary
  property color mSecondaryContainer: _defaults.mSecondaryContainer
  property color mOnSecondaryContainer: _defaults.mOnSecondaryContainer
  property color mTertiary: _defaults.mTertiary
  property color mOnTertiary: _defaults.mOnTertiary
  property color mTertiaryContainer: _defaults.mTertiaryContainer
  property color mOnTertiaryContainer: _defaults.mOnTertiaryContainer
  property color mError: _defaults.mError
  property color mOnError: _defaults.mOnError
  property color mErrorContainer: _defaults.mErrorContainer
  property color mOnErrorContainer: _defaults.mOnErrorContainer
  property color mSurface: _defaults.mSurface
  property color mOnSurface: _defaults.mOnSurface
  property color mSurfaceVariant: _defaults.mSurfaceVariant
  property color mOnSurfaceVariant: _defaults.mOnSurfaceVariant
  property color mSurfaceContainerLowest: _defaults.mSurfaceContainerLowest
  property color mSurfaceContainerLow: _defaults.mSurfaceContainerLow
  property color mSurfaceContainer: _defaults.mSurfaceContainer
  property color mSurfaceContainerHigh: _defaults.mSurfaceContainerHigh
  property color mSurfaceContainerHighest: _defaults.mSurfaceContainerHighest
  property color mInverseSurface: _defaults.mInverseSurface
  property color mInverseOnSurface: _defaults.mInverseOnSurface
  property color mInversePrimary: _defaults.mInversePrimary
  property color mSurfaceDim: _defaults.mSurfaceDim
  property color mSurfaceBright: _defaults.mSurfaceBright
  property color mOutline: _defaults.mOutline
  property color mOutlineVariant: _defaults.mOutlineVariant
  property color mShadow: _defaults.mShadow
  property color mScrim: _defaults.mScrim
  property color mPrimaryFixed: _defaults.mPrimaryFixed
  property color mPrimaryFixedDim: _defaults.mPrimaryFixedDim
  property color mOnPrimaryFixed: _defaults.mOnPrimaryFixed
  property color mOnPrimaryFixedVariant: _defaults.mOnPrimaryFixedVariant
  property color mSecondaryFixed: _defaults.mSecondaryFixed
  property color mSecondaryFixedDim: _defaults.mSecondaryFixedDim
  property color mOnSecondaryFixed: _defaults.mOnSecondaryFixed
  property color mOnSecondaryFixedVariant: _defaults.mOnSecondaryFixedVariant
  property color mTertiaryFixed: _defaults.mTertiaryFixed
  property color mTertiaryFixedDim: _defaults.mTertiaryFixedDim
  property color mOnTertiaryFixed: _defaults.mOnTertiaryFixed
  property color mOnTertiaryFixedVariant: _defaults.mOnTertiaryFixedVariant

  // ── FileView: Load & Hot-Reload ───────────────────────────
  readonly property string colorPath: Quickshell.env("HOME") + "/.config/npaper/color.json"

  FileView {
    id: colorFile
    path: root.colorPath
    watchChanges: true
    printErrors: false

    onLoaded: {
      try {
        var t = colorFile.text();
        if (t) _apply(JSON.parse(t));
      } catch (e) { /* invalid JSON → keep defaults */ }
    }
    onFileChanged: reload()
  }

  function _apply(cfg) {
    if (!cfg) return;
    for (var k in cfg) {
      if (root[k] !== undefined)
        root[k] = cfg[k];
    }
  }
}
