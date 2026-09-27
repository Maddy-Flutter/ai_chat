# NVIDIA AI Desktop (`aigui`)

A cross-platform desktop AI chat application built with **Flutter**, **Clean Architecture (MVVM)**, and **Riverpod**, powered by **NVIDIA NIM** (Inference Microservice) endpoints.

Run on **Windows**, **macOS**, and **Linux** with a native desktop user experience, bringing your own NVIDIA API key, dynamic LLM model selection, real-time streaming, local workspace projects with file context injection, and offline-first database persistence.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture & Design Principles](#architecture--design-principles)
- [Project Code Structure](#project-code-structure)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Getting Started & How to Use](#getting-started--how-to-use)
  - [1. Clone & Setup](#1-clone--setup)
  - [2. Obtain NVIDIA NIM API Key](#2-obtain-nvidia-nim-api-key)
  - [3. Run the Desktop App](#3-run-the-desktop-app)
  - [4. Usage Guide](#4-usage-guide)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Testing & Quality](#testing--quality)

---

## Overview

**NVIDIA AI Desktop** delivers a desktop-first AI workspace functionally comparable to Claude Desktop and Gemini Desktop. The application communicates with NVIDIA's OpenAI-compatible NIM API (`https://integrate.api.nvidia.com/v1`), allowing users to interact with leading models (e.g., Meta LLaMA 3, Mistral, DeepSeek, and NVIDIA Nemotron).

All conversations, projects, and indexed workspace files are stored **locally** on your device using a high-performance SQLite database via **Drift**, ensuring privacy and full offline access to past chat history.

---

## Key Features

- **⚡ Real-Time Streaming (SSE)**: Fast token streaming using Server-Sent Events with mid-stream cancel / stop generation support.
- **📁 Projects & File Context Injection**: Create workspace projects, link local directories or individual files (`.dart`, `.md`, `.txt`, `.json`, `.py`, etc.), toggle files on/off, and inject them into LLM context with configurable character/token budgets.
- **🔐 Bring Your Own Key (BYOK) Security**: Secure storage of your NVIDIA NIM API key via OS keychain/credential vault (`flutter_secure_storage`). Zero secret leakage.
- **🧠 Dynamic Model Catalog**: Fetches the latest models available from NVIDIA NIM dynamically with local caching, search, and manual refresh.
- **🎛️ Per-Conversation Tuning**: Customize hyperparameters on the fly (Temperature, Top-P, Max Tokens, and custom System Prompts).
- **📝 Rich Markdown & Code Syntax Highlighting**: Full Markdown formatting with syntax highlighting across dozens of languages, complete with one-click code copy.
- **🗃️ Local Persistence & History**: Powered by **Drift (SQLite)**. Threads organized into *Today*, *Yesterday*, *Previous 7 Days*, and *Older*, featuring conversation pinning, renaming, message editing/resending, regeneration, and deletion.
- **🖥️ Desktop-Optimized UX**:
  - Custom frameless title bar with drag and native window controls (`window_manager`).
  - Remembered window dimensions and minimum size constraints (960x640 min, 1280x820 default).
  - Smart auto-scroll that pauses when manually scrolling up and resumes at the bottom.
  - Collapsible desktop sidebar.
  - Global desktop keyboard shortcuts.
- **🎨 Modern Dark & Light Theming**: Custom-crafted NVIDIA green branding with high-contrast dark surfaces, polished glass accents, and responsive layout.

---

## Architecture & Design Principles

The application strictly adheres to **Clean Architecture** and **MVVM (Model-View-ViewModel)** with **Riverpod**:

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                      │
│   Widgets (Views)  ◄───►  ViewModels (StateNotifier/Notifier)│
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                        Domain Layer                         │
│     Entities  •  Repository Contracts  •  Business Logic    │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                         Data Layer                          │
│   Repository Implementations  •  Data Sources  •  Models    │
│   (NvidiaApiDataSource, AppDatabase, SecureStorageDataSource)│
└─────────────────────────────────────────────────────────────┘
                               ▲
┌──────────────────────────────┴──────────────────────────────┐
│                      Core & App Layers                      │
│      Network (SSE) • Errors (Result<T>) • Theme • Router    │
└─────────────────────────────────────────────────────────────┘
```

### Core Architecture Rules:
1. **Zero `setState` for business logic**: All state flows unidirectionally through Riverpod. `StatefulWidget` is reserved strictly for controller lifecycles (`TextEditingController`, `ScrollController`, `FocusNode`).
2. **ViewModel Independence**: ViewModels never import `package:flutter/material.dart` and remain decoupled from UI layout.
3. **Typed Functional Results**: Operations return `Result<T, AppFailure>` rather than throwing raw unhandled exceptions into the UI layer.
4. **Data Isolation**: Remote and local data sources (NVIDIA HTTP/SSE, SQLite Drift, and Secure Storage) are abstracted behind domain repository interfaces.

---

## Project Code Structure

```
lib/
├── main.dart                                # Desktop bootstrap, window_manager initialization & ProviderScope
│
├── app/                                     # App-level configurations
│   ├── app.dart                             # Root MaterialApp.router configuration
│   ├── router/
│   │   └── app_router.dart                  # Declarative GoRouter setup (ShellRoutes for Chat, Projects, Settings)
│   └── theme/
│       ├── app_theme.dart                   # Custom Dark & Light palettes with NVIDIA Green accents
│       └── theme_provider.dart              # Riverpod theme mode state provider
│
├── core/                                    # Cross-cutting foundational modules
│   ├── constants/
│   │   └── app_constants.dart               # API URLs, default models, window bounds & storage keys
│   ├── errors/
│   │   ├── app_failure.dart                 # Failure sealed classes (Network, Auth, Database, RateLimit)
│   │   └── result.dart                      # Functional Result<T, AppFailure> monad pattern
│   ├── network/
│   │   └── sse_stream_parser.dart           # Server-Sent Events (SSE) chunk & delta parser
│   └── utils/
│       └── app_logger.dart                  # Centralized structured logging
│
├── data/                                    # Data access and external communication
│   ├── datasources/
│   │   ├── local/
│   │   │   ├── database/
│   │   │   │   ├── app_database.dart        # Drift SQLite schema (Conversations, Messages, Projects, Files)
│   │   │   │   └── app_database.g.dart      # Generated Drift database code
│   │   │   ├── project_file_data_source.dart# Local file reader, directory walker, and char budgeting
│   │   │   └── secure_storage_data_source.dart # Encrypted API key storage via flutter_secure_storage
│   │   └── remote/
│   │       └── nvidia_api_data_source.dart  # Dio HTTP client, /models fetcher, and /chat/completions SSE stream
│   ├── di/
│   │   └── repository_providers.dart        # Riverpod Dependency Injection wiring for data sources & repos
│   ├── models/
│   │   └── nvidia_model_dto.dart            # API Data Transfer Objects with JSON mapping
│   └── repositories/
│       ├── chat_repository_impl.dart        # Chat threads and message persistence implementation
│       ├── llm_repository_impl.dart         # NVIDIA NIM streaming and model catalog implementation
│       ├── project_repository_impl.dart     # Workspace projects and file attachment implementation
│       └── settings_repository_impl.dart    # User preferences, API key, and system prompt implementation
│
├── domain/                                  # Pure business logic and domain definitions
│   ├── entities/
│   │   ├── chat_message.dart                # ChatMessage entity (id, role, content, tokenCount, status)
│   │   ├── conversation.dart                # Conversation entity with hyperparameters
│   │   ├── llm_model.dart                   # LlmModel entity representation
│   │   ├── project.dart                     # Project entity (workspace with system prompt & folder)
│   │   └── project_file.dart                # ProjectFile entity for injected contextual files
│   └── repositories/
│       ├── chat_repository.dart             # Abstract interface for chat persistence
│       ├── llm_repository.dart              # Abstract interface for LLM communication
│       ├── project_repository.dart          # Abstract interface for project management
│       └── settings_repository.dart         # Abstract interface for preferences & auth
│
└── presentation/                            # UI Layer (MVVM)
    ├── chat/                                # Chat experience
    │   ├── view/
    │   │   ├── chat_page.dart               # Conversation view, prompt input, model picker & actions
    │   │   └── widgets/
    │   │       └── markdown_message_view.dart # Markdown renderer with syntax highlighted code & copy
    │   └── viewmodel/
    │       ├── chat_state.dart              # Immutable ChatState (messages, streaming text, status)
    │       └── chat_viewmodel.dart          # Chat business logic, send, stop, regenerate, auto-scroll
    ├── history/
    │   └── viewmodel/
    │       └── history_viewmodel.dart       # Chronological conversation grouping & search filtering
    ├── projects/                            # Workspace context management
    │   ├── view/
    │   │   └── projects_page.dart           # Project explorer, directory picker, and file context toggles
    │   └── viewmodel/
    │       └── projects_viewmodel.dart      # Project CRUD and file indexing logic
    ├── settings/                            # App configuration
    │   ├── view/
    │   │   └── settings_page.dart           # API key management, connection tester, defaults & data reset
    │   └── viewmodel/
    │       └── settings_viewmodel.dart      # Settings logic and API key verification
    └── shared/                              # Shared desktop UI components
        ├── desktop_scaffold.dart            # Shell scaffold combining title bar, sidebar, and body
        ├── providers/
        │   └── sidebar_provider.dart        # Sidebar collapse/expand toggle state
        └── widgets/
            ├── desktop_shortcuts.dart       # Keyboard shortcut listener wrapper
            ├── desktop_sidebar.dart         # Navigation sidebar with conversation history & search
            └── desktop_title_bar.dart       # Frameless custom window title bar with drag & controls
```

---

## Tech Stack

| Component | Library / Tool | Purpose |
|---|---|---|
| **Framework** | [Flutter](https://flutter.dev) (Dart 3.x) | Desktop targets (Windows, macOS, Linux) |
| **State Management & DI**| [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) | Reactive state management, dependency injection, testability |
| **Networking & SSE** | [`dio`](https://pub.dev/packages/dio) | HTTP requests and Server-Sent Events (SSE) streaming |
| **Local Database** | [`drift`](https://pub.dev/packages/drift) + [`drift_flutter`](https://pub.dev/packages/drift_flutter) | High-performance, type-safe SQLite database |
| **Secure Storage** | [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) | Hardware-backed encrypted storage for API keys |
| **Routing** | [`go_router`](https://pub.dev/packages/go_router) | Declarative navigation with indexed stateful shell routes |
| **Desktop Windowing** | [`window_manager`](https://pub.dev/packages/window_manager) | Window sizing, framing, custom title bar, and constraints |
| **Markdown & Code** | [`flutter_markdown`](https://pub.dev/packages/flutter_markdown) + [`flutter_highlight`](https://pub.dev/packages/flutter_highlight) | Markdown formatting and syntax highlighting |
| **File Selection** | [`file_picker`](https://pub.dev/packages/file_picker) | Native folder and file dialogs for projects |
| **Testing** | `flutter_test`, `mocktail` | Unit and widget test suites |

---

## Prerequisites

Before running the application, make sure your environment is configured for Flutter Desktop development:

1. **Flutter SDK**: Version `^3.11.0` or higher installed and added to your `PATH`.
2. **Platform Build Tools**:
   - **Windows**: Visual Studio 2022 with **"Desktop development with C++"** workload installed.
   - **macOS**: Xcode installed with command line tools (`xcode-select --install`).
   - **Linux**: Clang, CMake, GTK development libraries (`sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev`).
3. Check status:
   ```bash
   flutter doctor
   ```

---

## Getting Started & How to Use

### 1. Clone & Setup

Clone the repository and install the required dependencies:

```bash
git clone https://github.com/your-username/aigui.git
cd aigui
flutter pub get
```

*(Optional)* If you modify database tables or models, run code generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

### 2. Obtain NVIDIA NIM API Key

1. Visit [NVIDIA API Catalog (build.nvidia.com)](https://build.nvidia.com/).
2. Sign in or create a free NVIDIA developer account.
3. Select any LLM (e.g. `meta/llama-3.3-70b-instruct`).
4. Click **Get API Key** and generate your personal API key (`nvapi-...`).

---

### 3. Run the Desktop App

Launch the application on your current desktop OS:

```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

---

### 4. Usage Guide

#### A. Initial Configuration
1. When you first open the app, navigate to **Settings** (`Ctrl+,` or click the settings gear in the sidebar).
2. Enter your NVIDIA API key and click **Test Connection** to verify your key against the NVIDIA NIM endpoint.
3. Once verified, the app dynamically loads the available models from the NVIDIA registry.
4. Select your preferred default model (e.g., `meta/llama-3.3-70b-instruct`) and optional default system prompt.

#### B. Conversing with AI
1. Click **New Chat** (`Ctrl+N` or top of sidebar).
2. Pick any model from the dropdown header in the chat page.
3. Adjust inference parameters (temperature, max tokens) via the configuration panel if desired.
4. Type your prompt into the message box:
   - Press **`Enter`** to send.
   - Press **`Shift + Enter`** to insert a newline.
5. Watch the response stream in real-time with full Markdown rendering.
6. Use the **Stop** button to cancel an in-progress response at any time.
7. Hover over messages to copy, regenerate responses, edit previous prompts, or delete.

#### C. Working with Projects (Context Injection)
1. Navigate to the **Projects** tab via the sidebar.
2. Click **Create Project**, assign a name, description, and custom workspace system prompt.
3. Click **Link Folder** or **Add Files** to index source files from your local disk.
4. Enable or disable specific files using the toggles to fit within your context character budget.
5. In the chat view, link your conversation to the Project. All enabled project files and instructions will automatically be injected into context for all subsequent messages!

---

## Keyboard Shortcuts

| Shortcut (Windows / Linux) | Shortcut (macOS) | Action |
|---|---|---|
| **`Ctrl + N`** | **`Cmd + N`** | Start a New Chat |
| **`Ctrl + B`** | **`Cmd + B`** | Toggle Sidebar (Show/Hide) |
| **`Ctrl + ,`** | **`Cmd + ,`** | Open Settings |
| **`Enter`** | **`Return`** | Send message in chat input |
| **`Shift + Enter`** | **`Shift + Return`** | Insert newline in chat input |

---

## Testing & Quality

Run unit and widget tests:

```bash
flutter test
```

Perform static analysis to verify lint rules and clean code standards:

```bash
flutter analyze
```

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
