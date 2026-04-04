# Task 3: 共享 UI 组件

## 目标
将 React 原型中的可复用 UI 组件翻译为 SwiftUI 组件。

## 参考源文件
- ~/app-design-files/src/app/components/current-event.tsx — CheckItem (89-131行), StepFlow (199-267行), SwipeableCard (134-196行)
- ~/app-design-files/src/app/components/progress-ring.tsx — 进度环组件

## 要求

### 1. ~/future_ego/FutureEgo/Views/Components/CheckItem.swift
- 圆形 checkbox + 文字
- 选中状态：绿色填充 #34C759 + 白色勾
- 未选中：灰色边框
- 选中后文字变灰 + 删除线
- 点击动画（scale bounce）

### 2. ~/future_ego/FutureEgo/Views/Components/StepFlow.swift
- 纵向步骤列表，左侧圆形序号 + 竖线连接
- 点击圆圈标记完成（变绿色 + 勾）
- 完成后竖线也变绿
- 文字删除线效果

### 3. ~/future_ego/FutureEgo/Views/Components/SwipeableCard.swift
- 多页卡片，支持左右滑动切换
- 顶部小圆点指示器（当前页用绿色长条，其余灰色小圆点）
- 使用 TabView with .page style 或自定义 gesture

### 4. ~/future_ego/FutureEgo/Views/Components/ProgressRing.swift
- 读取 progress-ring.tsx 了解具体设计
- 双环进度指示器
- 外环和内环分别显示不同进度
- 绿色主题色

## 设计规范
- 主色：#34C759
- 次色：#8E8E93（灰色文字）
- 背景辅助：rgba(0,0,0,0.025)
- 圆角：12px 卡片内元素
- 字体：系统字体，跟随 iOS 风格
- 所有动画用 SwiftUI .spring() 或 .easeInOut
