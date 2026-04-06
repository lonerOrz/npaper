pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Color palette singleton — loads ~/.config/npaper/color.json
 * Keys match color.json exactly (e.g., Color.mPrimary → JSON mPrimary).
 *
 * Usage:
 *   import qs.utils
 *   color: Color.mPrimary
 */
Singleton {
  id: root

  // ========== Default Palette (current hardcoded values) ==========

  QtObject {
    id: defaults

    readonly property color mPrimary:                "#6a9eff"
    readonly property color mOnPrimary:              "#001E2C"
    readonly property color mPrimaryContainer:       "#3b82f6"
    readonly property color mOnPrimaryContainer:     "#60a5fa"
    readonly property color mSecondary:              "#B2CADD"
    readonly property color mOnSecondary:            "#1C3342"
    readonly property color mSecondaryContainer:     "#354C5C"
    readonly property color mOnSecondaryContainer:   "#CFE7FB"
    readonly property color mTertiary:               "#92CDFD"
    readonly property color mOnTertiary:             "#003450"
    readonly property color mTertiaryContainer:      "#5B96C4"
    readonly property color mOnTertiaryContainer:    "#000000"
    readonly property color mError:                  "#FFB4AB"
    readonly property color mOnError:                "#690005"
    readonly property color mErrorContainer:         "#93000A"
    readonly property color mOnErrorContainer:       "#FFDAD6"
    readonly property color mSurface:                "#101416"
    readonly property color mOnSurface:              "#E0E3E6"
    readonly property color mSurfaceVariant:         "#40484D"
    readonly property color mOnSurfaceVariant:       "#BFC8CE"
    readonly property color mSurfaceContainerLowest: "#0B0F11"
    readonly property color mSurfaceContainerLow:    "#191C1E"
    readonly property color mSurfaceContainer:       "#1D2022"
    readonly property color mSurfaceContainerHigh:   "#272A2D"
    readonly property color mSurfaceContainerHighest:"#323538"
    readonly property color mInverseSurface:         "#E0E3E6"
    readonly property color mInverseOnSurface:       "#2D3133"
    readonly property color mInversePrimary:         "#076689"
    readonly property color mSurfaceDim:             "#101416"
    readonly property color mSurfaceBright:          "#363A3C"
    readonly property color mOutline:                "#899298"
    readonly property color mOutlineVariant:         "#40484D"
    readonly property color mShadow:                 "#000000"
    readonly property color mScrim:                  "#000000"
    readonly property color mPrimaryFixed:           "#C3E8FF"
    readonly property color mPrimaryFixedDim:        "#89CFF7"
    readonly property color mOnPrimaryFixed:         "#001E2C"
    readonly property color mOnPrimaryFixedVariant:  "#004C68"
    readonly property color mSecondaryFixed:         "#CDE6F9"
    readonly property color mSecondaryFixedDim:      "#B2CADD"
    readonly property color mOnSecondaryFixed:       "#041E2C"
    readonly property color mOnSecondaryFixedVariant:"#334959"
    readonly property color mTertiaryFixed:          "#CBE6FF"
    readonly property color mTertiaryFixedDim:       "#92CDFD"
    readonly property color mOnTertiaryFixed:        "#001E30"
    readonly property color mOnTertiaryFixedVariant: "#004B71"
  }

  // ========== Live Color Properties (bound to color.json) ==========

  property color mPrimary:                defaults.mPrimary
  property color mOnPrimary:              defaults.mOnPrimary
  property color mPrimaryContainer:       defaults.mPrimaryContainer
  property color mOnPrimaryContainer:     defaults.mOnPrimaryContainer
  property color mSecondary:              defaults.mSecondary
  property color mOnSecondary:            defaults.mOnSecondary
  property color mSecondaryContainer:     defaults.mSecondaryContainer
  property color mOnSecondaryContainer:   defaults.mOnSecondaryContainer
  property color mTertiary:               defaults.mTertiary
  property color mOnTertiary:             defaults.mOnTertiary
  property color mTertiaryContainer:      defaults.mTertiaryContainer
  property color mOnTertiaryContainer:    defaults.mOnTertiaryContainer
  property color mError:                  defaults.mError
  property color mOnError:                defaults.mOnError
  property color mErrorContainer:         defaults.mErrorContainer
  property color mOnErrorContainer:       defaults.mOnErrorContainer
  property color mSurface:                defaults.mSurface
  property color mOnSurface:              defaults.mOnSurface
  property color mSurfaceVariant:         defaults.mSurfaceVariant
  property color mOnSurfaceVariant:       defaults.mOnSurfaceVariant
  property color mSurfaceContainerLowest: defaults.mSurfaceContainerLowest
  property color mSurfaceContainerLow:    defaults.mSurfaceContainerLow
  property color mSurfaceContainer:       defaults.mSurfaceContainer
  property color mSurfaceContainerHigh:   defaults.mSurfaceContainerHigh
  property color mSurfaceContainerHighest:defaults.mSurfaceContainerHighest
  property color mInverseSurface:         defaults.mInverseSurface
  property color mInverseOnSurface:       defaults.mInverseOnSurface
  property color mInversePrimary:         defaults.mInversePrimary
  property color mSurfaceDim:             defaults.mSurfaceDim
  property color mSurfaceBright:          defaults.mSurfaceBright
  property color mOutline:                defaults.mOutline
  property color mOutlineVariant:         defaults.mOutlineVariant
  property color mShadow:                 defaults.mShadow
  property color mScrim:                  defaults.mScrim
  property color mPrimaryFixed:           defaults.mPrimaryFixed
  property color mPrimaryFixedDim:        defaults.mPrimaryFixedDim
  property color mOnPrimaryFixed:         defaults.mOnPrimaryFixed
  property color mOnPrimaryFixedVariant:  defaults.mOnPrimaryFixedVariant
  property color mSecondaryFixed:         defaults.mSecondaryFixed
  property color mSecondaryFixedDim:      defaults.mSecondaryFixedDim
  property color mOnSecondaryFixed:       defaults.mOnSecondaryFixed
  property color mOnSecondaryFixedVariant:defaults.mOnSecondaryFixedVariant
  property color mTertiaryFixed:          defaults.mTertiaryFixed
  property color mTertiaryFixedDim:       defaults.mTertiaryFixedDim
  property color mOnTertiaryFixed:        defaults.mOnTertiaryFixed
  property color mOnTertiaryFixedVariant: defaults.mOnTertiaryFixedVariant

  // ========== FileView: Load & Hot-Reload color.json ==========

  readonly property string colorPath: Quickshell.env("HOME") + "/.config/npaper/color.json"

  FileView {
    id: colorFile
    path: root.colorPath
    watchChanges: true
    printErrors: false

    onLoaded: {
      try {
        _apply(JSON.parse(text()));
      } catch (e) { /* invalid JSON → keep defaults */ }
    }

    onFileChanged: reload()
  }

  function _apply(cfg) {
    if (!cfg) return;
    if (cfg.mPrimary)                root.mPrimary                = cfg.mPrimary;
    if (cfg.mOnPrimary)              root.mOnPrimary              = cfg.mOnPrimary;
    if (cfg.mPrimaryContainer)       root.mPrimaryContainer       = cfg.mPrimaryContainer;
    if (cfg.mOnPrimaryContainer)     root.mOnPrimaryContainer     = cfg.mOnPrimaryContainer;
    if (cfg.mSecondary)              root.mSecondary              = cfg.mSecondary;
    if (cfg.mOnSecondary)            root.mOnSecondary            = cfg.mOnSecondary;
    if (cfg.mSecondaryContainer)     root.mSecondaryContainer     = cfg.mSecondaryContainer;
    if (cfg.mOnSecondaryContainer)   root.mOnSecondaryContainer   = cfg.mOnSecondaryContainer;
    if (cfg.mTertiary)               root.mTertiary               = cfg.mTertiary;
    if (cfg.mOnTertiary)             root.mOnTertiary             = cfg.mOnTertiary;
    if (cfg.mTertiaryContainer)      root.mTertiaryContainer      = cfg.mTertiaryContainer;
    if (cfg.mOnTertiaryContainer)    root.mOnTertiaryContainer    = cfg.mOnTertiaryContainer;
    if (cfg.mError)                  root.mError                  = cfg.mError;
    if (cfg.mOnError)                root.mOnError                = cfg.mOnError;
    if (cfg.mErrorContainer)         root.mErrorContainer         = cfg.mErrorContainer;
    if (cfg.mOnErrorContainer)       root.mOnErrorContainer       = cfg.mOnErrorContainer;
    if (cfg.mSurface)                root.mSurface                = cfg.mSurface;
    if (cfg.mOnSurface)              root.mOnSurface              = cfg.mOnSurface;
    if (cfg.mSurfaceVariant)         root.mSurfaceVariant         = cfg.mSurfaceVariant;
    if (cfg.mOnSurfaceVariant)       root.mOnSurfaceVariant       = cfg.mOnSurfaceVariant;
    if (cfg.mSurfaceContainerLowest) root.mSurfaceContainerLowest = cfg.mSurfaceContainerLowest;
    if (cfg.mSurfaceContainerLow)    root.mSurfaceContainerLow    = cfg.mSurfaceContainerLow;
    if (cfg.mSurfaceContainer)       root.mSurfaceContainer       = cfg.mSurfaceContainer;
    if (cfg.mSurfaceContainerHigh)   root.mSurfaceContainerHigh   = cfg.mSurfaceContainerHigh;
    if (cfg.mSurfaceContainerHighest)root.mSurfaceContainerHighest= cfg.mSurfaceContainerHighest;
    if (cfg.mInverseSurface)         root.mInverseSurface         = cfg.mInverseSurface;
    if (cfg.mInverseOnSurface)       root.mInverseOnSurface       = cfg.mInverseOnSurface;
    if (cfg.mInversePrimary)         root.mInversePrimary         = cfg.mInversePrimary;
    if (cfg.mSurfaceDim)             root.mSurfaceDim             = cfg.mSurfaceDim;
    if (cfg.mSurfaceBright)          root.mSurfaceBright          = cfg.mSurfaceBright;
    if (cfg.mOutline)                root.mOutline                = cfg.mOutline;
    if (cfg.mOutlineVariant)         root.mOutlineVariant         = cfg.mOutlineVariant;
    if (cfg.mShadow)                 root.mShadow                 = cfg.mShadow;
    if (cfg.mScrim)                  root.mScrim                  = cfg.mScrim;
    if (cfg.mPrimaryFixed)           root.mPrimaryFixed           = cfg.mPrimaryFixed;
    if (cfg.mPrimaryFixedDim)        root.mPrimaryFixedDim        = cfg.mPrimaryFixedDim;
    if (cfg.mOnPrimaryFixed)         root.mOnPrimaryFixed         = cfg.mOnPrimaryFixed;
    if (cfg.mOnPrimaryFixedVariant)  root.mOnPrimaryFixedVariant  = cfg.mOnPrimaryFixedVariant;
    if (cfg.mSecondaryFixed)         root.mSecondaryFixed         = cfg.mSecondaryFixed;
    if (cfg.mSecondaryFixedDim)      root.mSecondaryFixedDim      = cfg.mSecondaryFixedDim;
    if (cfg.mOnSecondaryFixed)       root.mOnSecondaryFixed       = cfg.mOnSecondaryFixed;
    if (cfg.mOnSecondaryFixedVariant) root.mOnSecondaryFixedVariant = cfg.mOnSecondaryFixedVariant;
    if (cfg.mTertiaryFixed)          root.mTertiaryFixed          = cfg.mTertiaryFixed;
    if (cfg.mTertiaryFixedDim)       root.mTertiaryFixedDim       = cfg.mTertiaryFixedDim;
    if (cfg.mOnTertiaryFixed)        root.mOnTertiaryFixed        = cfg.mOnTertiaryFixed;
    if (cfg.mOnTertiaryFixedVariant) root.mOnTertiaryFixedVariant = cfg.mOnTertiaryFixedVariant;
  }
}
