import SwiftUI
import WebKit

// 增强的Markdown渲染视图
struct Markdown: View {
    let text: String
    @State private var attributedText: AttributedString
    @State private var useWebView: Bool
    
    init(_ text: String) {
        self.text = text
        
        // 检测是否需要使用WebView（包含复杂元素如表格、代码块等）
        let needsWebView = text.contains("|") || 
                          text.contains("```") || 
                          text.contains("<table") || 
                          text.contains("- [ ]")
        
        self._useWebView = State(initialValue: needsWebView)
        
        // 尝试使用SwiftUI的AttributedString解析简单Markdown
        do {
            self._attributedText = State(initialValue: try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )))
        } catch {
            print("Markdown解析错误: \(error)")
            self._attributedText = State(initialValue: AttributedString(text))
        }
    }
    
    var body: some View {
        if useWebView {
            // 使用WebView渲染复杂Markdown
            MarkdownWebView(markdown: text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // 使用SwiftUI的AttributedString渲染简单Markdown
            ScrollView {
                Text(attributedText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
            }
        }
    }
}

// 预览示例
struct Markdown_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Markdown渲染测试").font(.headline)
            
            Markdown("""
            # 任务管理报告
            
            ## 本周任务统计
            
            **完成情况：**
            - 已完成任务：5个
            - 未完成任务：3个
            - 完成率：62.5%
            
            **优先级分布：**
            - 普通：4个
            - 重要：3个
            - 紧急：1个
            
            ## 详细任务列表
            
            | 项目名称 | 状态 | 优先级 | 截止日期 |
            | --- | --- | --- | --- |
            | 完成用户界面设计 | 已完成 | 重要 | 2023-06-15 |
            | 实现后端API | 未完成 | 紧急 | 2023-06-20 |
            | 编写文档 | 已完成 | 普通 | 2023-06-18 |
            | 测试功能 | 未完成 | 重要 | 2023-06-22 |
            
            ## 工作效率分析
            
            本周工作效率良好，重要任务的完成率达到了66%。建议下周将注意力集中在未完成的紧急任务上。
            
            ```swift
            // 任务完成率计算
            let completionRate = completedTasks.count / totalTasks.count * 100
            ```
            
            > 注意：下周应优先处理截止日期最早的任务。
            """)
        }
        .frame(width: 600, height: 800)
        .padding()
    }
} 