//
//  ContentView.swift
//  todo
//
//  Created by Hailing on 2025/3/11.
//

import SwiftUI
import SwiftData
import UserNotifications

// 排序选项
enum SortOption: String, CaseIterable {
    case dueDate = "截止时间优先"
    case priority = "重要程度优先"
    case creationDate = "创建时间优先"
}

// 筛选选项
enum FilterOption: String, CaseIterable {
    case incomplete = "未完成"
    case completed = "已完成"
    case all = "全部"
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedSortOption = SortOption.dueDate
    @State private var isAscending = true
    @State private var selectedFilter = FilterOption.incomplete
    @State private var newTaskTitle = ""
    @State private var selectedItem: Item?
    @State private var editingItem: Item?
    @State private var showingAddTaskSheet = false
    @StateObject private var attachmentManager = AttachmentManager.shared
    @State private var showFilterAndSort = false // 控制筛选和排序控件的显示
    @StateObject private var notificationManager = NotificationManager.shared
    @EnvironmentObject private var calendarManager: CalendarManager
    @State private var showingReportView = false
    @StateObject private var reportService = ReportService.shared
    @State private var showingTestMarkdownView = false
    @State private var showingFolderPicker = false // 添加文件夹选择器状态
    
    // 基础查询
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]
    
    // 过滤和排序后的任务列表
    var filteredAndSortedItems: [Item] {
        // 添加诊断日志
        print("获取到的任务总数: \(allItems.count)")
        if allItems.isEmpty {
            print("任务列表为空，可能是数据没有正确加载")
        } else {
            print("任务列表非空，第一个任务: \(allItems[0].title)")
        }
        
        // 首先根据完成状态过滤
        let filteredByStatus = allItems.filter { item in
            switch selectedFilter {
            case .incomplete: return !item.isCompleted
            case .completed: return item.isCompleted
            case .all: return true
            }
        }
        
        // 然后根据搜索文本过滤
        let filteredBySearch = filteredByStatus.filter { item in
            searchText.isEmpty ? true : item.title.localizedStandardContains(searchText)
        }
        
        // 最后排序
        return filteredBySearch.sorted { item1, item2 in
            switch selectedSortOption {
            case .dueDate:
                // 截止时间优先 - 截止时间越早的越靠前
                if item1.dueDate == nil && item2.dueDate == nil {
                    // 都没有截止时间时，按创建时间排序
                    return isAscending ? item1.createdAt < item2.createdAt : item1.createdAt > item2.createdAt
                }
                if item1.dueDate == nil { return isAscending ? false : true } // 升序：nil排后面，降序：nil排前面
                if item2.dueDate == nil { return isAscending ? true : false } // 升序：非nil排前面，降序：非nil排后面
                // 正常比较截止时间
                return isAscending ? item1.dueDate! < item2.dueDate! : item1.dueDate! > item2.dueDate!
                
            case .priority:
                // 重要程度优先
                if item1.priorityEnum == item2.priorityEnum {
                    // 优先级相同时，按截止时间排序
                    if item1.dueDate == nil && item2.dueDate == nil {
                        // 都没有截止时间，按创建时间
                        return isAscending ? item1.createdAt < item2.createdAt : item1.createdAt > item2.createdAt
                    }
                    if item1.dueDate == nil { return isAscending ? false : true }
                    if item2.dueDate == nil { return isAscending ? true : false }
                    return isAscending ? item1.dueDate! < item2.dueDate! : item1.dueDate! > item2.dueDate!
                }
                
                // 重要程度比较：升序=普通在前，降序=重要在前
                if isAscending {
                    return item1.priorityEnum == .normal
                } else {
                    return item1.priorityEnum == .important
                }
                
            case .creationDate:
                // 创建时间优先
                return isAscending ? item1.createdAt < item2.createdAt : item1.createdAt > item2.createdAt
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 任务列表
            List {
                ForEach(filteredAndSortedItems) { item in
                    TaskItemView(item: item, isSelected: item.id == selectedItem?.id, onSelect: { selectedItem = item }, onToggle: {
                        withAnimation {
                            item.isCompleted.toggle()
                            // 记录完成时间
                            if item.isCompleted {
                                item.completedAt = Date()
                                // 删除通知
                                notificationManager.cancelTaskReminder(for: item)
                                // 从日历中移除事件
                                if calendarManager.isCalendarEnabled {
                                    calendarManager.removeTaskFromCalendar(task: item)
                                }
                            } else {
                                item.completedAt = nil
                                // 如果标记为未完成且有截止时间，重新创建通知
                                if let dueDate = item.dueDate {
                                    notificationManager.scheduleTaskReminder(for: item)
                                    // 重新添加到日历
                                    if calendarManager.isCalendarEnabled {
                                        calendarManager.addTaskToCalendar(task: item)
                                    }
                                }
                            }
                            try? modelContext.save()
                            exportTasksToJSON()
                        }
                    }, onEdit: { editingItem = item }, onDelete: { deleteItem(item) }, onAttachmentUpdated: { exportTasksToJSON() }, onPriorityChanged: { exportTasksToJSON() })
                }
            }
            .listStyle(PlainListStyle())
        }
        .sheet(isPresented: $showingAddTaskSheet) {
            AddTaskView(initialTitle: newTaskTitle) { title, priority, dueDate, note in
                addItem(title: title, priority: priority, dueDate: dueDate, note: note)
                newTaskTitle = ""
            }
        }
        .sheet(item: $editingItem) { item in
            EditItemView(item: item) {
                try? modelContext.save()
                editingItem = nil
                // 在编辑完成后更新JSON文件
                exportTasksToJSON()
            }
        }
        .onChange(of: allItems) { _, _ in
            // 当任务列表发生变化时更新JSON文件
            exportTasksToJSON()
        }
        .onAppear {
            // 检查通知权限
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if !notificationManager.isAuthorized {
                    notificationManager.requestAuthorization()
                }
            }
        }
        .sheet(isPresented: $showingReportView) {
            ReportView()
                .environmentObject(reportService)
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // 保存新选择的文件夹路径
                    attachmentManager.setBasePath(url.path)
                    
                    // 从新文件夹加载任务
                    loadTasksFromFolder()
                }
            case .failure(let error):
                print("选择文件夹错误: \(error)")
            }
        }
        .toolbar {
            // 搜索和新建任务输入框
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                    
                    TextField("输入以搜索或回车添加...", text: $newTaskTitle)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .frame(width: 200)
                        .onChange(of: newTaskTitle) { _, newValue in
                            searchText = newValue
                        }
                        .onSubmit {
                            if !newTaskTitle.isEmpty {
                                showingAddTaskSheet = true
                            }
                        }
                        .keyboardShortcut(.return, modifiers: .command)
                    
                    if !newTaskTitle.isEmpty {
                        Button(action: { 
                            newTaskTitle = "" 
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 15))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // 筛选按钮
            ToolbarItem(placement: .primaryAction) {
                Picker("", selection: $selectedFilter) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .controlSize(.small)
                .frame(width: 200)
            }
            
            // 排序控制
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Picker("", selection: $selectedSortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .frame(width: 130)
                    .controlSize(.small)
                    
                    Button(action: { isAscending.toggle() }) {
                        Image(systemName: isAscending ? "arrow.up" : "arrow.down")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 重新选择文件夹按钮
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingFolderPicker = true
                } label: {
                    Text("更改文件夹")
                }
                .help("重新选择附件存储文件夹")
            }
            
            // 报告生成按钮
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingReportView = true
                } label: {
                    Text("生成报告")
                }
                .help("生成报告")
            }
        }
    }
    
    private func addItem(title: String, priority: Priority, dueDate: Date?, note: String) {
        guard !title.isEmpty else { return }
        
        // 创建新任务
        let newItem = Item(
            title: title,
            isCompleted: false,
            priority: priority,
            createdAt: Date(),
            dueDate: dueDate,
            note: note
        )
        
        // 插入并立即保存
        modelContext.insert(newItem)
        
        // 如果有截止时间，创建提醒通知
        if let dueDate = dueDate {
            notificationManager.scheduleTaskReminder(for: newItem)
        }
        
        // 同步保存数据并强制刷新
        do {
            try modelContext.save()
            print("成功添加任务：\(title)")
            
            // 添加任务后更新JSON文件
            exportTasksToJSON()
            
            // 强制刷新 UI
            DispatchQueue.main.async {
                let descriptor = FetchDescriptor<Item>()
                do {
                    let _ = try modelContext.fetch(descriptor)
                } catch {
                    print("刷新任务列表失败：\(error)")
                }
            }
        } catch {
            print("保存任务失败：\(error)")
        }
    }
    
    private func deleteItem(_ item: Item) {
        withAnimation {
            // 删除任务的通知
            notificationManager.cancelTaskReminder(for: item)
            
            modelContext.delete(item)
            
            // 删除任务后更新JSON文件
            exportTasksToJSON()
        }
    }
    
    // 导出任务信息到JSON文件
    func exportTasksToJSON() {
        DispatchQueue.global(qos: .background).async {
            // 重新尝试获取所有任务
            do {
                let descriptor = FetchDescriptor<Item>()
                let items = try modelContext.fetch(descriptor)
                print("导出任务数据：共 \(items.count) 个任务")
                attachmentManager.saveTasksToJSON(tasks: items)
            } catch {
                print("获取任务进行JSON导出时出错: \(error)")
                // 尝试使用已有的 allItems
                attachmentManager.saveTasksToJSON(tasks: allItems)
            }
        }
    }
    
    private func loadTasksFromFolder() {
        // 从新文件夹加载任务数据
        let loadedItems = attachmentManager.loadTasksFromJSON(modelContext: modelContext)
        
        if loadedItems.isEmpty {
            print("新文件夹中未找到任务数据或为空，保持当前任务列表")
            // 将当前任务导出到新文件夹
            exportTasksToJSON()
            return
        }
        
        // 清空当前的任务列表
        let descriptor = FetchDescriptor<Item>()
        do {
            let existingItems = try modelContext.fetch(descriptor)
            for item in existingItems {
                modelContext.delete(item)
            }
            
            // 添加从JSON加载的任务
            for item in loadedItems {
                modelContext.insert(item)
            }
            
            // 保存更改
            try modelContext.save()
            print("成功从文件夹加载 \(loadedItems.count) 个任务")
        } catch {
            print("替换任务列表失败: \(error)")
        }
    }
}

// 新增任务视图
struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var priority: Priority = .normal
    @State private var dueDate: Date?
    @State private var hasDueDate = false
    @State private var note: String = ""
    
    let onAdd: (String, Priority, Date?, String) -> Void
    
    init(initialTitle: String, onAdd: @escaping (String, Priority, Date?, String) -> Void) {
        self._title = State(initialValue: initialTitle)
        self.onAdd = onAdd
        
        // 设置默认截止时间为今天下午5点
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 17
        components.minute = 0
        components.second = 0
        if let defaultDate = calendar.date(from: components) {
            self._dueDate = State(initialValue: defaultDate)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) { // 减小间距
            Text("添加新任务")
                .font(.headline)
                .padding(.top, 4) // 减小顶部间距
            
            TextField("任务标题", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 4)
            
            // 备注输入框
            TextField("备注（可选）", text: $note)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 4)
            
            Picker("优先级", selection: $priority) {
                Text("普通").tag(Priority.normal)
                Text("重要").tag(Priority.important)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 4)
            
            Toggle("设置截止时间", isOn: $hasDueDate)
                .padding(.horizontal, 4)
            
            if hasDueDate {
                DatePicker("截止时间", selection: Binding(
                    get: { dueDate ?? Date() },
                    set: { dueDate = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical) // 使用图形样式（月视图）
                .padding(.horizontal, 4)
            }
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                
                Button("添加") {
                    onAdd(title, priority, hasDueDate ? dueDate : nil, note)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(title.isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8) // 减小整体上下间距
        .frame(width: 350)
    }
}

struct TaskItemView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var colorSchemeManager: ColorSchemeManager
    @EnvironmentObject private var attachmentManager: AttachmentManager
    @EnvironmentObject private var calendarManager: CalendarManager
    
    let item: Item
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAttachmentUpdated: () -> Void
    let onPriorityChanged: () -> Void
    
    var isChecked: Bool {
        item.isCompleted
    }
    @State private var showDatePickerPopover = false
    @State private var dateBeingEdited: Date? = nil
    @State private var showingNotificationAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：标题和右上角的时间、旗帜
            HStack(alignment: .top) {
                // 复选框和标题
                HStack(spacing: 8) {
                    Button(action: {
                        // 如果任务有截止时间且尚未过期，显示确认对话框
                        if !item.isCompleted && item.dueDate != nil && item.dueDate!.timeIntervalSinceNow > 0 {
                            showingNotificationAlert = true
                        } else {
                            onToggle()
                        }
                    }) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isCompleted ? .green : .gray)
                    }
                    .buttonStyle(.plain)
                    .alert("确认删除提醒", isPresented: $showingNotificationAlert) {
                        Button("保留提醒", role: .cancel) {
                            // 只标记任务完成，不删除通知
                            item.isCompleted = true
                        }
                        Button("删除提醒", role: .destructive) {
                            // 标记任务完成并删除通知
                            item.isCompleted = true
                            // 取消提醒通知
                            notificationManager.cancelTaskReminder(for: item)
                            // 从日历中移除事件
                            if calendarManager.isCalendarEnabled {
                                calendarManager.removeTaskFromCalendar(task: item)
                            }
                        }
                    } message: {
                        Text("该任务的截止时间还未到，是否同时删除提醒通知？")
                    }
                    
                    Text(item.title)
                        .strikethrough(item.isCompleted)
                        .foregroundColor(item.isCompleted ? .gray : .primary)
                }
                
                Spacer()
                
                // 右上角的时间、文件夹和旗帜
                HStack(spacing: 8) {
                    // 完成时间标记
                    if item.isCompleted, let completedAt = item.completedAt {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text(formatCompletionDate(completedAt))
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                    
                    // 截止时间标记 或 添加截止时间按钮
                    if let dueDate = item.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(formatDueDate(dueDate))
                                .font(.caption)
                        }
                        .foregroundColor(isDueDateNear(dueDate) ? .orange : .gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange.opacity(0.1))
                        )
                        .contentShape(Rectangle()) // 确保整个区域可点击
                        .onTapGesture {
                            dateBeingEdited = dueDate
                            showDatePickerPopover = true
                        }
                        .popover(isPresented: $showDatePickerPopover) {
                            DateEditView(date: $dateBeingEdited) {
                                if let newDate = dateBeingEdited {
                                    item.dueDate = newDate
                                    try? modelContext.save()
                                    
                                    // 更新提醒
                                    notificationManager.scheduleTaskReminder(for: item)
                                }
                                showDatePickerPopover = false
                            } onDelete: {
                                item.dueDate = nil
                                try? modelContext.save()
                                
                                // 取消提醒
                                notificationManager.cancelTaskReminder(for: item)
                                showDatePickerPopover = false
                            }
                        }
                    } else if !item.isCompleted {
                        // 添加截止时间按钮（仅在未完成任务中显示）
                        Button {
                            let defaultTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
                            dateBeingEdited = defaultTime
                            showDatePickerPopover = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.caption)
                                Text("添加时间")
                                    .font(.caption)
                            }
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showDatePickerPopover) {
                            DateEditView(date: $dateBeingEdited) {
                                if let newDate = dateBeingEdited {
                                    item.dueDate = newDate
                                    try? modelContext.save()
                                    
                                    // 添加提醒
                                    notificationManager.scheduleTaskReminder(for: item)
                                }
                                showDatePickerPopover = false
                            } onDelete: {
                                // 取消操作
                                showDatePickerPopover = false
                            }
                        }
                    }
                    
                    // 文件夹图标
                    Button(action: {
                        attachmentManager.openTaskFolder(for: item)
                        try? modelContext.save() // 保存可能更新的附件路径
                        onAttachmentUpdated()
                    }) {
                        Image(systemName: item.attachmentPath == nil ? "folder" : "folder.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("打开任务附件文件夹")
                    
                    // 优先级标志
                    Button(action: {
                        withAnimation {
                            item.priorityEnum = item.priorityEnum == .important ? .normal : .important
                            try? modelContext.save()
                            onPriorityChanged()
                        }
                    }) {
                        Image(systemName: item.priorityEnum == .important ? "flag.fill" : "flag")
                            .foregroundColor(item.priorityEnum == .important ? .red : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(item.priorityEnum == .important ? "设为普通任务" : "设为重要任务")
                }
            }
            
            // 第二行：备注信息
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 28) // 与标题对齐
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isChecked ? Color.blue.opacity(0.2) : Color.clear)
        )
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button(item.priorityEnum == .important ? "设为普通任务" : "设为重要任务") {
                withAnimation {
                    item.priorityEnum = item.priorityEnum == .important ? .normal : .important
                    try? modelContext.save()
                }
            }
            Button("打开附件文件夹") {
                attachmentManager.openTaskFolder(for: item)
                try? modelContext.save() // 保存可能更新的附件路径
            }
            Button("编辑", action: onEdit)
            Button("删除", role: .destructive, action: onDelete)
        }
    }
    
    // 格式化完成时间
    private func formatCompletionDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        // 如果是今天
        if calendar.isDateInToday(date) {
            return "今天完成"
        }
        
        // 如果是昨天
        if calendar.isDateInYesterday(date) {
            return "昨天完成"
        }
        
        // 如果是本周其他日子
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return weekdayFormatter.string(from: date) + "完成"
        }
        
        // 其他日期
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date) + "完成"
    }
    
    // 格式化截止时间
    private func formatDueDate(_ date: Date) -> String {
        // 如果任务已完成，只显示日期
        if item.isCompleted {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // 如果是今天
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: date)
        }
        
        // 如果是明天
        if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "明天 " + formatter.string(from: date)
        }
        
        // 如果是本周其他日子
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return weekdayFormatter.string(from: date) + " " + formatter.string(from: date)
        }
        
        // 其他日期
        let formatter = DateFormatter()
        formatter.dateFormat = item.isCompleted ? "MM-dd" : "MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    // 检查截止时间是否临近（24小时内）
    private func isDueDateNear(_ date: Date) -> Bool {
        let timeInterval = date.timeIntervalSinceNow
        return timeInterval > 0 && timeInterval < 24 * 3600 // 24小时
    }
    
    // 将exportTasksToJSON方法添加到TaskItemView中
    private func exportTasksToJSON() {
        DispatchQueue.global(qos: .background).async {
            do {
                let items = try modelContext.fetch(FetchDescriptor<Item>())
                attachmentManager.saveTasksToJSON(tasks: items)
            } catch {
                print("获取任务列表失败: \(error.localizedDescription)")
            }
        }
    }
}

// 新增日期编辑视图
struct DateEditView: View {
    @Binding var date: Date?
    let onSave: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("修改截止时间")
                .font(.headline)
                .padding(.top, 8)
            
            DatePicker("", selection: Binding(
                get: { date ?? Date() },
                set: { date = $0 }
            ), displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            
            HStack {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("移除", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("保存") {
                    onSave()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(width: 300)
    }
}

struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    let item: Item
    let onDone: () -> Void
    @State private var editedTitle: String
    @State private var priority: Priority
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    @State private var note: String
    @StateObject private var notificationManager = NotificationManager.shared
    
    init(item: Item, onDone: @escaping () -> Void) {
        self.item = item
        self.onDone = onDone
        self._editedTitle = State(initialValue: item.title)
        self._priority = State(initialValue: item.priorityEnum)
        self._dueDate = State(initialValue: item.dueDate)
        self._hasDueDate = State(initialValue: item.dueDate != nil)
        self._note = State(initialValue: item.note)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("编辑任务")
                .font(.headline)
            
            TextField("任务标题", text: $editedTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // 备注输入框
            TextField("备注（可选）", text: $note)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Picker("优先级", selection: $priority) {
                Text("普通").tag(Priority.normal)
                Text("重要").tag(Priority.important)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Toggle("设置截止时间", isOn: $hasDueDate)
            
            if hasDueDate {
                DatePicker("截止时间", selection: Binding(
                    get: { dueDate ?? Date() },
                    set: { dueDate = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
            }
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                
                Button("保存") {
                    // 检查截止时间是否已更改
                    let dueDateChanged = (hasDueDate ? dueDate : nil) != item.dueDate
                    
                    // 更新任务
                    item.title = editedTitle
                    item.priorityEnum = priority
                    item.dueDate = hasDueDate ? dueDate : nil
                    item.note = note
                    
                    // 如果截止时间已更改，更新通知
                    if dueDateChanged {
                        if let newDueDate = item.dueDate {
                            // 有新截止时间，创建新通知
                            notificationManager.scheduleTaskReminder(for: item)
                        } else {
                            // 没有截止时间，取消通知
                            notificationManager.cancelTaskReminder(for: item)
                        }
                    }
                    
                    dismiss()
                    onDone()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(editedTitle.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

