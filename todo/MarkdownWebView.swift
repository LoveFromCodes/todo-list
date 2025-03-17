import SwiftUI
import WebKit

// 只使用WebView渲染Markdown的视图
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    
    func makeNSView(context: Context) -> WKWebView {
        // 创建WKWebView配置
        let configuration = WKWebViewConfiguration()
        let contentController = configuration.userContentController
        
        // 添加消息处理程序
        contentController.add(context.coordinator, name: "heightHandler")
        contentController.add(context.coordinator, name: "linkHandler")
        
        // 创建WKWebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // 启用开发者工具（便于调试）
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // 构建HTML内容
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                    color: #24292e;
                    background-color: #ffffff;
                    padding: 10px;
                    margin: 0;
                }
                .markdown-body {
                    box-sizing: border-box;
                    width: 100%;
                    padding: 10px;
                    min-height: 400px;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.25;
                }
                h1 { font-size: 2em; }
                h2 { font-size: 1.5em; }
                h3 { font-size: 1.25em; }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 16px 0;
                    display: table;
                }
                th, td {
                    border: 1px solid #dfe2e5;
                    padding: 8px 16px;
                    text-align: left;
                }
                th {
                    background-color: #f6f8fa;
                    font-weight: 600;
                }
                tr:nth-child(even) {
                    background-color: #fafbfc;
                }
                code {
                    font-family: SFMono-Regular, Consolas, 'Liberation Mono', Menlo, monospace;
                    background-color: rgba(27, 31, 35, 0.05);
                    border-radius: 3px;
                    padding: 0.2em 0.4em;
                    font-size: 85%;
                }
                pre {
                    background-color: #f6f8fa;
                    border-radius: 3px;
                    font-size: 85%;
                    line-height: 1.45;
                    overflow: auto;
                    padding: 16px;
                }
                pre > code {
                    background-color: transparent;
                    padding: 0;
                }
                blockquote {
                    border-left: 0.25em solid #dfe2e5;
                    color: #6a737d;
                    padding: 0 1em;
                    margin: 0 0 16px 0;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                ul, ol {
                    padding-left: 2em;
                }
                @media (prefers-color-scheme: dark) {
                    body { 
                        color: #c9d1d9; 
                        background-color: #0d1117; 
                    }
                    th { background-color: #161b22; }
                    th, td { border-color: #30363d; }
                    tr:nth-child(even) { background-color: #161b22; }
                    code { background-color: rgba(240, 246, 252, 0.15); }
                    pre { background-color: #161b22; }
                    blockquote { border-left-color: #30363d; color: #8b949e; }
                }
            </style>
        </head>
        <body>
            <div class="markdown-body" id="content"></div>
            
            <script>
                // 调试信息
                console.log("渲染Markdown内容: ", \(markdown.count) + " 字符");
                
                // 先显示原始内容
                const rawContent = `\(markdown.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`;
                document.getElementById('content').innerText = rawContent;
                
                // 加载Marked库
                const script = document.createElement('script');
                script.src = "https://cdn.jsdelivr.net/npm/marked@4.3.0/marked.min.js";
                script.onload = function() {
                    console.log("Marked库加载成功");
                    renderMarkdown();
                };
                script.onerror = function(e) {
                    console.error("Marked库加载失败:", e);
                };
                document.head.appendChild(script);
                
                // 渲染Markdown
                function renderMarkdown() {
                    if (typeof marked !== 'undefined') {
                        try {
                            // 配置Marked
                            marked.setOptions({
                                gfm: true,
                                breaks: true,
                                headerIds: true,
                                mangle: false,
                                sanitize: false
                            });
                            
                            // 渲染内容
                            const content = document.getElementById('content');
                            content.innerHTML = marked.parse(rawContent);
                            console.log("Markdown渲染完成");
                            
                            // 处理链接点击
                            document.querySelectorAll('a').forEach(link => {
                                link.addEventListener('click', function(e) {
                                    e.preventDefault();
                                    try {
                                        webkit.messageHandlers.linkHandler.postMessage(this.href);
                                    } catch (e) {
                                        console.error('链接处理错误:', e);
                                        window.open(this.href, '_blank');
                                    }
                                });
                            });
                        } catch (e) {
                            console.error("Markdown渲染错误:", e);
                            document.getElementById('content').innerHTML += "<p style='color:red'>渲染错误: " + e.message + "</p>";
                        }
                    }
                }
            </script>
        </body>
        </html>
        """
        
        // 加载HTML内容
        webView.loadHTMLString(htmlContent, baseURL: nil)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.currentMarkdown != markdown {
            context.coordinator.currentMarkdown = markdown
            
            let js = """
            const rawContent = `\(markdown.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`;
            document.getElementById('content').innerText = rawContent;
            if (typeof renderMarkdown === 'function') {
                renderMarkdown();
            } else {
                console.log("渲染函数未定义，等待库加载");
            }
            """
            
            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("更新Markdown内容时出错: \(error)")
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(markdown: markdown)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var currentMarkdown: String
        
        init(markdown: String) {
            self.currentMarkdown = markdown
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView加载完成")
            
            // 检查内容是否已渲染
            webView.evaluateJavaScript("document.getElementById('content').innerHTML.length") { (length, error) in
                if let length = length as? Int {
                    print("内容长度: \(length)")
                }
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler" {
                if let height = message.body as? CGFloat {
                    print("从JS收到的内容高度: \(height)")
                }
            } else if message.name == "linkHandler" {
                if let urlString = message.body as? String, let url = URL(string: urlString) {
                    print("打开链接: \(urlString)")
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
} 