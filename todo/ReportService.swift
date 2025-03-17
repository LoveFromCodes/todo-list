import Foundation
import SwiftData

// 报告类型枚举
enum ReportType: String, CaseIterable, Identifiable {
    case weekly = "周报"
    case monthly = "月报"
    case yearly = "年报"
    
    var id: String { self.rawValue }
}

// 报告服务类
class ReportService: ObservableObject {
    static let shared = ReportService()
    
    private let apiKey = "sk-1b3315dec6d746e98772f652f8ea9247" // 实际应用中应使用安全的方式存储
    private let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    
    @Published var isGenerating = false
    @Published var generatedReport: String = ""
    @Published var error: String? = nil
    
    // 生成报告
    func generateReport(type: ReportType, tasks: [Item]) async {
        // 在主线程更新UI状态
        await MainActor.run {
            self.isGenerating = true
            self.error = nil
            self.generatedReport = ""
        }
        
        do {
            // 准备任务数据
            let tasksData = prepareTasksData(tasks: tasks, type: type)
            
            // 构建API请求
            let prompt = """
            作为一个任务管理助手，请根据以下任务数据生成一份\(type.rawValue)：
            
            \(tasksData)
            
            请在报告中包含以下内容：
            1. 完成的任务数量和未完成的任务数量
            2. 任务完成率
            3. 按优先级分类的任务统计
            4. 对工作效率的分析
            5. 建议和改进措施
            
            具体要求：
            - 以表格形式展示所有任务，表格必须包含项目名称（即任务标题）、状态、优先级、截止日期等字段
            - 提供任务分类统计，可以按照项目名称/优先级进行分组统计
            - 添加图表描述（如完成率饼图、优先级分布等）
            
            请以markdown格式输出，使用中文。
            """
            
            // 调用API
            let report = try await callLLMAPI(prompt: prompt)
            
            // 更新UI
            await MainActor.run {
                self.generatedReport = report
                self.isGenerating = false
            }
        } catch {
            await MainActor.run {
                self.error = "生成报告失败: \(error.localizedDescription)"
                self.isGenerating = false
            }
        }
    }
    
    // 准备任务数据
    private func prepareTasksData(tasks: [Item], type: ReportType) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // 根据报告类型筛选时间范围内的任务
        let filteredTasks: [Item]
        switch type {
        case .weekly:
            // 获取本周开始和结束时间
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            
            // 过滤在本周范围内的任务
            filteredTasks = tasks.filter { task in
                // 初始设为不在范围内
                var inRange = false
                
                // 检查创建时间 (createdAt 是非可选类型)
                let createdDate = task.createdAt
                if calendar.isDate(createdDate, inSameDayAs: startOfWeek) {
                    inRange = true
                } else if createdDate >= startOfWeek && createdDate < endOfWeek {
                    inRange = true
                }
                
                // 检查完成时间
                if !inRange, let date = task.completedAt {
                    if calendar.isDate(date, inSameDayAs: startOfWeek) {
                        inRange = true
                    } else if date >= startOfWeek && date < endOfWeek {
                        inRange = true
                    }
                }
                
                // 检查截止时间
                if !inRange, let date = task.dueDate {
                    if calendar.isDate(date, inSameDayAs: startOfWeek) {
                        inRange = true
                    } else if date >= startOfWeek && date < endOfWeek {
                        inRange = true
                    }
                }
                
                return inRange
            }
            
        case .monthly:
            // 获取本月开始和结束时间
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            
            // 过滤在本月范围内的任务
            filteredTasks = tasks.filter { task in
                // 初始设为不在范围内
                var inRange = false
                
                // 检查创建时间 (createdAt 是非可选类型)
                let createdDate = task.createdAt
                if calendar.isDate(createdDate, inSameDayAs: startOfMonth) {
                    inRange = true
                } else if createdDate >= startOfMonth && createdDate < nextMonth {
                    inRange = true
                }
                
                // 检查完成时间
                if !inRange, let date = task.completedAt {
                    if calendar.isDate(date, inSameDayAs: startOfMonth) {
                        inRange = true
                    } else if date >= startOfMonth && date < nextMonth {
                        inRange = true
                    }
                }
                
                // 检查截止时间
                if !inRange, let date = task.dueDate {
                    if calendar.isDate(date, inSameDayAs: startOfMonth) {
                        inRange = true
                    } else if date >= startOfMonth && date < nextMonth {
                        inRange = true
                    }
                }
                
                return inRange
            }
            
        case .yearly:
            // 获取本年开始和结束时间
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let nextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear)!
            
            // 过滤在本年范围内的任务
            filteredTasks = tasks.filter { task in
                // 初始设为不在范围内
                var inRange = false
                
                // 检查创建时间 (createdAt 是非可选类型)
                let createdDate = task.createdAt
                if calendar.isDate(createdDate, inSameDayAs: startOfYear) {
                    inRange = true
                } else if createdDate >= startOfYear && createdDate < nextYear {
                    inRange = true
                }
                
                // 检查完成时间
                if !inRange, let date = task.completedAt {
                    if calendar.isDate(date, inSameDayAs: startOfYear) {
                        inRange = true
                    } else if date >= startOfYear && date < nextYear {
                        inRange = true
                    }
                }
                
                // 检查截止时间
                if !inRange, let date = task.dueDate {
                    if calendar.isDate(date, inSameDayAs: startOfYear) {
                        inRange = true
                    } else if date >= startOfYear && date < nextYear {
                        inRange = true
                    }
                }
                
                return inRange
            }
        }
        
        // 格式化任务数据
        var result = ""
        for task in filteredTasks {
            let status = task.isCompleted ? "已完成" : "未完成"
            
            // 获取优先级
            let priorityText: String
            if task.priority == "normal" {
                priorityText = "普通"
            } else if task.priority == "important" {
                priorityText = "重要"
            } else {
                priorityText = "紧急"
            }
            
            // 格式化日期
            let dateString: String
            if let dueDate = task.dueDate {
                dateString = dueDate.formatted(date: .abbreviated, time: .shortened)
            } else {
                dateString = "无截止日期"
            }
            
            // 添加任务信息 - 更加结构化，便于生成表格
            result += "- 项目名称：\(task.title)\n"
            result += "  状态：\(status)\n"
            result += "  优先级：\(priorityText)\n"
            result += "  截止日期：\(dateString)\n"
            
            // 添加备注（如果有）
            if !task.note.isEmpty {
                result += "  备注：\(task.note)\n"
            }
            
            result += "\n" // 任务之间添加空行，增加可读性
        }
        
        return result.isEmpty ? "该时间段内没有任务数据" : result
    }
    
    // 调用大语言模型API
    private func callLLMAPI(prompt: String) async throws -> String {
        // 构建请求URL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw NSError(domain: "ReportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])
        }
        
        // 准备请求参数
        let messages: [[String: String]] = [
            ["role": "system", "content": """
            你是一个专业的数据分析助手，擅长生成美观、结构化的报告。
            
            请遵循以下指南：
            1. 使用正确的Markdown语法格式化内容
            2. 表格一定要使用标准Markdown格式
            3. 确保所有的HTML标签和特殊字符都被适当转义
            4. 优先使用标准Markdown语法而不是HTML标签
            5. 生成的内容应当是完整的、可读的报告
            """
            ],
            ["role": "user", "content": prompt]
        ]
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": "qwen-max", // 使用更强大的模型
            "messages": messages,
            "temperature": 0.7,  // 适中的创造性
            "top_p": 0.95,       // 保持合理的多样性
            "max_tokens": 2000   // 允许生成更长的报告
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 处理响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ReportService", code: 2, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])
        }
        
        if httpResponse.statusCode != 200 {
            // 尝试解析错误信息
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw NSError(domain: "ReportService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            } else {
                throw NSError(domain: "ReportService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API请求失败: \(httpResponse.statusCode)"])
            }
        }
        
        // 解析返回数据
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            } else {
                throw NSError(domain: "ReportService", code: 4, userInfo: [NSLocalizedDescriptionKey: "无法解析API响应"])
            }
        } catch {
            throw NSError(domain: "ReportService", code: 5, userInfo: [NSLocalizedDescriptionKey: "解析响应失败: \(error.localizedDescription)"])
        }
    }
} 
