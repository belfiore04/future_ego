# Task 12: CallingOverlay → fullScreenCover

## 目标
将 CallingOverlay 的 ZStack 覆盖方式改为 iOS 原生 .fullScreenCover()。

## 要修改的文件

### 1. 修改: /home/jun/future_ego/FutureEgo/Views/ContentView.swift
- 先读取当前文件（task-11 已修改过）
- 删除 ZStack 中的 CallingOverlay 覆盖
- 添加 .fullScreenCover(isPresented: $isCalling):

```swift
TabView(selection: $activeTab) {
    // tabs...
}
.fullScreenCover(isPresented: $isCalling) {
    CallingOverlay {
        isCalling = false
    }
}
```

- 删除 isCalling 相关的动画包裹（fullScreenCover 自带转场动画）
- 不再需要手动隐藏 TabBar

### 2. 修改: /home/jun/future_ego/FutureEgo/Views/Components/CallingOverlay.swift
- 先读取当前文件
- 删除手动的背景遮罩（Rectangle + ultraThinMaterial）— fullScreenCover 自带
- 删除 overlayVisible 状态和手动的淡入/淡出动画
- 简化 onHangUp 回调（直接调用，不需要 DispatchQueue.main.asyncAfter）
- 背景改为纯色或系统背景

### 3. 修改: /home/jun/future_ego/FutureEgo/Views/Tabs/CurrentTabView.swift
- 先读取当前文件（task-13 已修改过）
- 确认 onStartCalling 回调仍然正常工作
- 如果 toolbar 的按钮触发方式变了，适配一下

## 完成后
写报告到 /home/jun/future_ego/.pm/2026-04-03/task-12/report.md
