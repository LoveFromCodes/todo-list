//
//  todoApp.swift
//  todo
//
//  Created by Hailing on 2025/3/11.
//

import SwiftUI
import SwiftData
import AppKit
import UserNotifications

@main
struct todoApp: App {
    @StateObject private var attachmentManager = AttachmentManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var colorSchemeManager = ColorSchemeManager.shared
    @StateObject private var calendarManager = CalendarManager.shared
    @State private var isWindowVisible = true
    @AppStorage("windowWidth") private var windowWidth: Double = 400
    @AppStorage("windowHeight") private var windowHeight: Double = 600
    @AppStorage("windowPositionX") private var windowPositionX: Double = -1
    @AppStorage("windowPositionY") private var windowPositionY: Double = -1
    
    var sharedModelContainer: ModelContainer = {
        do {
            // 配置持久存储并指定明确的 URL 路径
            let url = URL.documentsDirectory.appending(path: "TodoApp.sqlite")
            let schema = Schema([Item.self])
            let config = ModelConfiguration("TodoApp", schema: schema, url: url)
            
            print("SwiftData 数据库路径: \(url.path)")
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()
    
    init() {
        // 设置应用为通知代理
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // 恢复Dock图标，成为普通应用
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    var body: some Scene {
        WindowGroup {
            if attachmentManager.isInitialized {
                ContentView()
                    .environmentObject(colorSchemeManager)
                    .environmentObject(calendarManager)
                    .environmentObject(notificationManager)
                    .environmentObject(attachmentManager)
                    .background(WindowAccessor(
                        isVisible: $isWindowVisible,
                        windowWidth: $windowWidth,
                        windowHeight: $windowHeight,
                        windowPositionX: $windowPositionX,
                        windowPositionY: $windowPositionY
                    ))
                    .onAppear {
                        // 确保窗口可见性状态与实际情况一致
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let window = NSApplication.shared.windows.first(where: { $0.title.isEmpty == false }) {
                                isWindowVisible = window.isVisible
                            }
                        }
                    }
            } else {
                InitialSetupView()
            }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: windowWidth, height: windowHeight)
        .windowResizability(.contentSize)
        
        #if DEBUG
        Settings {
            VStack {
                Text("快捷键:")
                Text("⌘Q: 退出")
            }
            .padding()
        }
        #endif
    }
}

// 用于访问和控制窗口的辅助视图
struct WindowAccessor: NSViewRepresentable {
    @Binding var isVisible: Bool
    @Binding var windowWidth: Double
    @Binding var windowHeight: Double
    @Binding var windowPositionX: Double
    @Binding var windowPositionY: Double
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // 设置为普通窗口，明确设置level为.normal，可以被其他窗口遮挡
                window.level = .normal
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isMovableByWindowBackground = true // 允许通过拖动窗口任何位置来移动窗口
                
                // 设置窗口样式
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                
                // 恢复窗口位置和大小
                if windowPositionX >= 0 && windowPositionY >= 0 {
                    // 确保位置在可见屏幕范围内
                    if let screen = NSScreen.main {
                        let screenFrame = screen.visibleFrame
                        let newSize = NSSize(width: windowWidth, height: windowHeight)
                        let newOrigin = NSPoint(
                            x: min(max(windowPositionX, screenFrame.minX), screenFrame.maxX - newSize.width),
                            y: min(max(windowPositionY, screenFrame.minY), screenFrame.maxY - newSize.height)
                        )
                        window.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
                    }
                } else {
                    // 初始位置（屏幕右上角）
                    if let screen = window.screen {
                        let screenFrame = screen.visibleFrame
                        let windowFrame = window.frame
                        let newOrigin = NSPoint(
                            x: screenFrame.maxX - windowFrame.width - 20,
                            y: screenFrame.maxY - windowFrame.height - 20
                        )
                        window.setFrameOrigin(newOrigin)
                        // 保存初始位置
                        windowPositionX = newOrigin.x
                        windowPositionY = newOrigin.y
                    }
                }
                
                // 添加窗口大小或位置变化的监听器
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    saveWindowFrame(window)
                }
                
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didMoveNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    saveWindowFrame(window)
                }
                
                // 建立窗口关闭时的监听器
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResignKeyNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    // 当窗口失去焦点时可能被关闭，更新绑定状态
                    DispatchQueue.main.async {
                        self.isVisible = window.isVisible
                    }
                }
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // 当isVisible状态变化时，更新窗口状态
        if let window = nsView.window {
            if isVisible && !window.isVisible {
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
            } else if !isVisible && window.isVisible {
                window.orderOut(nil)
            }
        }
    }
    
    // 保存窗口位置和大小
    private func saveWindowFrame(_ window: NSWindow) {
        let frame = window.frame
        windowWidth = frame.width
        windowHeight = frame.height
        windowPositionX = frame.origin.x
        windowPositionY = frame.origin.y
    }
}

// 创建通知代理类，用于处理应用处于前台时的通知
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // 应用处于前台时也显示通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 前台时显示横幅和播放声音
        completionHandler([.banner, .sound])
    }
    
    // 用户点击通知时的处理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 获取通知的标识符
        let identifier = response.notification.request.identifier
        print("用户点击了通知: \(identifier)")
        
        // 如果标识符以"task-"开头，可以提取任务ID
        if identifier.hasPrefix("task-") {
            let taskId = identifier.replacingOccurrences(of: "task-", with: "")
            print("关联的任务ID: \(taskId)")
            
            // 显示应用窗口
            if let window = NSApplication.shared.windows.first(where: { $0.title.isEmpty == false }) {
                window.orderFrontRegardless()
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
        
        completionHandler()
    }
}
