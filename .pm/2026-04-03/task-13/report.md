# Task 13 Report: 浮动工具栏 → 系统 toolbar

## 状态: 完成

## 修改的文件

### /home/jun/future_ego/FutureEgo/Views/Tabs/CurrentTabView.swift

**删除:**
- `floatingToolbar` computed property（约 40 行自定义胶囊浮动工具栏代码）
- `ZStack(alignment: .bottom)` 包裹层
- `.padding(.bottom, 100)` 底部留白（系统 toolbar 自动处理）

**新增:**
- 最外层包裹 `NavigationStack`（`.toolbar` 修饰符需要导航容器才能渲染 bottomBar）
- `.toolbar { ToolbarItemGroup(placement: .bottomBar) { ... } }` 修饰符
  - 拍照按钮：`Label("拍照", systemImage: "camera")`，`.tint(toolbarGray)`
  - `Spacer()` 分隔
  - AI Coach 按钮：`Label("AI Coach", systemImage: "phone")`，`.tint(accentGreen)`，点击触发 `onStartCalling?()`

**保留不变:**
- headerView
- CurrentEventView 内容
- 所有 design tokens、date helpers、progress 计算
- Preview
- onStartCalling 回调机制

## 技术说明
- `NavigationStack` 是必要的，因为 `.toolbar` 中的 `ToolbarItemGroup(placement: .bottomBar)` 需要一个导航容器来渲染底部工具栏。在 TabView 的 tab content 中直接使用 `.toolbar` 不会显示，必须有 NavigationStack。
- 系统 toolbar 自动处理安全区域和内容偏移，无需手动 `.padding(.bottom, 100)`。
