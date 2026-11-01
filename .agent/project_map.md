# Project Map & Architecture: nectarlink
Generated on: 2026-11-01T11:24:12.800Z | Total Tracked Files: 669

## Architecture Flowchart
```mermaid
graph TD
  App["Application Root"]
  Docs["Documentation (docs/)"]
  App -.-> Docs
```

## Directory Structure Map
```text
.
├── .cargo/ (1 file)
├── .github/ (9 files)
│   ├── ISSUE_TEMPLATE/ (3 files)
│   ├── scripts/ (1 file)
│   └── workflows/ (2 files)
├── LICENSES/ (5 files)
├── android/ (184 files)
│   ├── app/ (175 files)
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
├── desktop/ (256 files)
│   ├── app/ (250 files)
│   ├── packaging/ (1 file)
│   └── vcam/ (5 files)
├── docs/ (117 files)
│   ├── adr/ (9 files)
│   ├── architecture/ (2 files)
│   ├── design/ (6 files)
│   ├── foundations/ (1 file)
│   ├── guide/ (52 files)
│   ├── protocol/ (19 files)
│   ├── research/ (1 file)
│   ├── screenshots/ (14 files)
│   └── technical/ (8 files)
├── scripts/ (7 files)
├── tools/ (4 files)
│   └── xtask/ (4 files)
├── .editorconfig
├── .gitattributes
├── .gitignore
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
