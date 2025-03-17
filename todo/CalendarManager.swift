import SwiftUI
import SwiftData

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    // 由于不实际使用日历功能，我们设置为默认关闭
    @Published var isCalendarEnabled = false
    
    private init() {
        // 空实现，保留单例模式
    }
    
    // 空方法实现，仅为了满足代码引用
    func addTaskToCalendar(task: Item) {
        // 不实际实现日历功能
        print("日历功能已禁用，不添加任务到日历")
    }
    
    func removeTaskFromCalendar(task: Item) {
        // 不实际实现日历功能
        print("日历功能已禁用，不从日历中移除任务")
    }
} 