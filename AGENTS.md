# iMessage Bot - Agent Coding Guidelines

## Project Overview
macOS SwiftUI application that creates an AI-powered bot for iMessage. Polls the local iMessage database, processes messages with AI, and sends automated responses.

## Build & Commands

### Building
```bash
# Open in Xcode
open ImessageBot.xcodeproj

# Or use command line
xcodebuild -project ImessageBot.xcodeproj -scheme ImessageBot build

# Create DMG distribution
python3 build_dmg.py
```

### Running
No test suite currently exists. Run the app through Xcode or build and run the .app directly.

### Permissions Required
- Full Disk Access (System Settings → Privacy & Security) - Required to read iMessage database

---

## Code Style Guidelines

### Language & Framework
- Swift with SwiftUI for UI
- Target: macOS 13+
- Uses Combine for reactive patterns
- Uses async/await for concurrency

### Imports
- Standard imports first (Foundation, SwiftUI)
- Third-party/framework imports second
- Keep imports minimal and relevant to the file
- Common imports: `import Foundation`, `import SwiftUI`, `import Combine`, `import SQLite3`

### Naming Conventions
- **Classes/Structs**: PascalCase (`MessageEngine`, `ConfigManager`, `PersonaCard`)
- **Functions/Methods**: camelCase (`toggle()`, `start()`, `poll()`)
- **Variables/Properties**: camelCase (`isRunning`, `alertMessage`, `configManager`)
- **Constants**: camelCase with descriptive names (`dbPath`, `maxLogs`)
- **Views**: PascalCase with descriptive names (`ContentView`, `SettingsTabView`)
- **SwiftUI modifiers**: Chain calls with proper indentation

### File Organization
- One major class/struct per file (e.g., `AIService.swift`, `ConfigManager.swift`)
- Large views (ContentView) include helper components in same file
- Use `// MARK: -` to organize logical sections
- Place related code together (state, computed properties, methods)

### Types & Data Models
- Use `struct` for data models conforming to `Codable`
- Use `class` for services, managers, and ObservableObjects
- Prefer strong typing over `Any` (except in dynamic API requests)
- Use `UUID` for unique identifiers
- Model hierarchy: `AppConfig` → `PersonaCard[]` → selected persona

### State Management
- Use `@State` for local view state
- Use `@Binding` for passing state between views
- Use `@ObservedObject` for external observable objects
- Use `@Published` for properties that trigger updates
- Use `@FocusState` for input focus management
- Use `@StateObject` for owned observable objects in views

### SwiftUI Patterns
- Extract reusable components (e.g., `SidebarButton`, `ModernSection`, `ModernTextField`)
- Use generic components with `@ViewBuilder` for flexibility
- Use `NSViewRepresentable` for AppKit bridging when needed
- Prefer `.buttonStyle(.plain)` for custom styled buttons
- Use `.sheet(item:)` for presenting detail views
- Chain modifiers logically (e.g., `.padding().background().cornerRadius()`)

### Error Handling
- Use `do-try-catch` for async operations and network calls
- Return `Bool` for save operations (true = success)
- Use `@Published` alert properties for user-facing errors
- Log errors using `LogManager.shared.log(..., level: .error)`
- Validate user input before operations (e.g., API key checks)

### Async & Concurrency
- Use `async/await` for async operations
- Wrap async work in `Task` blocks when called from sync contexts
- Use `[weak self]` in closures to prevent retain cycles
- Handle cancellation points appropriately in long-running operations
- Use `Task.sleep(nanoseconds:)` for delays

### Logging
- Use `LogManager.shared.log(message, level: .info)` for logging
- Log levels: `.info`, `.warning`, `.error`, `.success`
- Important events should be logged (service start/stop, messages received/sent, errors)
- Max 500 log entries stored in memory

### Database (SQLite3)
- Use SQLite3 C API directly (`sqlite3_open`, `sqlite3_prepare_v2`, `sqlite3_step`, etc.)
- Always finalize statements with `sqlite3_finalize()`
- Always close database with `sqlite3_close()` when done
- Handle connection errors gracefully with user feedback
- Poll database on timer (2-second interval)

### Networking
- Use `URLSession.shared.data(for: request)` for HTTP requests
- Set proper headers (Authorization, Content-Type)
- Use `JSONSerialization` and `JSONDecoder` for API responses
- Handle network errors and log appropriately

### File I/O
- Config saved to `~/.imessagebot`
- Use `FileManager.default` for file operations
- Use `FileManager.default.temporaryDirectory` for temporary files
- Clean up temporary files after use

### UI/UX Guidelines
- Provide user feedback for async operations (loading states, success/error alerts)
- Use menu bar extra for quick access to main features
- Provide keyboard shortcuts for common actions
- Ensure accessibility with proper labels and focus management
- Use semantic colors and system fonts for native feel

### Code Quality
- Keep functions focused and under 50 lines when possible
- Extract complex logic into separate methods
- Prefer computed properties for derived values
- Use guard statements for early returns
- Avoid force unwrapping (!) except in safe contexts
- Use meaningful variable and function names

### Adding Features
1. Add new models as structs conforming to Codable
2. Add services as classes with static methods for simple operations
3. Create reusable SwiftUI components in ContentView or separate files
4. Add logging for important operations
5. Update AppConfig if new configuration needed
6. Save/load changes through ConfigManager

### Testing & Debugging
- Check logs in the app's Log View tab
- Ensure Full Disk Access permission is granted before testing database operations
- Test with different trigger prefixes and persona configurations
- Verify async operations complete properly without blocking UI
