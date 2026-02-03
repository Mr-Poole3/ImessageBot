# LLM Adapter Architecture Documentation

## Overview

This project uses an Adapter Pattern to handle the differences between various LLM providers (e.g., OpenAI, Ollama, Volcengine). This architecture allows the core business logic (`AIService`) to remain provider-agnostic while ensuring compatibility with different API specifications.

## Core Components

### 1. LLMAdapter Protocol

The `LLMAdapter` protocol defines the contract that all provider adapters must implement:

```swift
protocol LLMAdapter {
    /// Prepare HTTP headers
    func headers(apiKey: String) -> [String: String]
    
    /// Prepare request body
    func prepareRequestBody(model: String, messages: [[String: Any]], tools: [Tool], useTools: Bool) -> [String: Any]
    
    /// Format tool arguments for sending back to the API in the message history
    func formatToolArgumentsForHistory(_ arguments: String) -> Any
}
```

### 2. Adapters

#### OpenAIAdapter
Standard adapter for OpenAI and compatible services (like Volcengine).
- **Tool Arguments**: Formatted as JSON Strings.
- **Request Format**: Uses standard OpenAI chat completion structure.

#### OllamaAdapter
Specialized adapter for Ollama.
- **Tool Arguments**: Formatted as Dictionary (Object) to prevent 400 errors.
- **Request Format**: Handles Ollama's specific JSON structure (e.g., omitting `format: json` when tools are present).

### 3. AdapterFactory

A factory class that returns the correct adapter instance based on the user's configuration (`AIProvider`).

```swift
class AdapterFactory {
    static func getAdapter(for provider: AIProvider) -> LLMAdapter {
        switch provider {
        case .openai, .volcengine:
            return OpenAIAdapter()
        case .ollama:
            return OllamaAdapter()
        }
    }
}
```

## How to Add a New Provider

To add support for a new LLM provider (e.g., Anthropic Claude):

1.  **Create a New Adapter**:
    Create a new class implementing `LLMAdapter` in `LLMAdapter.swift`.
    ```swift
    class ClaudeAdapter: LLMAdapter {
        // Implement required methods
    }
    ```

2.  **Update AdapterFactory**:
    Add the new case to `AdapterFactory`.
    ```swift
    case .claude:
        return ClaudeAdapter()
    ```

3.  **Update AppConfig**:
    Add the new provider case to the `AIProvider` enum in `ConfigManager.swift`.

## Key Benefits

-   **Decoupling**: `AIService` no longer contains provider-specific logic.
-   **Extensibility**: Adding new providers does not require modifying core logic.
-   **Maintainability**: Provider-specific quirks (like Ollama's argument formatting) are isolated in their respective adapters.
