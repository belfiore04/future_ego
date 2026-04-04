# Task 1: Xcode 项目骨架

## 目标
在 ~/future_ego/ 创建完整的 iOS SwiftUI 项目结构，用户可以用 XcodeGen 生成 .xcodeproj 或直接在 Xcode 中创建项目后拖入文件。

## 要求

### 1. project.yml（XcodeGen 配置）
- 项目名：FutureEgo
- targets: iOS App, deployment target iOS 17.0
- sources: FutureEgo/
- Swift 语言版本 5.9+
- 设备：iPhone only
- 方向：portrait only

### 2. 目录结构
```
FutureEgo/
├── App/
│   └── FutureEgoApp.swift       # @main 入口
├── Models/
│   └── (task-2 负责)
├── Views/
│   ├── Tabs/                    # 各 tab 页面
│   └── Components/              # 共享组件
├── Assets.xcassets/
│   ├── AccentColor.colorset/    # #34C759 绿色
│   ├── AppIcon.appiconset/
│   └── Contents.json
└── Info.plist
```

### 3. FutureEgoApp.swift
- 简单的 @main 入口
- 导入 SwiftUI
- body 返回一个占位 ContentView()
- 注释说明后续 Wave 2 会替换 ContentView

### 4. Assets
- AccentColor: #34C759（应用主色调绿色）
- AppIcon: 空的 appiconset（Contents.json 结构正确即可）

### 5. Info.plist
- 支持 portrait only
- Bundle display name: 交联
- 其他标准配置

## 输出文件
所有文件写入 ~/future_ego/ 目录。
