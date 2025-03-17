import SwiftUI

struct InitialSetupView: View {
    @StateObject private var attachmentManager = AttachmentManager.shared
    @State private var selectedPath: String = ""
    @State private var showingFolderPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("欢迎使用待办事项")
                .font(.title)
            
            Text("请选择附件存储位置")
                .font(.headline)
            
            HStack {
                TextField("存储路径", text: $selectedPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(true)
                
                Button("选择文件夹") {
                    showingFolderPicker = true
                }
            }
            .frame(width: 400)
            
            Button("确认") {
                if !selectedPath.isEmpty {
                    attachmentManager.setBasePath(selectedPath)
                }
            }
            .disabled(selectedPath.isEmpty)
        }
        .padding()
        .frame(width: 500, height: 200)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedPath = url.path
                }
            case .failure(let error):
                print("Error selecting folder: \(error)")
            }
        }
    }
} 