# Project Rules & Constraints

## Rule 1: Never Change the UI of MacLink
- The MacLink user interface, navigation rail, page structure, views, visual tokens, and user experience must **NEVER** be modified, replaced, or redesigned.
- All existing MacLink navigation items, pages, styling, phone companion workflows, and screens remain exactly as designed in the original application.

## Rule 2: Everything Modified Must Be an Add-On
- Any and all new features, services, or modifications (e.g., MacBook notch integration, dynamic island extensions, live telemetry wings, HUD sneak-peek) must be implemented strictly as **add-ons** / modular extensions.
- Add-ons must be purely additive, non-destructive, and cleanly isolated.
- All add-on features must be toggleable and have zero adverse impact on existing MacLink features.

## Rule 3: Use REA for Every Repo Link Provided
- Whenever a repository link or target binary/package is provided, always utilize REA (Reverse Engineer Anything) to inspect, reverse-engineer, decompile, extract assets, and trace architecture/semantics thoroughly.

## Rule 4: Write All Code in macOS-Supported Swift
- Where new code, services, extensions, or modular add-ons are written, prioritize macOS-supported native Swift (using AppKit, SwiftUI, Combine, CoreGraphics, and Apple platform frameworks).
- All implementations must be strictly compatible with macOS and follow native Apple guidelines.

## Rule 5: Only Modify and Build MacLink (Single-App Target)
- All modifications, new features, and code changes are done **strictly and solely inside the `MacLink` repository and application**.
- All external repositories (such as `dynamo-mac`, `liquid-glass-react`, or any other reference repositories) serve **exclusively as references** for code, architecture, designs, feature logic, and tool code to be integrated directly into MacLink.
- Under no circumstances should separate apps (such as `LiquidDynamo.app`) be built, run, installed, or distributed.
- Any build, package, or install commands (`build`, `install`, `cargo build`, packaging scripts, etc.) must target and operate **exclusively on MacLink** (`/Applications/MacLink.app`).

