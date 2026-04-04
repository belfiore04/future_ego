# Task 9: AI Coach 通话浮层 — 完成报告

## 状态: 已完成

## 变更摘要

### 1. 新建: `FutureEgo/Views/Components/CallingOverlay.swift`
从 `calling-screen.tsx` 翻译为纯 SwiftUI 实现，包含:
- **ChatMessage 模型**: id / role(user|ai) / text
- **CallingOverlay 视图**: 全屏覆盖层
  - 毛玻璃暗色背景 (`.ultraThinMaterial` + dark colorScheme + 半透明黑色叠加)
  - 通话计时器 (48pt 轻字重，`Timer.publish` 驱动每秒 +1)
  - "AI Coach" 名称 + 绿色脉动指示点 (PulseDotModifier)
  - 聊天消息列表 (ScrollViewReader 自动滚动到底部)
  - 气泡样式: 用户绿色(#34C759)右对齐，AI 半透明白色左对齐，自定义 BubbleShape 不同圆角
  - 文字输入框 (胶囊形毛玻璃背景) + 发送按钮
  - 红色渐变"结束通话"按钮 (#FF3B30 -> #FF6B60)，带阴影
  - Mock 对话数据 (4 轮)，AI 自动 0.8s 延迟回复
  - 进入动画: 0.8s 淡入；退出动画: 0.3s 淡出后回调 onHangUp
- **辅助类型**: BubbleShape, RoundedCornerShape, PulseDotModifier

### 2. 修改: `FutureEgo/Views/ContentView.swift`
- 添加 `@State private var isCalling = false`
- `isCalling` 为 true 时隐藏 FloatingTabBar（带 move+opacity 过渡）
- `isCalling` 为 true 时显示 CallingOverlay（带 opacity 过渡）
- CallingOverlay 的 onHangUp 回调设置 `isCalling = false`
- 给 CurrentTabView 传入 `onStartCalling` 闭包，设置 `isCalling = true`
- 所有已有逻辑（Tab 切换、slide transition、previousTabIndex）保持不变

### 3. 修改: `FutureEgo/Views/Tabs/CurrentTabView.swift`
- 添加 `var onStartCalling: (() -> Void)? = nil` 参数（可选，默认 nil，不破坏 Preview）
- AI Coach 按钮的 action 从 `// TODO` 改为 `onStartCalling?()`

## 交互流程
1. 用户在「此刻」Tab 点击底部工具栏的 "AI Coach" 按钮
2. ContentView 设置 isCalling = true
3. FloatingTabBar 向下滑出隐藏，CallingOverlay 淡入覆盖全屏
4. 1 秒后 AI 自动发送问候消息
5. 用户可输入文字聊天，AI 以 mock 数据自动回复
6. 点击"结束通话"后覆盖层淡出，TabBar 恢复

## 设计规范对照
- 主色 #34C759 -- 已应用于气泡、发送按钮、状态指示点
- 暗色毛玻璃背景 -- `.ultraThinMaterial` + dark scheme
- 进入/退出动画 -- easeOut 0.8s 进入, easeInOut 0.3s 退出
- 纯 SwiftUI -- 无 UIKit 依赖
