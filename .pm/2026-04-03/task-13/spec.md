# Task 13: 浮动工具栏 → 系统 toolbar

## 目标
将 CurrentTabView 中自定义的浮动胶囊工具栏替换为 iOS 原生 .toolbar。

## 要修改的文件

### 修改: /home/jun/future_ego/FutureEgo/Views/Tabs/CurrentTabView.swift
- 先读取当前文件
- 删除 floatingToolbar computed property
- 删除 ZStack(alignment: .bottom) 包裹（改为直接 ScrollView）
- 添加 .toolbar 修饰符:

```swift
ScrollView {
    // content...
}
.toolbar {
    ToolbarItemGroup(placement: .bottomBar) {
        Button {
            // camera action
        } label: {
            Label("拍照", systemImage: "camera")
        }
        .tint(Color(hex: "3A3A3C"))
        
        Spacer()
        
        Button {
            onStartCalling?()
        } label: {
            Label("AI Coach", systemImage: "phone")
        }
        .tint(Color(hex: "34C759"))
    }
}
```

- 保留所有其他逻辑（header, event view, date helpers）不变

## 完成后
写报告到 /home/jun/future_ego/.pm/2026-04-03/task-13/report.md
