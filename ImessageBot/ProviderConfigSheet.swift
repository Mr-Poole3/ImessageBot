import SwiftUI

struct ProviderConfigSheet: View {
    @ObservedObject var configManager: ConfigManager
    @Binding var isPresented: Bool
    
    // Local state to hold temporary edits
    @State private var tempConfig: AppConfig
    
    init(configManager: ConfigManager, isPresented: Binding<Bool>) {
        self.configManager = configManager
        self._isPresented = isPresented
        self._tempConfig = State(initialValue: configManager.config)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(configManager.config.selectedProvider.description)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("配置连接参数")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
            
            Divider().opacity(0.1)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if configManager.config.selectedProvider == .volcengine {
                        ModernTextField(label: "Ark API Key", text: $tempConfig.volcengineApiKey, isSecure: true, placeholder: "请输入您的火山引擎 API KEY") {
                            HStack(spacing: 4) {
                                if tempConfig.volcengineApiKey.isEmpty {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("必填项")
                                        .foregroundStyle(.orange)
                                }
                                Text("获取地址:")
                                Link("volcengine.com", destination: URL(string: "https://www.volcengine.com/")!)
                                    .underline()
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }
                        
                        ModernTextField(label: "Base URL (可选)", text: $tempConfig.volcengineBaseURL, placeholder: "https://ark.cn-beijing.volces.com/api/v3") {
                            Text("默认为 https://ark.cn-beijing.volces.com/api/v3")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        ModernTextField(label: "Model Name", text: $tempConfig.volcengineModel, placeholder: "例如：doubao-seed-1-6-flash-250828")
                        
                    } else if configManager.config.selectedProvider == .openai {
                        ModernTextField(label: "OpenAI API Key", text: $tempConfig.openaiApiKey, isSecure: true, placeholder: "sk-...")
                        
                        ModernTextField(label: "Base URL (可选)", text: $tempConfig.openaiBaseURL, placeholder: "https://api.openai.com/v1") {
                            Text("默认为 https://api.openai.com/v1，使用中转/代理请修改此项")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        ModernTextField(label: "Model Name", text: $tempConfig.openaiModel, placeholder: "gpt-3.5-turbo")
                        
                    } else if configManager.config.selectedProvider == .ollama {
                        ModernTextField(label: "Base URL", text: $tempConfig.ollamaBaseURL, placeholder: "http://localhost:11434") {
                            Text("请确保 Ollama 服务已启动且允许外部连接（如需远程）")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        ModernTextField(label: "Model Name", text: $tempConfig.ollamaModel, placeholder: "llama3") {
                            Text("请输入您在 Ollama 中已拉取 (pull) 的模型名称")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(24)
            }
            
            Divider().opacity(0.1)
            
            // Footer
            HStack {
                Spacer()
                Button(action: {
                    // Save changes
                    configManager.config = tempConfig
                    _ = configManager.saveConfig()
                    isPresented = false
                }) {
                    Text("确认并保存")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.white.opacity(0.02))
        }
        .frame(width: 450, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // Sync temp config with current config when sheet appears
            tempConfig = configManager.config
        }
    }
}
