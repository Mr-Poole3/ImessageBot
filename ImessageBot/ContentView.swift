import SwiftUI

struct ContentView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var engine: MessageEngine
    @ObservedObject var logManager = LogManager.shared
    @Binding var selectedTab: Int
    
    var body: some View {
        ZStack {
            // Animated Gradient Background
            BackgroundGradient()
                .ignoresSafeArea()
            
            HStack(spacing: 20) {
                // Sidebar - Floating Glass Island
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 64, height: 64)
                                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                                
                                Image("logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .cornerRadius(10)
                        }
                        
                        Text("iMessage Bot")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.primary, .primary.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 8) {
                        SidebarButton(title: "设置", icon: "square.grid.2x2.fill", isSelected: selectedTab == 0) {
                            withAnimation(.spring()) { selectedTab = 0 }
                        }
                        SidebarButton(title: "日志", icon: "terminal.fill", isSelected: selectedTab == 1) {
                            withAnimation(.spring()) { selectedTab = 1 }
                        }
                    }
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        StatusBadge(isRunning: engine.isRunning)
                        
                        Button(action: toggleEngine) {
                            Text(engine.isRunning ? "停止服务" : "启动服务")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: engine.isRunning ? [.red, .orange] : [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: (engine.isRunning ? Color.red : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(engine.isRunning ? 1.0 : 1.02)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: engine.isRunning)
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(20)
                    .padding(12)
                }
                .frame(width: 220)
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.vertical, 20)
                .padding(.leading, 20)
                
                // Main Content - Glass Card
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    if selectedTab == 0 {
                        SettingsTabView(configManager: configManager)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    } else {
                        LogView(logs: logManager.logs)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    }
                }
                .padding(.vertical, 20)
                .padding(.trailing, 20)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .onAppear {
            LogManager.shared.log("欢迎使用 iMessage Bot！程序已准备就绪。")
        }
        .alert(engine.alertMessage, isPresented: $engine.showAlert) {
            Button("好的", role: .cancel) { }
        }
    }
    
    func toggleEngine() {
        withAnimation(.spring()) {
            engine.toggle(with: configManager.config)
            if engine.isRunning {
                selectedTab = 1
            }
        }
    }
}

// MARK: - New Components

struct BackgroundGradient: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            
            LinearGradient(colors: [Color.blue.opacity(0.12), Color.white.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .hueRotation(.degrees(animate ? 10 : 0))
                .onAppear {
                    withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                        animate.toggle()
                    }
                }
            
            // Subtle blue mesh blobs
            Circle()
                .fill(Color.blue.opacity(0.08))
                .frame(width: 500, height: 500)
                .blur(radius: 100)
                .offset(x: animate ? -50 : 50, y: animate ? 50 : -50)
            
            Circle()
                .fill(Color.cyan.opacity(0.05))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: animate ? 100 : -100, y: animate ? -50 : 50)
        }
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? icon : icon.replacingOccurrences(of: ".fill", with: ""))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? 
                        AnyShapeStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)) : 
                        AnyShapeStyle(Color.secondary.opacity(0.8)))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.05))
                    }
                }
            )
            .foregroundColor(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct StatusBadge: View {
    let isRunning: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isRunning ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                
                if isRunning {
                    Circle()
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                        .scaleEffect(1.5)
                        .opacity(0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isRunning)
                }
            }
            
            Text(isRunning ? "服务正在运行" : "服务已停止")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isRunning ? .green : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isRunning ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(20)
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("设置")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                        Text("配置您的 iMessage 机器人助手")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        if showSuccess || showError {
                            HStack(spacing: 6) {
                                Image(systemName: showSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(showSuccess ? .green : .red)
                                Text(showSuccess ? "保存成功" : "保存失败")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(showSuccess ? .green : .red)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background((showSuccess ? Color.green : Color.red).opacity(0.1))
                            .cornerRadius(12)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        
                        Button(action: saveSettings) {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.down.doc.fill")
                                }
                                Text(isSaving ? "保存中..." : "保存更改")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                }
                .padding(.bottom, 16)
                
                Group {
                    ModernSection(title: "基础服务配置", icon: "key.fill") {
                        VStack(alignment: .leading, spacing: 16) {
                            ModernTextField(label: "Ark API Key", text: $configManager.config.apiKey, isSecure: true, placeholder: "请输入您的API KEY") {
                                HStack(spacing: 4) {
                                    if configManager.config.apiKey.isEmpty {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("未设置 API Key，机器人将无法回复")
                                            .foregroundColor(.orange)
                                    }
                                    Text("获取地址:")
                                    Link("volcengine.com", destination: URL(string: "https://www.volcengine.com/")!)
                                        .underline()
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            }
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
                        VStack(alignment: .leading, spacing: 16) {
                            ModernTextField(label: "表情包 API Key (Yaohud)", text: $configManager.config.emojiApiKey, placeholder: "请输入您的API KEY") {
                                HStack(spacing: 4) {
                                    if configManager.config.emojiApiKey.isEmpty {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(.blue)
                                        Text("未设置则不启用表情包功能")
                                            .foregroundColor(.blue)
                                    }
                                    Text("获取地址:")
                                    Link("api.yaohud.cn", destination: URL(string: "https://api.yaohud.cn/doc/47")!)
                                        .underline()
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            }
                        }
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
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 选择指示器
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.blue : Color.primary.opacity(0.1), lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.cardName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("角色名: \(card.personaName)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
                .opacity(isSelected ? 0.3 : 1.0)
                .disabled(isSelected)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            isSelected ? 
            LinearGradient(colors: [.blue.opacity(0.15), .cyan.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing) : 
            LinearGradient(colors: [Color.primary.opacity(0.03)], startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            
            content
        }
        .padding(24)
        .background(Color.white.opacity(0.03))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct ModernTextField<Footer: View>: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false
    var placeholder: String = ""
    var footer: Footer
    
    @FocusState private var isFocused: Bool
    
    init(label: String, text: Binding<String>, isSecure: Bool = false, placeholder: String = "", @ViewBuilder footer: () -> Footer) {
        self.label = label
        self._text = text
        self.isSecure = isSecure
        self.placeholder = placeholder
        self.footer = footer()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .focused($isFocused)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            footer
        }
    }
}

extension ModernTextField where Footer == EmptyView {
    init(label: String, text: Binding<String>, isSecure: Bool = false, placeholder: String = "") {
        self.init(label: label, text: text, isSecure: isSecure, placeholder: placeholder, footer: { EmptyView() })
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("运行日志")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text("实时监控机器人运行状态")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { LogManager.shared.clear() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("清空日志")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            
            Divider()
                .opacity(0.1)
            
            List {
                ForEach(logs) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Text(entry.formattedTime)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                        
                        Text(entry.message)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(entryColor(for: entry.level))
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    private func entryColor(for level: LogManager.LogLevel) -> Color {
        switch level {
        case .info: return .primary.opacity(0.9)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("编辑角色设定")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text("System Prompt 将根据角色名和描述自动生成")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    onSave(persona)
                    dismiss()
                }) {
                    Text("保存设置")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
            
            Divider().opacity(0.1)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ModernTextField(label: "卡片命名", text: $persona.cardName, placeholder: "例如：日常助手")
                    
                    ModernTextField(label: "人格名字", text: $persona.personaName, placeholder: "机器人对自己的称呼")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("角色能力与描述")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $persona.description)
                            .font(.system(size: 14, design: .rounded))
                            .frame(height: 180)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 12))
                            Text("System Prompt 预览")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.secondary)
                        
                        Text(persona.systemPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
                .padding(32)
            }
        }
        .frame(width: 550, height: 680)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let cm = ConfigManager()
        ContentView(configManager: cm, engine: MessageEngine(configManager: cm), selectedTab: .constant(0))
    }
}
