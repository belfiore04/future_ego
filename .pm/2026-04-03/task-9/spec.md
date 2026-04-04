# Task 9: AI Coach 通话浮层

## 目标
实现 AI Coach 通话覆盖层。

## 参考源文件（必须先读取）
- /home/jun/app-design-files/src/app/components/calling-screen.tsx — 完整实现

## 已有文件
- /home/jun/future_ego/FutureEgo/Views/ContentView.swift — 主框架（需要集成通话浮层）

## 要做的事

### 1. 创建: /home/jun/future_ego/FutureEgo/Views/Components/CallingOverlay.swift
读取 calling-screen.tsx 理解设计后翻译为 SwiftUI:
- 全屏覆盖层
- 通话界面（对方名称、通话时长计时、头像等）
- 挂断按钮
- 相关动画

### 2. 修改: /home/jun/future_ego/FutureEgo/Views/ContentView.swift
在 ContentView 中集成通话功能:
- 添加 @State var isCalling = false
- 此刻 Tab 工具栏的 "AI Coach" 按钮触发 isCalling = true
- isCalling 时显示 CallingOverlay 全屏覆盖
- isCalling 时隐藏底部 TabBar（参考 App.tsx 中 {!calling && <TabBar ... />}）

注意: 先读取当前 ContentView.swift 的内容，在其基础上修改，不要破坏已有的 Tab 切换逻辑。添加一个回调机制让 CurrentTabView 能触发通话（通过 @Binding 或环境变量）。

## 设计规范
- 主色: #34C759
- 通话界面全屏，暗色/毛玻璃背景
- 进入/退出动画
- 纯 SwiftUI

## 完成后
写报告到 /home/jun/future_ego/.pm/2026-04-03/task-9/report.md
