# Task 4: TabBar + ContentView 主框架

## 目标
替换占位 ContentView，创建带 4 个 Tab 的主框架和自定义浮动 TabBar。

## 参考源文件
- /home/jun/app-design-files/src/app/App.tsx — 主框架结构、Tab 切换、StatusBar
- /home/jun/app-design-files/src/app/components/tab-bar.tsx — TabBar 设计

## 已有文件（Wave 1 产出，可直接引用）
- /home/jun/future_ego/FutureEgo/Models/ — 数据模型
- /home/jun/future_ego/FutureEgo/Views/Components/ — 共享组件

## 要修改/创建的文件

### 1. 修改: /home/jun/future_ego/FutureEgo/Views/ContentView.swift
替换占位内容，实现:
- TabId 枚举: current("此刻"), daily("日程"), review("复盘"), profile("我的")
- @State activeTab: TabId = .current
- 根据 activeTab 切换显示不同 Tab 内容（先用占位视图，具体 Tab 由 task-5,6 创建）
- Tab 切换动画: .transition + .animation，模拟 React 版的左右滑入效果
- 底部浮动 TabBar（overlay）
- 不需要 iOS StatusBar 模拟（原生会自动显示）

### 2. 创建: /home/jun/future_ego/FutureEgo/Views/Components/FloatingTabBar.swift
自定义浮动 TabBar（不用系统 TabView）:
- 底部居中的胶囊形容器
- 毛玻璃背景: .ultraThinMaterial
- 阴影: shadow(color: .black.opacity(0.08), radius: 20)
- 4 个 Tab 按钮，每个包含图标 + 文字
- 图标用 SF Symbols: clock(此刻), calendar(日程), doc.text(复盘), person(我的)
- 选中态: 绿色(#34C759) + 绿色背景胶囊(.opacity(0.12))
- 未选中: 灰色(#8E8E93)
- 选中指示器用 .matchedGeometryEffect 实现滑动动画
- 文字 10px, 图标 22px

### 3. 创建占位 Tab 视图（如果 task-5,6 的文件还不存在）
- /home/jun/future_ego/FutureEgo/Views/Tabs/CurrentTabView.swift — 占位
- /home/jun/future_ego/FutureEgo/Views/Tabs/DailyPlanTabView.swift — 占位
- /home/jun/future_ego/FutureEgo/Views/Tabs/ReviewTabView.swift — 占位
- /home/jun/future_ego/FutureEgo/Views/Tabs/ProfileTabView.swift — 占位

每个占位视图只需: struct XXXView: View { var body: some View { Text("XXX") } }

## 设计规范
- TabBar 在所有页面底部固定显示
- TabBar 距离底部安全区域 2pt padding
- 整体背景色: Color(.systemGroupedBackground)
- Tab 切换用 withAnimation(.spring(response: 0.35, dampingFraction: 0.85))

## 完成后
将简短的完成报告写入 /home/jun/future_ego/.pm/2026-04-03/task-4/report.md
