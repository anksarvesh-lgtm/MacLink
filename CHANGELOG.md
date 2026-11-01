# Changelog

All notable changes to MacLink are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.1] - 2026-11-01

### Added - Initial Beta Release

#### Connectivity & Resilience
- **Persistent Local Auto-Connect:** Mac and Android automatically connect on application startup and whenever both devices are present on the same local Wi-Fi network.
- **Unbreakable Keep-Alive:** Multi-try heartbeat resilience with 15-second fault tolerance prevents premature disconnects during Android radio power-saving modes.
- **Android Background Reliability:** High-performance `WifiLock` and partial wake lock ensure background reachability without connection interruptions.
- **Fast LAN Discovery:** mDNS and UDP discovery broadcast peer LAN addresses directly into connection endpoints for sub-second handshake resolution.
- **Strict Local Privacy:** Pure local LAN and USB P2P communication; cellular stay-connected disabled to safeguard mobile data and maintain zero cloud dependency.
- **Alphanumeric Pairing:** Short alphanumeric SAS pairing verification codes for simple and unambiguous authentication.

#### Desktop & Android Experience
- **Liquid Glass & System Theme Adaptation:** Modern translucent UI that organically inherits native macOS and system wallpaper themes.
- **Smart Connect App Play:** Run and control Android apps inside independent desktop windows with keyboard and mouse input.
- **Screen & Display Mirroring:** Low-latency H.264/H.265 display streaming with interactive touch, scroll, and gesture support.
- **Bidirectional Clipboard Sync:** Seamless real-time clipboard sharing for text and copied images with automatic exclusion of password manager secrets.
- **High-Speed File & Folder Sharing:** Direct encrypted peer-to-peer transfers with folder preservation, pause/resume, and offline send queuing.
- **Notification Mirroring:** Live synchronized phone notifications on your desktop with inline action execution and monochrome status icons.
- **Calls & SMS:** View incoming calls, dial phone contacts, and read and reply to text messages from your Mac.
- **Phone as Speaker & Microphone:** Stream Mac audio directly to your phone speakers or use your Android phone as a wireless desktop microphone.
- **Automatic GitHub Updates:** Built-in update check on application startup with automated platform-specific artifact delivery (.dmg, .pkg, .apk, .exe, .AppImage).
