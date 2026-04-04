# Task 11: TabBar → 原生 TabView

## 目标
将自定义 FloatingTabBar 替换为 iOS 原生 TabView，使用最新的 Tab() API。

## 现代 TabView API（iOS 18+，但 iOS 17 也支持 tabItem 方式）

因为目标是 iOS 17+，使用兼容方式：

```swift
TabView(selection: $activeTab) {
    CurrentTabView(...)
        .tabItem {
            Label("此刻", systemImage: "clock")
        }
        .tag(TabId.current)
    
    DailyPlanTabView()
        .tabItem {
            Label("日程", systemImage: "calendar")
        }
        .tag(TabId.daily)
    
    ReviewTabView()
        .tabItem {
            Label("复盘", systemImage: "doc.text")
        }
        .tag(TabId.review)
    
    ProfileTabView()
        .tabItem {
            Label("我的", systemImage: "person")
        }
        .tag(TabId.profile)
}
.tint(Color(hex: "34C759"))  // 绿色主题
```

## 要修改的文件

### 1. 重写: /home/jun/future_ego/FutureEgo/Views/ContentView.swift
- 先读取当前文件内容
- 删除所有对 FloatingTabBar 的引用
- 用原生 TabView 替换 ZStack + switch 结构
- 保留 isCalling 状态和 CallingOverlay（这个由 task-12 处理，现在先保留）
- TabId 枚举保留在 FloatingTabBar.swift 中，需要移到 ContentView 或独立文件

### 2. 修改: /home/jun/future_ego/FutureEgo/Views/Components/FloatingTabBar.swift
- 保留 TabId 枚举定义（其他文件依赖它）
- 删除 FloatingTabBar struct 和 Preview
- 或者把 TabId 移到 ContentView.swift，然后删除整个文件

### 3. 关键注意
- CurrentTabView 接收参数: schedule, currentIndex, onStartCalling
- 先读取当前 ContentView.swift 了解现有结构
- CallingOverlay 目前用 ZStack 覆盖，暂时保留这个方式
- isCalling 时不需要隐藏 TabBar（原生 TabView 在 fullScreenCover 时自动隐藏）

## 完成后
写报告到 /home/jun/future_ego/.pm/2026-04-03/task-11/report.md
