import SwiftUI

struct ContentView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var engine: MessageEngine
    @ObservedObject var logManager = LogManager.shared
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Text("iMessage Bot")
                        .font(.system(size: 16, weight: .bold))
                }
                .padding(.top, 40)
                
                VStack(spacing: 4) {
                    SidebarButton(title: "设置", icon: "gearshape.fill", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    SidebarButton(title: "日志", icon: "doc.text.fill", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                VStack(spacing: 12) {
                    StatusBadge(isRunning: engine.isRunning)
                    
                    Button(action: toggleEngine) {
                        Text(engine.isRunning ? "停止服务" : "启动服务")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(engine.isRunning ? Color.red : Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color.black.opacity(0.05))
                .cornerRadius(12)
                .padding(12)
            }
            .frame(width: 200)
            .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
            
            Divider()
            
            // Main Content
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                if selectedTab == 0 {
                    SettingsTabView(configManager: configManager)
                } else {
                    LogView(logs: logManager.logs)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .tint(.blue)
        .onAppear {
            LogManager.shared.log("欢迎使用 iMessage Bot！程序已准备就绪。")
            LogManager.shared.log("提示：请确保已在“系统设置 -> 隐私与安全性 -> 完全磁盘访问权限”中勾选本程序。", level: .warning)
        }
        .alert(engine.alertMessage, isPresented: $engine.showAlert) {
            Button("好的", role: .cancel) { }
        }
    }
    
    func toggleEngine() {
        engine.toggle(with: configManager.config)
        if engine.isRunning {
            selectedTab = 1
        }
    }
}

// MARK: - Components

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle()) // 关键：将整个区域设为可点击
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let isRunning: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isRunning ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(isRunning ? "正在运行" : "服务已停止")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isRunning ? .green : .secondary)
        }
    }
}

struct SettingsTabView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var editingPersona: PersonaCard?
    
    // 用于管理输入框聚焦状态，防止页面进入时自动全选第一个输入框
    @FocusState private var focusedField: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 这是一个隐藏的聚焦元素，用来“拦截” macOS 自动聚焦第一个输入框的行为
                TextField("", text: .constant(""))
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .focused($focusedField, equals: "dummy")

                HStack {
                    Text("设置")
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if showSuccess {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("保存成功")
                                    .font(.system(size: 13))
                                    .foregroundColor(.green)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        
                        if showError {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("保存失败")
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        
                        Button(action: saveSettings) {
                            HStack(spacing: 6) {
                                if isSaving {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(isSaving ? "正在保存..." : "保存设置")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                }
                .padding(.bottom, 8)
                
                Group {
                    ModernSection(title: "基础服务配置", icon: "key.fill") {
                        VStack(alignment: .leading, spacing: 16) {
                            ModernTextField(label: "Ark API Key", text: $configManager.config.apiKey, isSecure: true, placeholder: "输入您的 API 密钥")
                            ModernTextField(label: "消息唤醒词", text: $configManager.config.triggerPrefix, placeholder: "例如 . 或 @bot")
                        }
                    }
                    
                    ModernSection(title: "角色人格库", icon: "person.text.rectangle.fill") {
                        VStack(alignment: .leading, spacing: 16) {
                            // 顶部控制栏
                            HStack {
                                Text("管理人格设定卡片，点击选择当前生效的角色")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: addPersona) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("添加新角色")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // 卡片网格/列表
                            VStack(spacing: 12) {
                                ForEach(configManager.config.personaCards) { card in
                                    PersonaCardView(
                                        card: card,
                                        isSelected: configManager.config.selectedPersonaId == card.id,
                                        onSelect: {
                                            configManager.config.selectedPersonaId = card.id
                                        },
                                        onEdit: {
                                            editingPersona = card
                                        },
                                        onDelete: {
                                            deletePersona(card)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .sheet(item: $editingPersona) { persona in
                        PromptDetailView(persona: persona) { updatedPersona in
                            if let index = configManager.config.personaCards.firstIndex(where: { $0.id == updatedPersona.id }) {
                                configManager.config.personaCards[index] = updatedPersona
                            }
                        }
                    }
                    
                    ModernSection(title: "扩展功能", icon: "face.smiling.fill") {
                        ModernTextField(label: "表情包 API Key (Yaohud)", text: $configManager.config.emojiApiKey, placeholder: "输入表情包 API 密钥")
                    }
                }
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.secondary)
                    Text("提示：保存后配置将立即生效，无需重启服务。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
        .onAppear {
            // 页面加载时，将焦点给到隐藏的 dummy 元素，从而避免第一个真实输入框被自动全选
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = "dummy"
            }
        }
    }
    
    func saveSettings() {
        isSaving = true
        let success = configManager.saveConfig()
        
        // 模拟保存动画并显示反馈提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            withAnimation {
                if success {
                    showSuccess = true
                    showError = false
                } else {
                    showSuccess = false
                    showError = true
                }
            }
            
            // 3秒后隐藏提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    showSuccess = false
                    showError = false
                }
            }
        }
    }
    
    func addPersona() {
        let newCard = PersonaCard(
            cardName: "新角色 \(configManager.config.personaCards.count + 1)",
            personaName: "iMessageBot",
            description: "你是一个智能助手。"
        )
        configManager.config.personaCards.append(newCard)
        if configManager.config.selectedPersonaId == nil {
            configManager.config.selectedPersonaId = newCard.id
        }
    }
    
    func deletePersona(_ card: PersonaCard) {
        configManager.config.personaCards.removeAll { $0.id == card.id }
        if configManager.config.selectedPersonaId == card.id {
            configManager.config.selectedPersonaId = configManager.config.personaCards.first?.id
        }
    }
}

struct PersonaCardView: View {
    let card: PersonaCard
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 选择指示器
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.cardName)
                    .font(.system(size: 14, weight: .bold))
                Text("角色名: \(card.personaName)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .opacity(isSelected ? 0.3 : 1.0)
                .disabled(isSelected) // 不允许删除当前选中的
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.blue.opacity(0.05) : Color.primary.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

struct ModernSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            
            content
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct ModernTextField: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
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

struct PromptDetailView: View {
    @State var persona: PersonaCard
    var onSave: (PersonaCard) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("编辑角色设定")
                        .font(.system(size: 18, weight: .bold))
                    Text("System Prompt 将由姓名和设计内容自动生成")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("保存并完成") {
                    onSave(persona)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("卡片命名")
                            .font(.system(size: 13, weight: .semibold))
                        TextField("例如：卡片1", text: $persona.cardName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("人格名字")
                            .font(.system(size: 13, weight: .semibold))
                        TextField("例如：青竹", text: $persona.personaName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("您希望它能做什么？")
                            .font(.system(size: 13, weight: .semibold))
                        TextEditor(text: $persona.description)
                            .font(.system(size: 13))
                            .frame(height: 200)
                            .padding(4)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("预览生成的 System Prompt")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(persona.systemPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(8)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
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
        let cm = ConfigManager()
        ContentView(configManager: cm, engine: MessageEngine(configManager: cm), selectedTab: .constant(0))
    }
}
