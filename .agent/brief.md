<!-- BRIEF: COMMIT=95621f01 HASH=37098b0a DATE=2026-11-02T14:40:43.426Z -->
# Project Brief: nectarlink
- **Commit**: `95621f01` | **Updated**: 2026-11-02T14:40:43.426Z | **Files Tracked**: 621

## Overview
**Your Android phone and your Mac, working seamlessly as one.**

## Tech Stack
- Rust (Cargo.toml)

## Project Map (Directory Tree)
```text
.
├── .agent/ (7 files)
│   └── history/ (1 file)
├── .cargo/ (1 file)
├── .github/ (9 files)
│   ├── ISSUE_TEMPLATE/ (3 files)
│   ├── scripts/ (1 file)
│   └── workflows/ (2 files)
├── LICENSES/ (5 files)
├── android/ (186 files)
│   ├── app/ (177 files)
│   └── gradle/ (3 files)
├── assets/ (16 files)
│   ├── brand/ (8 files)
│   └── fonts/ (8 files)
├── core/ (57 files)
│   ├── maclink-adb/ (2 files)
│   ├── maclink-cli/ (2 files)
│   ├── maclink-core/ (40 files)
│   ├── maclink-ffi/ (4 files)
│   └── maclink-protocol/ (9 files)
├── desktop/ (202 files)
│   ├── app/ (201 files)
│   └── packaging/ (1 file)
├── docs/ (118 files)
│   ├── adr/ (9 files)
│   ├── architecture/ (2 files)
│   ├── design/ (6 files)
│   ├── foundations/ (1 file)
│   ├── guide/ (52 files)
│   ├── protocol/ (19 files)
│   ├── research/ (1 file)
│   ├── screenshots/ (14 files)
│   └── technical/ (9 files)
├── scripts/ (2 files)
├── tools/ (4 files)
│   └── xtask/ (4 files)
├── .editorconfig
├── .gitattributes
├── .gitignore
├── AGENTS.md
├── CHANGELOG.md
├── Cargo.lock
├── Cargo.toml
├── LICENSE
├── README.md
├── SECURITY.md
├── TRADEMARKS.md
├── deny.toml
├── rust-toolchain.toml
└── rustfmt.toml
```

## Architecture Chart
```mermaid
graph TD
  App["Application Root"]
  Docs["Documentation (docs/)"]
  App -.-> Docs
```

## Likely Entry Points
- `core/maclink-cli/src/main.rs`
- `desktop/app/qml/App.qml`
- `desktop/app/src/bridge/app.rs`
- `desktop/app/src/main.rs`
- `docs/design/mockups/index.html`
- `docs/design/themes/index.html`
- `tools/xtask/src/main.rs`

## Key Commands
- No build/test scripts found

## Project Rules (AGENTS.md)
# Workspace Rules

## Build Rule
- **Only build the app when explicitly told by the user. If not mentioned, do not build the app.**
- Verification may use fast checks (like `cargo check` or linting), but do not run full packaging, release builds, or build scripts (`build-all.sh`, `macdeployqt`, etc.) unless the user explicitly requests a build.
