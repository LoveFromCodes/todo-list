//
//  Item.swift
//  todo
//
//  Created by Hailing on 2025/3/11.
//

import Foundation
import SwiftData

// 简化的优先级枚举
enum Priority: String, Codable, Hashable {
    case normal = "normal"
    case important = "important"
}

// 简化的模型类
@Model
final class Item {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var priority: String
    var createdAt: Date
    var completedAt: Date?
    var dueDate: Date?
    var note: String
    var attachmentPath: String?  // 添加附件路径
    
    // 计算属性，用于处理优先级
    var priorityEnum: Priority {
        get {
            return Priority(rawValue: priority) ?? .normal
        }
        set {
            priority = newValue.rawValue
        }
    }
    
    init(
        title: String, 
        isCompleted: Bool = false, 
        priority: Priority = .normal, 
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        dueDate: Date? = nil,
        note: String = "",
        attachmentPath: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority.rawValue
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.note = note
        self.attachmentPath = attachmentPath
    }
    
    // 从 JSON 加载时使用的初始化方法
    init(
        id: UUID,
        title: String, 
        isCompleted: Bool = false, 
        priority: String,  // 直接接收字符串
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        dueDate: Date? = nil,
        note: String = "",
        attachmentPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.note = note
        self.attachmentPath = attachmentPath
    }
}
