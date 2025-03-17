import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    @Published var isAuthorized = false
    @Published var authorizationStatus = "未知"
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                switch settings.authorizationStatus {
                case .authorized:
                    self.authorizationStatus = "已授权"
                case .denied:
                    self.authorizationStatus = "已拒绝"
                case .notDetermined:
                    self.authorizationStatus = "未决定"
                case .provisional:
                    self.authorizationStatus = "临时授权"
                case .ephemeral:
                    self.authorizationStatus = "临时会话"
                @unknown default:
                    self.authorizationStatus = "未知"
                }
                print("通知权限状态: \(self.authorizationStatus)")
            }
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
            if let error = error {
                print("通知授权请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 为任务创建截止时间提醒通知
    func scheduleTaskReminder(for task: Item) {
        guard let dueDate = task.dueDate else { return }
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "任务提醒"
        content.body = task.title
        content.sound = .default
        
        // 设置通知不会自动消失
        content.interruptionLevel = .timeSensitive
        
        // 创建触发器
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: "task-\(task.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("添加通知失败: \(error.localizedDescription)")
            } else {
                print("成功为任务「\(task.title)」创建提醒通知，将在截止时间 \(dueDate) 触发")
            }
        }
    }
    
    // 取消任务提醒通知
    func cancelTaskReminder(for task: Item) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["task-\(task.id.uuidString)"]
        )
        print("已取消任务「\(task.title)」的提醒通知")
    }
    
    // 取消所有通知
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("已取消所有提醒通知")
    }
    
    // 创建测试通知
    func scheduleTestNotification() {
        guard isAuthorized else {
            print("未获得通知权限，无法创建测试通知")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "测试任务提醒"
        content.body = "这是一个测试通知，模拟任务到达截止时间"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("添加测试通知失败: \(error.localizedDescription)")
            } else {
                print("成功创建测试通知，将在10秒后触发")
            }
        }
    }
    
    // 打开系统通知设置
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // 实现代理方法，确保通知在展示时不会自动消失
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 显示通知横幅和播放声音，但不自动消失
        completionHandler([.banner, .sound, .list])
    }
} 