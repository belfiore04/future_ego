# Task 6: 日程 Tab

## 目标
实现"日程"Tab，展示全天时间线，支持点击展开 Sheet 查看事件详情。

## 参考源文件（必须先读取）
- /home/jun/app-design-files/src/app/components/daily-plan-tab.tsx — 完整实现

## 已有文件（直接 import 使用）
- FutureEgo/Models/SampleData.swift — SampleData.schedule
- FutureEgo/Models/ScheduleItem.swift — ScheduleItem, EventStatus
- FutureEgo/Models/EventTypes.swift — CurrentEventData
- FutureEgo/Views/Components/CurrentEventView.swift（由 task-5 创建，如果还不存在就先创建一个简单版本）

## 要创建/修改的文件

### 修改: /home/jun/future_ego/FutureEgo/Views/Tabs/DailyPlanTabView.swift

**Header:**
- "全天日程"(28px, bold)
- "共 7 项 · N 项已完成"(14px, 灰色) — N 动态计算

**时间线列表 (ScrollView):**
每行 TimelineRow:
- 左侧竖向: 圆点(10px) + 竖线(1.5px)
  - active 事件: 绿色圆点 + 绿色发光阴影
  - done 事件: 浅灰色圆点
  - upcoming: 灰色圆点
- 右侧内容:
  - 时间(13px) + 标题(17px, semibold)
  - done: 灰色 + 删除线
  - active: 正常黑色 + 绿色高亮背景卡片(圆角16, 绿色6%透明度背景 + 绿色15%透明度边框)
  - upcoming: 正常显示
- 右上角 StatusBadge:
  - done → 灰色"已完成"胶囊
  - active → 绿色"进行中"胶囊
  - upcoming 有 tag → 显示 tag（使用 tagColor）
- SubInfo（非 done 状态显示）:
  - location → ◎ + 地址
  - delivery → 店名（总价）斜体
  - eat-out → 餐厅 · 菜系
  - cook → 菜名小标签卡片
  - todo → ⏰ + deadline

**点击交互:**
- upcoming 事件可点击 → 弹出 Sheet
- done/active 不可点击
- 整行 done 状态 opacity 0.6

**Sheet (iOS 风格底部弹出):**
- 使用 .sheet() 或自定义实现
- 顶部拖拽手柄(36x5 灰色胶囊)
- Header: 时间 + 标题 + 关闭按钮(X)
- 内容: 复用 CurrentEventView 展示该事件详情
- 支持下拉关闭

**动画:**
- 每行逐项出现: delay = index * 0.04
- spring(stiffness: 400, damping: 28)
- Sheet 弹出用 spring 动画

## 完成后
将简短的完成报告写入 /home/jun/future_ego/.pm/2026-04-03/task-6/report.md
