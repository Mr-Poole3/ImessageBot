# iMessage Bot 🤖

[![GitHub stars](https://img.shields.io/github/stars/2840269475/ImessageBot.svg?style=flat-square)](https://github.com/2840269475/ImessageBot/stargazers)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)

一个基于 macOS 原生 iMessage 的 AI 自动化机器人。通过集成先进的 AI 模型，让您的 iMessage 具备智能回复、角色扮演及自动化处理能力。

---

## 📦 官方资源

- [访问 iMessageBot 官网](https://imessagebot.aetheriaai.cn/)
- [立即下载 iMessageBot.dmg](https://imessagebot.aetheriaai.cn/download/iMessageBot.dmg)

---

## 🌟 核心特性

- **原生集成**：直接与 macOS 消息系统交互，无需通过第三方协议。
- **AI 智能驱动**：支持自定义 AI 角色设定，提供拟人化的对话体验。
- **自动化回复**：毫秒级轮询 iMessage 数据库，确保消息处理的即时性。
- **后台常驻**：支持 macOS 菜单栏常驻运行，实时监控，不干扰日常使用。
- **可视化配置**：提供简洁的 GUI 界面，轻松管理 API 密钥、角色设定及运行日志。
- **本地化检测**：实时监听本地 iMessage 数据，不经云端同步，数据仅在本机处理。
- **隐私保护**：不上传聊天记录，所有处理在本地完成，仅与配置的 API 进行必要交互。
- **智能分段发送**：自动拆分长文本，模拟真人输入节奏。
- **表情包互动**：根据语境智能选择并发送匹配的表情包，提升交流亲和力。

## 💡 运行原理

本机器人的核心工作流程如下：
1. **消息监听**：实时检测 macOS 本地的 iMessage 数据库 (`chat.db`)，获取新收到的消息内容。
2. **AI 处理**：将消息发送至预设的 AI 模型进行分析并生成回复。
3. **消息发送**：调用 macOS 原生能力，通过您的 iMessage 账号发送回复。

**⚠️ 重要提示：关于“自发自收”测试**
如果您希望在同一台设备或同一账号下进行测试（即自己给自己发信息），请务必区分发送端和接收端的 iMessage 账号标识。例如：
- **手机端**：设置通过“手机号”发送 iMessage。
- **Mac 端**：设置通过“邮箱地址”发送 iMessage。

这样可以避免消息循环或系统无法正确识别消息来源的问题。

## 🚀 快速开始

### 1. 环境要求
- 运行 macOS 的电脑（需开启 iMessage 登录）。
- 已安装 Xcode (若需自行编译)。

### 2. 安装与配置
0. **下载与安装**：
   - 直接下载并打开 DMG 安装包：[iMessageBot.dmg](https://imessagebot.aetheriaai.cn/download/iMessageBot.dmg)
1. **获取权限**：
   - 打开 `系统设置 -> 隐私与安全性 -> 完全磁盘访问权限`。
   - 点击 `+` 号，手动添加 `iMessageBot.app` 并勾选开启。
2. **配置 API**：
   - 启动应用，在设置界面输入您的 AI 服务商 API Key。
3. **开启服务**：
   - 点击“启动服务”按钮，程序将自动开始监控新接收到的消息。

## 🧰 LLM 工具调用能力

- 支持 OpenAI/火山引擎的函数调用与 Ollama 原生工具调用，已适配参数格式差异。
- 工具由模型自动判定调用时机，执行结果会注入上下文，随后进行二次回复生成。
- 可用工具列表：
  - get_weather：参数 city（城市名），用于天气查询
  - web_search：参数 query（关键词），用于实时信息检索
  - create_calendar_event：参数 title、start_time、end_time、notes
    - 时间格式必须为 yyyy-MM-dd HH:mm:ss，例如 2026-02-01 14:00:00
    - 需要系统“日历”访问权限，已在工程中声明
- 使用示例（模型内部自动生成，示意）：

```json
{
  "name": "create_calendar_event",
  "arguments": {
    "title": "团队周会",
    "start_time": "2026-02-05 10:00:00",
    "end_time": "2026-02-05 11:00:00",
    "notes": "讨论版本发布与Bug修复"
  }
}
```

- 说明与注意事项：
  - 我们在系统提示中注入“当前时间”，便于模型正确解析“明天/下周五”等相对时间。
  - 工具执行后的结果作为“tool”消息回传，模型基于该结果生成最终自然语言回复。
  - 日历工具默认事件时长 1 小时，可通过 end_time 覆盖。

- 代码参考：
  - 工具定义与执行：[ToolService.swift](file:///Users/mac/ai-house/ImessageBot/ImessageBot/ToolService.swift)
  - 工具调用流程与二次请求：[AIService.swift](file:///Users/mac/ai-house/ImessageBot/ImessageBot/AIService.swift)
  - 多提供商适配（OpenAI/Ollama）：[LLMAdapter.swift](file:///Users/mac/ai-house/ImessageBot/ImessageBot/LLMAdapter.swift)

## 🛠 开发与构建

项目采用 Swift 语言开发，遵循现代 macOS 应用设计规范。

```bash
# 克隆仓库
git clone https://github.com/2840269475/ImessageBot.git
```

## 🤝 贡献指南

我们非常欢迎大家克隆本项目并进行改进！如果您有任何想法或建议，请：
1. Fork 本项目。
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)。
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)。
4. 推送到分支 (`git push origin feature/AmazingFeature`)。
5. 开启一个 Pull Request。

## 📄 开源协议

本项目采用 [MIT 协议](LICENSE) 开源。

## 📬 联系方式

如果您有商业合作意向或技术反馈，欢迎通过以下方式联系：

- **Email**: [2840269475@qq.com](mailto:2840269475@qq.com)

---

**如果这个项目对您有帮助，请给一个 ⭐️ Star！这是对我们最大的支持。**
