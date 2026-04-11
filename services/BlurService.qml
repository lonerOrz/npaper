pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*
* BlurService — 纯 QML 背景模糊服务
*
* 检测 Quickshell 是否支持 BackgroundEffect (通过尝试创建 Region)。
* Quickshell 内部已处理 protocol 绑定，如果 Region 能创建成功，
* 说明 compositor 也支持 ext-background-effect-v1。
*
* 使用:
*   if (BlurService.available) {
*     region = Qt.createQmlObject("import Quickshell; Region {}", window, "Blur");
*     region.x = ...; region.y = ...; region.width = ...; region.height = ...;
*     window.BackgroundEffect.blurRegion = region;
*   }
*/

Singleton {
  id: root

  property bool _supported: false
  readonly property bool available: _supported

  // ── 检测支持性 ──
  Component.onCompleted: {
    try {
      const test = Qt.createQmlObject(`
                import Quickshell
                Region {}
            `, root, "BlurAvailabilityTest");
      test.destroy();
      _supported = true;
      console.info("BlurService: Blur is AVAILABLE");
    } catch (e) {
      console.info("BlurService: Blur NOT available — disabled");
    }
  }
}
