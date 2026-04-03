import SwiftUI

// MARK: - Sample Data

enum SampleData {
    /// The index of the currently active schedule item.
    static let currentIndex = 1

    /// Complete schedule translated from the React prototype.
    static let schedule: [ScheduleItem] = [
        item0, item1, item2, item3, item4, item5, item6
    ]

    // MARK: - Individual items (split to help Swift type checker)

    private static let item0 = ScheduleItem(
        scheduleTime: "08:00 - 09:00",
        title: "早间例行习惯",
        status: .done,
        tag: "任务清单",
        tagColor: Color(hex: "5856D6"),
        detail: .todo(TodoEvent(
            time: "08:00",
            endTime: "09:00",
            name: "早间例行习惯",
            deadline: "每日例行",
            steps: ["冥想 10 分钟", "伸展运动", "准备营养早餐", "回顾今日计划"]
        ))
    )

    private static let item1 = ScheduleItem(
        scheduleTime: "10:00 - 11:30",
        title: "创意品牌营销会议",
        status: .active,
        tag: nil,
        tagColor: nil,
        detail: .location(LocationEvent(
            time: "10:00",
            endTime: "11:30",
            name: "创意品牌营销会议",
            address: "朝阳区798艺术区 A1座",
            cardTitle: "记得要带的东西",
            items: ["笔记本电脑与充电器", "营销方案打印稿（5份）", "降噪耳机"]
        ))
    )

    private static let item2 = ScheduleItem(
        scheduleTime: "12:30 - 13:30",
        title: "午餐 · 外卖",
        status: .upcoming,
        tag: "餐食 · 外卖",
        tagColor: Color(hex: "FF9500"),
        detail: .delivery(DeliveryEvent(
            time: "12:00",
            shop: "旬味寿司·国贸店",
            deliveryTime: "约30分钟送达",
            items: [
                DeliveryItem(name: "三文鱼刺身拼盘", price: "¥38"),
                DeliveryItem(name: "鳗鱼饭", price: "¥32"),
                DeliveryItem(name: "味噌汤", price: "¥12"),
            ],
            totalPrice: "¥82"
        ))
    )

    private static let item3 = ScheduleItem(
        scheduleTime: "14:00 - 15:00",
        title: "午餐 · 外食",
        status: .upcoming,
        tag: "餐食 · 外食",
        tagColor: Color(hex: "FF9500"),
        detail: .eatOut(EatOutEvent(
            time: "14:00",
            guest: "Lisa & 产品组",
            restaurant: "泰香米",
            cuisine: "泰餐",
            address: "三里屯太古里北区 B1层",
            recommendedDishes: [
                RecommendedDish(name: "冬阴功汤", desc: "招牌酸辣鲜虾"),
                RecommendedDish(name: "芒果糯米饭", desc: "甜品必点"),
                RecommendedDish(name: "青木瓜沙拉", desc: "清爽开胃"),
                RecommendedDish(name: "菠萝炒饭", desc: "经典主食"),
            ]
        ))
    )

    private static let item4 = ScheduleItem(
        scheduleTime: "15:00 - 17:00",
        title: "整理周报",
        status: .upcoming,
        tag: "任务清单",
        tagColor: Color(hex: "5856D6"),
        detail: .todo(TodoEvent(
            time: "15:00",
            endTime: "17:00",
            name: "整理周报",
            deadline: "下周一前完成",
            steps: ["整理数据", "收集素材", "撰写报告", "交叉审阅"]
        ))
    )

    private static let item5 = ScheduleItem(
        scheduleTime: "18:30 - 19:30",
        title: "晚餐 · 自己做",
        status: .upcoming,
        tag: "餐食 · 自炊",
        tagColor: Color(hex: "FF9500"),
        detail: .cook(CookEvent(
            time: "18:30",
            dishes: [
                CookDish(name: "香煎三文鱼", steps: ["三文鱼解冻擦干", "两面撒盐和黑胡椒", "热锅少油煎3分钟/面", "挤柠檬汁装盘"]),
                CookDish(name: "蒜蓉西蓝花", steps: ["西蓝花切小朵焯水", "热锅爆香蒜末", "加入西蓝花翻炒", "加盐和少许蚝油出锅"]),
            ],
            cookTime: "约35分钟",
            ingredients: [
                Ingredient(name: "三文鱼", amount: "1块(200g)"),
                Ingredient(name: "西蓝花", amount: "1颗"),
                Ingredient(name: "大蒜", amount: "4瓣"),
                Ingredient(name: "柠檬", amount: "半个"),
                Ingredient(name: "黑胡椒", amount: "适量"),
                Ingredient(name: "蚝油", amount: "1勺"),
            ]
        ))
    )

    private static let item6 = ScheduleItem(
        scheduleTime: "22:00",
        title: "晚间洗漱与阅读",
        status: .upcoming,
        tag: "任务清单",
        tagColor: Color(hex: "5856D6"),
        detail: .todo(TodoEvent(
            time: "22:00",
            endTime: "23:00",
            name: "晚间洗漱与阅读",
            deadline: "睡前完成",
            steps: ["洗漱护肤", "阅读 30 分钟", "记录今日感想"]
        ))
    )
}
