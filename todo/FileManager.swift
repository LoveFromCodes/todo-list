import Foundation
import SwiftUI
import SwiftData

class AttachmentManager: ObservableObject {
    @AppStorage("baseAttachmentPath") private var baseAttachmentPath: String?
    @Published var isInitialized = false
    
    static let shared = AttachmentManager()
    
    private init() {
        isInitialized = baseAttachmentPath != nil
    }
    
    func setBasePath(_ path: String) {
        baseAttachmentPath = path
        isInitialized = true
    }
    
    func getBasePath() -> String? {
        return baseAttachmentPath
    }
    
    func createTaskFolder(for item: Item) -> String? {
        guard let basePath = baseAttachmentPath else { return nil }
        
        // 创建日期格式化的文件夹名
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: item.createdAt)
        
        // 清理任务名称中的非法字符
        let cleanTitle = item.title.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "*", with: "-")
            .replacingOccurrences(of: "?", with: "-")
            .replacingOccurrences(of: "\"", with: "-")
            .replacingOccurrences(of: "<", with: "-")
            .replacingOccurrences(of: ">", with: "-")
            .replacingOccurrences(of: "|", with: "-")
        
        let folderName = "\(dateString)-\(cleanTitle)"
        let folderPath = (basePath as NSString).appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
            return folderPath
        } catch {
            print("Error creating folder: \(error)")
            return nil
        }
    }
    
    func openTaskFolder(for item: Item) {
        if let folderPath = item.attachmentPath {
            let url = URL(fileURLWithPath: folderPath)
            NSWorkspace.shared.open(url)
        } else if let newPath = createTaskFolder(for: item) {
            item.attachmentPath = newPath
            let url = URL(fileURLWithPath: newPath)
            NSWorkspace.shared.open(url)
            // 注意：保存操作应在调用此方法的地方处理
            // 因为这个类没有 modelContext 的访问权限
        }
    }
    
    // MARK: - 任务数据JSON导出
    
    /// 将所有任务信息保存为JSON文件
    func saveTasksToJSON(tasks: [Item]) {
        guard let basePath = baseAttachmentPath else { return }
        
        let jsonFilePath = (basePath as NSString).appendingPathComponent("_METAINFO.json")
        
        // 创建任务数据数组
        let taskDataArray = tasks.map { item -> [String: Any] in
            var taskDict: [String: Any] = [
                "id": item.id.uuidString,
                "title": item.title,
                "isCompleted": item.isCompleted,
                "priority": item.priority,
                "createdAt": item.createdAt.timeIntervalSince1970,
                "note": item.note
            ]
            
            if let dueDate = item.dueDate {
                taskDict["dueDate"] = dueDate.timeIntervalSince1970
            }
            
            if let completedAt = item.completedAt {
                taskDict["completedAt"] = completedAt.timeIntervalSince1970
            }
            
            if let attachmentPath = item.attachmentPath {
                taskDict["attachmentPath"] = attachmentPath
            }
            
            return taskDict
        }
        
        // 添加元数据
        let metaData: [String: Any] = [
            "exportDate": Date().timeIntervalSince1970,
            "totalTasks": tasks.count,
            "completedTasks": tasks.filter { $0.isCompleted }.count,
            "pendingTasks": tasks.filter { !$0.isCompleted }.count,
            "tasks": taskDataArray
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metaData, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: jsonFilePath))
            print("任务数据已保存到: \(jsonFilePath)")
        } catch {
            print("保存任务数据失败: \(error)")
        }
    }
    
    /// 从JSON文件加载任务列表
    func loadTasksFromJSON(modelContext: ModelContext) -> [Item] {
        guard let basePath = baseAttachmentPath else { return [] }
        
        let jsonFilePath = (basePath as NSString).appendingPathComponent("_METAINFO.json")
        let fileURL = URL(fileURLWithPath: jsonFilePath)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: jsonFilePath) else {
            print("未找到任务数据文件: \(jsonFilePath)")
            return []
        }
        
        do {
            // 读取JSON数据
            let jsonData = try Data(contentsOf: fileURL)
            guard let metaData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let tasksArray = metaData["tasks"] as? [[String: Any]] else {
                print("JSON数据格式错误")
                return []
            }
            
            print("从JSON加载任务数据: 共 \(tasksArray.count) 个任务")
            
            // 将JSON数据转换为Item对象
            var loadedItems: [Item] = []
            
            for taskDict in tasksArray {
                // 提取必要字段
                guard let idString = taskDict["id"] as? String,
                      let title = taskDict["title"] as? String,
                      let isCompleted = taskDict["isCompleted"] as? Bool,
                      let priority = taskDict["priority"] as? String,
                      let createdAtTimestamp = taskDict["createdAt"] as? TimeInterval else {
                    continue
                }
                
                // 创建新Item
                let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
                
                // 提取可选字段
                let note = taskDict["note"] as? String ?? ""
                
                let completedAt: Date?
                if let completedAtTimestamp = taskDict["completedAt"] as? TimeInterval {
                    completedAt = Date(timeIntervalSince1970: completedAtTimestamp)
                } else {
                    completedAt = nil
                }
                
                let dueDate: Date?
                if let dueDateTimestamp = taskDict["dueDate"] as? TimeInterval {
                    dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
                } else {
                    dueDate = nil
                }
                
                let attachmentPath = taskDict["attachmentPath"] as? String
                
                // 创建新的Item
                let newItem = Item(
                    id: UUID(uuidString: idString) ?? UUID(),
                    title: title,
                    isCompleted: isCompleted,
                    priority: priority,
                    createdAt: createdAt,
                    completedAt: completedAt,
                    dueDate: dueDate,
                    note: note,
                    attachmentPath: attachmentPath
                )
                
                loadedItems.append(newItem)
            }
            
            return loadedItems
            
        } catch {
            print("加载任务数据失败: \(error)")
            return []
        }
    }
} 