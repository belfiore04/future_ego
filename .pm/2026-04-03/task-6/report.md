# Task 6 完成报告

## 状态: 已完成

## 创建/修改的文件
- `/home/jun/future_ego/FutureEgo/Views/Tabs/DailyPlanTabView.swift` — 覆盖重写

## 实现内容

### Header
- "全天日程" 标题 (28px, bold)
- "共 N 项 · M 项已完成" 动态统计 (14px, 灰色)

### 时间线列表 (ScrollView)
- **TimelineRow**: 圆点(10px) + 竖线(1.5px) + 内容区
  - active: 绿色圆点+发光阴影, 绿色高亮背景卡片 (圆角16, 6%透明度背景 + 15%透明度边框)
  - done: 浅灰色圆点, 灰色文字+删除线, opacity 0.6
  - upcoming: 灰色圆点, 正常显示
- **StatusBadge**: done→灰色"已完成", active→绿色"进行中", upcoming有tag→显示tag胶囊
- **SubInfo**: location→◎+地址, delivery→店名(总价)斜体, eat-out→餐厅·菜系, cook→菜名标签卡片, todo→⏰+deadline

### 点击交互
- upcoming 可点击 → 弹出 .sheet
- done/active 不可点击
- 按下缩放反馈 (scaleEffect 0.97)

### Sheet 详情
- 使用 `.sheet(item:)` modifier + `presentationDetents([.medium, .large])`
- 拖拽手柄 (36x5 灰色胶囊, 隐藏系统 indicator)
- Header: 时间+标题+关闭按钮(X)
- InlineEventDetail: 自包含的事件详情视图, 覆盖全部5种事件类型
  - 不依赖 CurrentEventView (避免与 task-5 的并行冲突)

### 动画
- 每行逐项出现: delay = index * 0.04
- spring(stiffness: 400, damping: 28)

## 数据源
- `SampleData.schedule` — 7个事件
- 类型引用: `ScheduleItem`, `EventStatus`, `CurrentEventData` 及其子类型
- 全部类型引用已验证与 Model 文件一致
