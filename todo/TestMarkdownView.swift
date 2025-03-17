import SwiftUI

struct TestMarkdownView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 测试Markdown内容
    let testMarkdown = """
    # 测试报告
    
    这是一个测试报告，用于验证Markdown渲染功能。
    
    ## 任务统计
    
    - 总任务数：5
    - 已完成任务：3
    - 未完成任务：2
    - 完成率：60%
    
    ## 任务列表
    
    | 项目名称 | 状态 | 优先级 | 截止日期 |
    | --- | --- | --- | --- |
    | UI设计 | 已完成 | 重要 | 2023-06-15 |
    | 后端API | 未完成 | 紧急 | 2023-06-20 |
    | 文档编写 | 已完成 | 普通 | 2023-06-18 |
    | 单元测试 | 已完成 | 普通 | 2023-06-19 |
    | 部署上线 | 未完成 | 重要 | 2023-06-25 |
    
    ## 优先级分布
    
    - 普通：2个任务 (40%)
    - 重要：2个任务 (40%)
    - 紧急：1个任务 (20%)
    
    ## 工作效率分析
    
    本周工作效率良好，已完成大部分计划任务。重要任务的完成率为50%。
    
    ## 建议
    
    1. 优先处理未完成的紧急任务
    2. 提前规划下周工作内容
    3. 合理分配时间，确保所有重要任务能够按时完成
    
    > 注意：本报告为测试内容，仅用于验证渲染功能
    """
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("测试Markdown渲染")
                            .font(.headline)
                            .padding(.bottom)
                        
                        Markdown(testMarkdown)
                            .frame(maxWidth: .infinity, minHeight: 400)
                    }
                    .frame(minWidth: 600, maxWidth: .infinity)
                    .padding([.horizontal, .bottom], 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Markdown测试")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TestMarkdownView()
} 