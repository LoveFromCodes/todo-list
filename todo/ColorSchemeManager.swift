import SwiftUI

class ColorSchemeManager: ObservableObject {
    static let shared = ColorSchemeManager()
    
    // 不再需要存储颜色模式或提供切换方法
    // 应用将自动跟随系统颜色模式
    
    private init() {
        // 空实现，保留单例模式
    }
} 