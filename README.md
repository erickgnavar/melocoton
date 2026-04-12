# Melocoton

A keyboard-driven, multi-platform database client for SQLite, PostgreSQL, and MySQL.
Built with Elixir/Phoenix LiveView and packaged as a desktop app with Tauri.

## Features

- **Keyboard-native** — every action reachable from the keyboard, shortcut hints shown inline
- **SQL editor** — write and execute queries with results displayed in dense, scannable tables
- **Transaction support** — interactive transactions with explicit commit/rollback control
- **Table explorer** — browse schemas, tables, indexes, and column definitions
- **Multiple databases** — connect to several databases and switch between them quickly
- **Connection groups** — organize databases by project, environment, or team
- **AI assistant** — natural language to SQL with schema-aware chat, supporting Anthropic, OpenAI, OpenRouter, MiniMax,
  and local models via Ollama
- **Data export** — export query results to CSV or Excel
- **Cross-platform** — runs as a web app or a native desktop app (macOS, Linux)

## Requirements

- [mise](https://mise.jdx.dev/getting-started.html) — manages Elixir, Erlang, and Node.js versions
- [just](https://github.com/casey/just) — command runner for common tasks (see `justfile`)
- [Rust](https://rustup.rs/) — required only for desktop builds (Tauri)

## Development

```bash
# Install tool versions (Elixir, Node, etc.)
mise install

# Install dependencies and set up the database
just setup

# Start the dev server at localhost:4000
just dev
```

A `justfile` defines all common tasks. Run `just --list` to see available recipes:

```bash
just test                           # Run all tests
just ci                             # Full CI suite (format + deps + tests)
just fmt                            # Format code
just release                        # Full desktop app build
just tauri-dev                      # Tauri dev mode with hot reload
just db-migrate                     # Run pending migrations
just db-reset                       # Drop + create + migrate + seed
```

## Tech stack

| Layer     | Technology               |
|-----------|--------------------------|
| Backend   | Elixir, Phoenix LiveView |
| Frontend  | LiveView, Tailwind CSS   |
| Desktop   | Tauri (Rust)             |
| Databases | Postgrex, Exqlite, MyXQL |
| Packaging | Burrito                  |
