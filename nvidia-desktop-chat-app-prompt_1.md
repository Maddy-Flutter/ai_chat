# Build Prompt — Cross-Platform AI Chat Desktop App (Flutter + NVIDIA NIM)

> Paste the whole block below into Claude Code / Cursor / Gemini / any coding agent.
> Sections marked `[EDIT]` are the only things you should change before sending.

---

## ROLE

You are a senior Flutter engineer specialising in desktop applications and clean
architecture. You write production-grade, null-safe Dart. You never take
shortcuts that would need rewriting later.

## OBJECTIVE

Build a **cross-platform desktop AI chat client** in Flutter that runs on
**Windows, Linux and macOS**. It is functionally similar to the Claude Desktop
and Gemini desktop apps: the user brings their own free **NVIDIA NIM API key**,
picks a model, chats with it, and all conversations are stored locally and can
be attached to a "Project" (a workspace with its own system prompt and files).

Mobile and web are explicitly **out of scope**.

## HARD CONSTRAINTS — non-negotiable

1. **Do not use `setState` anywhere.** Not once. All UI state flows through the
   state management layer. `StatefulWidget` is allowed only for
   `AnimationController`, `TextEditingController`, `ScrollController`,
   `FocusNode` lifecycle — never for business state.
2. **MVVM architecture.** Strict layering:
   `View (widgets)` → `ViewModel (state + commands)` → `Repository` →
   `Service / DataSource`. A View never touches a Repository or an HTTP client
   directly. A ViewModel never imports `package:flutter/material.dart`.
3. **State management:** `[EDIT: Riverpod 2.x (recommended) | BLoC | Provider]`.
   Use it for dependency injection as well — no service locators scattered
   around, no global singletons.
4. **Immutable state objects** (`freezed` or manual `copyWith`). No mutation of
   state in place.
5. **No secrets in source.** The API key is entered by the user at runtime and
   stored with `flutter_secure_storage`. Never logged, never printed.
6. Every async operation returns a typed result — `Result<T, AppFailure>` or a
   sealed class. No raw exceptions bubbling into the UI layer.

## TECH STACK

| Concern            | Choice |
|--------------------|--------|
| Framework          | Flutter stable, Dart 3.x, desktop targets only |
| State / DI         | `[EDIT: flutter_riverpod + riverpod_annotation]` |
| Models             | `freezed` + `json_serializable` |
| HTTP + streaming   | `dio` (SSE via `ResponseType.stream`) |
| Local database     | `[EDIT: drift (recommended) | isar | sqflite_common_ffi]` |
| Secure storage     | `flutter_secure_storage` |
| Routing            | `go_router` |
| Markdown rendering | `flutter_markdown` + `flutter_highlight` for code blocks |
| File/folder picker | `file_picker` |
| Window management  | `window_manager` (min size, title bar, remember bounds) |
| Logging            | `logger`, disabled in release |
| Testing            | `flutter_test`, `mocktail` |

## NVIDIA API INTEGRATION

The NVIDIA NIM endpoint is **OpenAI-compatible**.

- Base URL: `https://integrate.api.nvidia.com/v1`
- Auth header: `Authorization: Bearer <nvapi-...>`
- `GET /models` → populate the model dropdown **dynamically**. Do not hardcode a
  model list; cache the response locally and offer a manual refresh.
- `POST /chat/completions` with `"stream": true` → parse the
  `text/event-stream` response, emit each `delta.content` chunk so tokens appear
  in the UI as they arrive. Handle the `[DONE]` sentinel.
- Expose per-conversation settings: `temperature`, `top_p`, `max_tokens`,
  `system prompt`.
- Handle and surface clearly: 401 invalid key, 429 rate limit (with retry-after
  backoff), 5xx, network offline, and mid-stream disconnects. A cancelled or
  failed stream must leave the partial message in the DB, flagged as incomplete.
- Abstract the client behind an `LlmService` interface so a second provider
  (OpenAI, Ollama, OpenRouter) can be added later without touching ViewModels.

## FEATURES

### 1. Onboarding / Settings
- First-run screen to paste the NVIDIA API key, with a "Test connection" button.
- Settings page: change key, default model, default system prompt, theme
  (light/dark/system), font size, data folder location, "Delete all data".

### 2. Chat
- Streaming assistant responses with a visible stop/cancel button.
- Markdown rendering, syntax-highlighted code blocks with a copy button.
- Per-message actions: copy, regenerate, edit-and-resend, delete.
- Token/character count per conversation (approximate is fine).
- Auto-scroll that pauses when the user scrolls up.
- `Enter` sends, `Shift+Enter` newline.

### 3. History
- Left sidebar listing conversations, newest first, grouped by Today /
  Yesterday / Previous 7 days / Older.
- Auto-generate a conversation title from the first user message.
- Rename, pin, delete, and full-text search across all messages.
- Everything persisted locally in the database and restored on app launch.

### 4. Projects
- A Project has: name, description, custom system prompt, an optional linked
  local folder, and many conversations.
- Files added to a project (`.txt`, `.md`, `.dart`, `.json`, `.csv`, …) are read,
  chunked and prepended as context to requests within that project, with a
  configurable character budget so requests never blow past the context window.
- Show which files are currently in context, with per-file enable/disable.
- Conversations can be created inside a project or moved into one.

### 5. Desktop polish
- Remember window size and position between launches.
- Keyboard shortcuts: new chat, focus search, toggle sidebar, settings.
- Graceful shutdown: cancel in-flight streams, flush DB writes.

## PROJECT STRUCTURE

```
lib/
├── main.dart
├── app/                     # App widget, router, theme, DI bootstrap
├── core/
│   ├── constants/
│   ├── errors/              # AppFailure sealed classes, Result<T>
│   ├── network/             # dio client, interceptors, SSE parser
│   └── utils/
├── data/
│   ├── datasources/
│   │   ├── remote/          # nvidia_api_datasource.dart
│   │   └── local/           # database, secure storage, file reader
│   ├── models/              # DTOs (freezed, fromJson/toJson)
│   └── repositories/        # *RepositoryImpl
├── domain/
│   ├── entities/            # pure Dart, no json, no flutter
│   ├── repositories/        # abstract contracts
│   └── usecases/            # SendMessage, LoadHistory, IndexProjectFiles…
└── presentation/
    ├── chat/
    │   ├── view/            # chat_screen.dart, widgets/
    │   ├── viewmodel/       # chat_viewmodel.dart
    │   └── state/           # chat_state.dart (freezed)
    ├── history/
    ├── projects/
    ├── settings/
    └── shared/              # reusable widgets, theme extensions
```

Mirror this layout in `test/`.

## DELIVERY — work in ordered phases, stop after each for review

1. **Scaffold** — project setup, dependencies, folder structure, theme, router,
   window_manager config, DI wiring. Runnable empty shell.
2. **Domain + Data** — entities, DTOs, database schema, repository contracts and
   implementations, `LlmService` with model listing and non-streaming chat.
3. **Chat MVP** — chat view + ViewModel, streaming responses, markdown rendering.
4. **Persistence & History** — save/restore conversations, sidebar, search.
5. **Projects** — project CRUD, folder linking, file context injection.
6. **Settings, shortcuts, error states, empty states, loading skeletons.**
7. **Tests + build** — unit tests for ViewModels/repositories, widget tests for
   the chat view, and release build instructions for all three platforms.

## OUTPUT RULES

- Give me complete, compiling files with their full paths. No `// ...rest of
  code` placeholders.
- Start with the folder tree and `pubspec.yaml`, then the files for the current
  phase only.
- Add a short note on any assumption you had to make.
- Comment the *why*, not the *what*.
- Before moving to the next phase, list what is done and what remains.

## ACCEPTANCE CRITERIA

- [ ] `grep -r "setState" lib/` returns nothing.
- [ ] No ViewModel imports Flutter material/widgets.
- [ ] App builds and runs on Windows, Linux and macOS.
- [ ] Killing the app mid-conversation and reopening it restores full history.
- [ ] Invalid API key shows a readable message, not a stack trace.
- [ ] Streaming can be cancelled mid-response without corrupting state.
- [ ] `flutter analyze` is clean.

---

**Start with Phase 1 only.** Ask me any clarifying questions before you begin.
