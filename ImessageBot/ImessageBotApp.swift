//
//  ImessageBotApp.swift
//  ImessageBot
//
//  Created by Mac on 2026/1/30.
//

import SwiftUI

@main
struct ImessageBotApp: App {
    @StateObject private var configManager = ConfigManager()
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
            // 精简菜单栏：只移除绝对不需要的项
            CommandGroup(replacing: .newItem) { } // 移除“文件”菜单中的新建/打开
            
            // 编辑菜单
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) {
                Button("剪切") {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x", modifiers: .command)
                
                Button("拷贝") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c", modifiers: .command)
                
                Button("粘贴") {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("v", modifiers: .command)
                
                Button("全选") {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
            }
            
            // 移除 View 菜单中的侧边栏控制
            CommandGroup(replacing: .sidebar) { }
            
            // 添加视图切换菜单
            CommandGroup(after: .toolbar) {
                Button("显示设置") {
                    selectedTab = 0
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Button("显示运行日志") {
                    selectedTab = 1
                }
                .keyboardShortcut("l", modifiers: .command)
            }
            
            // 添加机器人控制菜单
            CommandMenu("机器人") {
                Button(engine.isRunning ? "停止服务" : "启动服务") {
                    toggleEngine()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Divider()
                
                Button("清空运行日志") {
                    LogManager.shared.clear()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
            
            // 帮助菜单
            CommandGroup(replacing: .help) {
                Button("iMessage Bot 帮助") {
                    if let url = URL(string: "https://support.apple.com/zh-cn/guide/mac-help/mchl211c911f/mac") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
    
    func toggleEngine() {
        engine.toggle(with: configManager.config)
    }
}
