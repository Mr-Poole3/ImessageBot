```
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
```

## Codebase Overview

This repository contains **ImessageBot**, a macOS application that acts as an AI-powered chatbot for Apple's iMessage. It monitors incoming iMessages, processes them using AI, and sends automated responses.

## Project Structure

```
ImessageBot/
├── ImessageBot.xcodeproj/          # Xcode project file
└── ImessageBot/                    # Main application code
    ├── AIService.swift             # AI API integration (Volcengine Ark)
    ├── ConfigManager.swift         # Configuration management
    ├── ContentView.swift           # Main UI components
    ├── EmojiService.swift          # Emoji/meme generation service
    ├── ImessageBotApp.swift        # Application entry point
    ├── LogManager.swift            # Logging system
    └── MessageEngine.swift         # Core message processing engine
```

## Key Technologies

- **Language**: Swift
- **Framework**: SwiftUI (macOS)
- **AI Service**: Volcengine Ark API (doubao-seed-1-6-flash-250828 model)
- **Database**: SQLite (iMessage chat.db)
- **Emoji Service**: Yaohud API
- **Automation**: AppleScript for sending messages

## Building and Running

### Requirements
- macOS 12.0+
- Xcode 14.0+
- Apple Developer account (for code signing)

### Build Commands
```bash
# Open project in Xcode
open ImessageBot/ImessageBot.xcodeproj

# Build from command line
xcodebuild -project ImessageBot/ImessageBot.xcodeproj -scheme ImessageBot -configuration Debug build
```

### Running the App
1. Open project in Xcode
2. Select target device (Mac)
3. Click "Run" (▶️) button or press `Cmd+R`

## Configuration

### First-Time Setup
1. After first run, app will prompt for permissions
2. Enable "Full Disk Access" in System Settings → Privacy & Security
3. Configure API keys in the app settings:
   - **Ark API Key**: For AI responses (obtain from volcengine.com)
   - **Emoji API Key**: For meme generation (optional, obtain from api.yaohud.cn)

### Configuration File
Settings are stored in `~/.imessagebot` (JSON format)

## Core Architecture

### Message Flow
1. `MessageEngine` polls iMessage database (chat.db) for new messages
2. When trigger prefix is detected, message is sent to `AIService`
3. AI generates response with emoji keyword
4. Response is split into segments and sent via AppleScript
5. Optional emoji is downloaded and sent if configured

### Key Classes

#### MessageEngine
- **File**: `MessageEngine.swift`
- **Responsibilities**:
  - Monitor iMessage database
  - Detect trigger prefix in incoming messages
  - Coordinate message processing workflow
  - Send responses using AppleScript

#### AIService
- **File**: `AIService.swift`
- **Responsibilities**:
  - Call Volcengine Ark API
  - Handle AI response parsing
  - Format system prompts with persona information

#### ConfigManager
- **File**: `ConfigManager.swift`
- **Responsibilities**:
  - Manage application settings
  - Load/save configuration from disk
  - Manage persona cards (AI personalities)

#### ContentView
- **File**: `ContentView.swift`
- **Responsibilities**:
  - Main UI for settings and log viewing
  - Tab-based navigation (Settings / Logs)
  - Persona card management

#### LogManager
- **File**: `LogManager.swift`
- **Responsibilities**:
  - Centralized logging system
  - Real-time log display
  - Log level management (info/warning/error/success)

## Testing

### Running Tests
```bash
# Run all tests from Xcode
# Or use command line:
xcodebuild -project ImessageBot/ImessageBot.xcodeproj -scheme ImessageBot test
```

### Testable Components
- Message parsing and splitting logic
- Configuration management
- API response handling
- Persona card operations

## Debugging

### Key Debug Areas
1. **Permissions**: Ensure Full Disk Access is granted
2. **API Keys**: Verify Ark API key is valid
3. **Log View**: Check real-time logs in app for errors
4. **Database Access**: Verify chat.db is accessible at `~/Library/Messages/chat.db`

## Common Development Tasks

### Adding New Features
1. Create new Swift files in ImessageBot/ directory
2. Update ContentView for UI changes
3. Modify MessageEngine for new message handling logic
4. Update ConfigManager if new settings are needed

### Customizing Personas
- Edit persona cards in the Settings tab
- Persona system prompt is auto-generated from: `姓名: [name]\n[description]`
- Multiple personas can be configured with different personalities

### Changing AI Model
Modify `AIService.swift` line 19:
```swift
"model": "doubao-seed-1-6-flash-250828",
```

## Important Notes

- App requires Full Disk Access to read iMessage database
- First run will show security warnings (unsigned app)
- Responses are sent via AppleScript, which may have delays
- Configuration changes take effect immediately without restarting
