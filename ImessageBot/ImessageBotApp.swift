//
//  ImessageBotApp.swift
//  ImessageBot
//
//  Created by Mac on 2026/1/30.
//

import SwiftUI

@main
struct ImessageBotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var configManager: ConfigManager
    @StateObject private var engine: MessageEngine
    
    init() {
        let cm = ConfigManager()
        _configManager = StateObject(wrappedValue: cm)
        _engine = StateObject(wrappedValue: MessageEngine(configManager: cm))
    }
    
    @State private var selectedTab = 0
    
    var body: some Scene {
        WindowGroup {
            ContentView(configManager: configManager, engine: engine, selectedTab: $selectedTab)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) {
                Button("剪切") { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }.keyboardShortcut("x", modifiers: .command)
                Button("拷贝") { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }.keyboardShortcut("c", modifiers: .command)
                Button("粘贴") { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }.keyboardShortcut("v", modifiers: .command)
                Button("全选") { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }.keyboardShortcut("a", modifiers: .command)
            }
            CommandGroup(replacing: .sidebar) { }
            CommandGroup(after: .toolbar) {
                Button("显示设置") { selectedTab = 0 }.keyboardShortcut(",", modifiers: .command)
                Button("显示运行日志") { selectedTab = 1 }.keyboardShortcut("l", modifiers: .command)
            }
            CommandMenu("机器人") {
                Button(engine.isRunning ? "停止服务" : "启动服务") { toggleEngine() }.keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("清空运行日志") { LogManager.shared.clear() }.keyboardShortcut("k", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button("iMessage Bot 帮助") {
                    if let url = URL(string: "https://support.apple.com/zh-cn/guide/mac-help/mchl211c911f/mac") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        MenuBarExtra {
            Button(engine.isRunning ? "停止服务" : "启动服务") {
                toggleEngine()
            }
            
            Divider()
            
            // 人格库选择子菜单
            Menu("选择人格角色") {
                ForEach(configManager.config.personaCards) { card in
                    Button {
                        configManager.config.selectedPersonaId = card.id
                        _ = configManager.saveConfig() // 自动保存
                    } label: {
                        HStack {
                            if configManager.config.selectedPersonaId == card.id {
                                Image(systemName: "checkmark")
                            }
                            Text(card.cardName)
                        }
                    }
                }
            }
            
            Divider()
            
            Button("显示主界面") {
                openMainWindow()
            }
            
            Button("退出 iMessage Bot") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            HStack {
                Image("MenuBarIcon") // 使用您创建的自定义图标资源
                if engine.isRunning {
                    Text("运行中")
                }
            }
        }
    }
    
    func toggleEngine() {
        engine.toggle(with: configManager.config)
        // 如果启动失败且窗口未打开，强制打开窗口以显示错误提示
        if !engine.isRunning && engine.showAlert {
            openMainWindow()
        }
    }
    
    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // 在 SwiftUI 中，如果窗口已经关闭，激活应用可能不会自动重新打开窗口（取决于配置）
        // 但通常 WindowGroup 会处理这个
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        } else {
            // 如果没有窗口，通过 URL Scheme 或者重新触发 WindowGroup 行为（这在 SwiftUI 比较难）
            // 但在 macOS 13+ 中，激活应用通常会重新打开 WindowGroup 的窗口。
            // 另一种方法是使用环境变量控制窗口显示
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // 即使关闭所有窗口也不退出程序
    }
}
