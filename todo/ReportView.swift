import SwiftUI
import SwiftData

struct ReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var reportService: ReportService
    
    @Query private var tasks: [Item]
    
    @State private var selectedReportType: ReportType = .weekly
    @State private var showingShareSheet = false
    @State private var reportToShare: String = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                // 报告类型选择器
                Picker("报告类型", selection: $selectedReportType) {
                    ForEach(ReportType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if reportService.isGenerating {
                    // 加载中视图
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在生成\(selectedReportType.rawValue)...")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = reportService.error {
                    // 错误视图
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("生成报告时出错")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            Task {
                                await reportService.generateReport(type: selectedReportType, tasks: tasks)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !reportService.generatedReport.isEmpty {
                    // 报告内容视图
                    VStack(spacing: 0) {
                        Text(selectedReportType.rawValue + " - 生成于 " + Date().formatted(date: .long, time: .shortened))
                            .font(.headline)
                            .padding()
                        
                        // 使用新的WebView渲染组件
                        MarkdownWebView(markdown: reportService.generatedReport)
                            .frame(maxWidth: .infinity)
                            .frame(height: 500) // 设置固定高度
                            .id(reportService.generatedReport) // 强制在内容变化时重建视图
                        
                        // 分享按钮
                        Button {
                            reportToShare = reportService.generatedReport
                            showingShareSheet = true
                        } label: {
                            Label("分享报告", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                        .sheet(isPresented: $showingShareSheet) {
                            ShareSheet(items: [reportToShare])
                        }
                    }
                    .frame(minWidth: 600, maxWidth: .infinity)
                } else {
                    // 初始空视图
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("选择报告类型并点击生成按钮")
                            .font(.headline)
                        Text("系统将分析您的任务数据，生成详细的报告")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("任务报告")
            .toolbar {
                // 关闭按钮
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                // 生成报告按钮
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await reportService.generateReport(type: selectedReportType, tasks: tasks)
                        }
                    } label: {
                        Text("生成")
                    }
                    .disabled(reportService.isGenerating)
                }
            }
            .onChange(of: selectedReportType) { oldValue, newValue in
                // 清空之前的报告
                reportService.generatedReport = ""
                reportService.error = nil
            }
        }
    }
}

// 分享表单 - 针对macOS修改
struct ShareSheet: NSViewRepresentable {
    var items: [Any]
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        // 创建分享服务
        let picker = NSSharingServicePicker(items: items)
        
        // 在view上显示分享菜单
        DispatchQueue.main.async {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
} 