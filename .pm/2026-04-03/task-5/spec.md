# Task 5: 此刻 Tab

## 目标
实现"此刻"Tab 的完整视图，展示当前事件详情，支持 5 种事件类型的不同布局。

## 参考源文件（必须先读取）
- /home/jun/app-design-files/src/app/App.tsx — CurrentTabHeader 结构（37-51行）、工具栏（87-129行）
- /home/jun/app-design-files/src/app/components/current-event.tsx — 5 种事件视图的完整实现

## 已有文件（直接 import 使用）
- FutureEgo/Models/ScheduleItem.swift — ScheduleItem, EventStatus
- FutureEgo/Models/EventTypes.swift — CurrentEventData, 各事件 struct
- FutureEgo/Models/SampleData.swift — SampleData.schedule, SampleData.currentIndex
- FutureEgo/Views/Components/CheckItem.swift
- FutureEgo/Views/Components/StepFlow.swift
- FutureEgo/Views/Components/SwipeableCard.swift
- FutureEgo/Views/Components/ProgressRing.swift

## 要创建/修改的文件

### 1. 修改: /home/jun/future_ego/FutureEgo/Views/Tabs/CurrentTabView.swift
替换占位内容（如果已存在则覆盖），实现完整视图:

**Header 区域:**
- 左侧: 日期 "2026/4/1"(34px bold) + "星期三 · 北京 · 晴"(20px bold)
- 右侧: DualProgressRing 组件（传入 eventIndex）

**内容区域（ScrollView）:**
- 根据当前事件的 kind 显示不同视图
- 调用下面的 CurrentEventView

**底部工具栏（浮动在内容上方、TabBar 下方）:**
- 胶囊形毛玻璃容器
- 左按钮: 📷 拍照（camera icon + "拍照"）
- 分隔线
- 右按钮: 📞 AI Coach（phone icon + "AI Coach"，绿色）
- 拍照按钮灰色，AI Coach 按钮绿色(#34C759)

### 2. 创建: /home/jun/future_ego/FutureEgo/Views/Components/CurrentEventView.swift
根据 CurrentEventData 类型分发到不同视图:

**LocationView:**
- "当前正在进行" 灰色小字
- 时间大字(56px, 绿色 #34C759)
- 事件名(22px, bold)
- 地址(15px, 灰色, 前面有绿色 ◎)
- 分隔线
- 卡片标题 + CheckItem 列表

**TodoView:**
- 倒计时逻辑: 如果当前时间在事件时间范围内显示"距离结束还剩" + 倒计时，否则显示"计划进行时间" + 开始时间
- 倒计时用 Timer.publish 每秒更新
- 时间大字(56px, 绿色)
- 事件名 + deadline
- 分隔线
- "任务拆解" + StepFlow 组件

**EatOutView:**
- "约定时间" + 时间大字
- "嘉宾 · 餐厅名 泰餐"
- 地址
- 分隔线
- "用餐愉快 :)" + 推荐菜列表
- 每道菜: emoji + 菜名 + 描述 + "推荐"标签（绿色）
- 菜的 emoji 按顺序: 🍜🍚🥗🍛 循环

**CookView:**
- "开始做饭" + 时间大字
- 菜名用 · 连接
- 烹饪时长(🍳 图标)
- 分隔线
- SwipeableCard: 第一页=食材清单（名称+用量），后续页=每道菜的做法(StepFlow)

**DeliveryView:**
- "吃饭时间" + 时间大字
- 店名
- 配送时间(🛵 图标)
- 分隔线
- "点这几道菜" + 菜单列表（菜名 + 价格绿色）
- 底部: 分隔线 + "预估总价" + 总价(绿色 bold)

## 设计规范
- 大时间数字: .system(size: 56, weight: .medium), 绿色
- 事件名: .system(size: 22, weight: .semibold)
- 灰色文字: Color(hex: "8E8E93")
- 卡片内元素: 圆角 12, 背景 Color.black.opacity(0.025), 边框 Color.black.opacity(0.05)
- 列表项动画: 逐项延迟出现 (stagger 0.06s)

## 完成后
将简短的完成报告写入 /home/jun/future_ego/.pm/2026-04-03/task-5/report.md
