import SwiftUI

struct ContentView: View {
    @StateObject var configManager = ConfigManager()
    @StateObject var engine: MessageEngine
    @ObservedObject var logManager = LogManager.shared
    @State private var selectedTab = 0
    @State private var showStatusAlert = false
    @State private var alertMessage = ""
    
    init() {
        let cm = ConfigManager()
        _configManager = StateObject(wrappedValue: cm)
        _engine = StateObject(wrappedValue: MessageEngine(config: cm.config))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("iMessage Bot")
                        .font(.system(size: 24, weight: .bold))
                    Text(engine.isRunning ? "正在运行中..." : "已停止")
                        .font(.subheadline)
                        .foregroundColor(engine.isRunning ? .green : .secondary)
                }
                Spacer()
                
                Button(action: toggleEngine) {
                    Text(engine.isRunning ? "停止服务" : "启动服务")
                        .frame(width: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.isRunning ? .red : .accentColor)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            TabView(selection: $selectedTab) {
                // Settings Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SectionView(title: "基础配置") {
                            VStack(alignment: .leading) {
                                Text("API Key")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField("输入 Ark API Key", text: $configManager.config.apiKey)
                                    .textFieldStyle(.roundedBorder)
                                
                                Text("唤醒词")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("例如 .", text: $configManager.config.triggerPrefix)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        SectionView(title: "Persona 设置") {
                            VStack(alignment: .leading) {
                                Text("System Prompt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $configManager.config.systemPrompt)
                                    .frame(height: 200)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                            }
                        }
                        
                        SectionView(title: "表情包 API") {
                            VStack(alignment: .leading) {
                                Text("Yaohud API Key")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("输入表情包 API Key", text: $configManager.config.emojiApiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        VStack(alignment: .center) {
                            Text("请确保已在系统中授予“完全磁盘访问权限”")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                }
                .tabItem {
                    Label("配置", systemImage: "gearshape")
                }
                .tag(0)
                
                // Logs Tab
                LogView(logs: logManager.logs)
                    .tabItem {
                        Label("运行日志", systemImage: "doc.text")
                    }
                    .tag(1)
            }
        }
        .frame(minWidth: 550, minHeight: 650)
        .onChange(of: configManager.config.apiKey) { configManager.saveConfig() }
        .onChange(of: configManager.config.triggerPrefix) { configManager.saveConfig() }
        .onChange(of: configManager.config.systemPrompt) { configManager.saveConfig() }
        .onChange(of: configManager.config.emojiApiKey) { configManager.saveConfig() }
        .onAppear {
            LogManager.shared.log("欢迎使用 iMessage Bot！程序已准备就绪。")
            LogManager.shared.log("提示：请确保已在“系统设置 -> 隐私与安全性 -> 完全磁盘访问权限”中勾选本程序。", level: .warning)
        }
        .alert(alertMessage, isPresented: $showStatusAlert) {
            Button("好的", role: .cancel) { }
        }
    }
    
    func toggleEngine() {
        if engine.isRunning {
            engine.stop()
            alertMessage = "机器人服务已停止"
            showStatusAlert = true
        } else {
            engine.config = configManager.config
            engine.start()
            selectedTab = 1 // 启动后自动跳转到日志页
            alertMessage = "机器人服务启动成功！"
            showStatusAlert = true
        }
    }
}

struct LogView: View {
    let logs: [LogManager.LogEntry]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("实时日志")
                    .font(.headline)
                Spacer()
                Button("清空日志") {
                    LogManager.shared.clear()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            
            List {
                ForEach(logs) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text("[\(entry.formattedTime)]")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text(entry.message)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(entryColor(for: entry.level))
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset)
        }
    }
    
    private func entryColor(for level: LogManager.LogLevel) -> Color {
        switch level {
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
