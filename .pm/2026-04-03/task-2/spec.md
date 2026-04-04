# Task 2: 数据模型层

## 目标
将 React 原型中的 TypeScript 类型和数据翻译为 Swift 模型。

## 参考源文件
- ~/app-design-files/src/app/components/schedule-data.ts — 数据结构和示例数据
- ~/app-design-files/src/app/components/current-event.tsx — 事件类型定义（前 56 行）

## 要求

### 1. 文件: ~/future_ego/FutureEgo/Models/ScheduleItem.swift

定义 ScheduleItem:
```swift
struct ScheduleItem: Identifiable {
    let id = UUID()
    let scheduleTime: String
    let title: String
    let status: EventStatus  // enum: done, active, upcoming
    let tag: String?
    let tagColor: Color?
    let detail: CurrentEventData
}
```

### 2. 文件: ~/future_ego/FutureEgo/Models/EventTypes.swift

5 种事件类型，用 enum with associated values:
```swift
enum CurrentEventData {
    case location(LocationEvent)
    case todo(TodoEvent)
    case eatOut(EatOutEvent)
    case cook(CookEvent)
    case delivery(DeliveryEvent)
}
```

每种事件类型为独立 struct，字段完全对应 TypeScript 定义。

### 3. 文件: ~/future_ego/FutureEgo/Models/SampleData.swift

将 schedule-data.ts 中的 SCHEDULE 数组和 CURRENT_INDEX 翻译为 Swift 静态数据。保留全部 7 条示例数据，中文内容完全一致。

## 注意
- 使用 SwiftUI 的 Color 类型
- 所有 struct 遵循 Identifiable
- 不依赖任何第三方库
