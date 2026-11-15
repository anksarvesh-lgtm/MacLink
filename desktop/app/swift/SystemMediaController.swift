// SPDX-License-Identifier: GPL-3.0-or-later
//
//  SystemMediaController.swift
//  MacLink Native System Media Controller (Apple Music & Spotify)
//  Reverse-engineered and adapted from boring.notch (TheBoredTeam/boring.notch)
//

import Cocoa
import Foundation

public final class SystemMediaController {
    public static let shared = SystemMediaController()

    public struct MediaState: Codable {
        public var hasTrack: Bool
        public var player: String
        public var title: String
        public var artist: String
        public var album: String
        public var isPlaying: Bool
        public var duration: Double
        public var position: Double
    }

    public var onMediaStateChange: ((MediaState) -> Void)?

    private var currentState = MediaState(
        hasTrack: false,
        player: "",
        title: "",
        artist: "",
        album: "",
        isPlaying: false,
        duration: 0,
        position: 0
    )

    private var lastActivePlayer: String = "com.apple.Music"

    private init() {
        setupObservers()
        refresh()
    }

    private func setupObservers() {
        let center = DistributedNotificationCenter.default()

        center.addObserver(
            self,
            selector: #selector(handleAppleMusicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )

        center.addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
    }

    @objc private func handleAppleMusicNotification(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        lastActivePlayer = "com.apple.Music"

        let state = info["Player State"] as? String ?? ""
        let isPlaying = (state == "Playing")
        let name = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        let album = info["Album"] as? String ?? ""
        let totalTimeMs = info["Total Time"] as? Double ?? 0.0
        let duration = totalTimeMs > 0 ? (totalTimeMs / 1000.0) : 0.0
        let position = info["Player Position"] as? Double ?? 0.0

        let hasTrack = !name.isEmpty
        currentState = MediaState(
            hasTrack: hasTrack,
            player: "Apple Music",
            title: name,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            duration: duration,
            position: position
        )

        DispatchQueue.main.async {
            self.onMediaStateChange?(self.currentState)
        }
    }

    @objc private func handleSpotifyNotification(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        lastActivePlayer = "com.spotify.client"

        let state = info["Player State"] as? String ?? ""
        let isPlaying = (state == "Playing")
        let name = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        let album = info["Album"] as? String ?? ""
        let durationMs = info["Duration"] as? Double ?? 0.0
        let duration = durationMs > 0 ? (durationMs / 1000.0) : 0.0
        let position = info["Playback Position"] as? Double ?? 0.0

        let hasTrack = !name.isEmpty
        currentState = MediaState(
            hasTrack: hasTrack,
            player: "Spotify",
            title: name,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            duration: duration,
            position: position
        )

        DispatchQueue.main.async {
            self.onMediaStateChange?(self.currentState)
        }
    }

    public func getCurrentState() -> MediaState {
        return currentState
    }

    public func refresh() {
        // Probe running music apps if state is empty
        if !currentState.hasTrack {
            let running = NSWorkspace.shared.runningApplications
            let musicRunning = running.contains(where: { $0.bundleIdentifier == "com.apple.Music" })
            let spotifyRunning = running.contains(where: { $0.bundleIdentifier == "com.spotify.client" })

            if musicRunning {
                queryAppleMusicViaScript()
            } else if spotifyRunning {
                querySpotifyViaScript()
            }
        }
    }

    private func queryAppleMusicViaScript() {
        let scriptText = """
        tell application "Music"
            if it is running then
                set pState to (player state as string)
                if pState is "playing" or pState is "paused" then
                    set cTrack to current track
                    set tName to name of cTrack
                    set tArtist to artist of cTrack
                    set tAlbum to album of cTrack
                    set tDuration to duration of cTrack
                    set tPos to player position
                    return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (tDuration as string) & "|||" & (tPos as string)
                end if
            end if
        end tell
        return ""
        """
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: scriptText),
               let result = script.executeAndReturnError(&error).stringValue,
               !result.isEmpty {
                let parts = result.components(separatedBy: "|||")
                if parts.count >= 6 {
                    let isPlaying = (parts[0].lowercased() == "playing")
                    let name = parts[1]
                    let artist = parts[2]
                    let album = parts[3]
                    let dur = Double(parts[4]) ?? 0.0
                    let pos = Double(parts[5]) ?? 0.0
                    DispatchQueue.main.async {
                        self.currentState = MediaState(
                            hasTrack: !name.isEmpty,
                            player: "Apple Music",
                            title: name,
                            artist: artist,
                            album: album,
                            isPlaying: isPlaying,
                            duration: dur,
                            position: pos
                        )
                        self.onMediaStateChange?(self.currentState)
                    }
                }
            }
        }
    }

    private func querySpotifyViaScript() {
        let scriptText = """
        tell application "Spotify"
            if it is running then
                set pState to (player state as string)
                if pState is "playing" or pState is "paused" then
                    set cTrack to current track
                    set tName to name of cTrack
                    set tArtist to artist of cTrack
                    set tAlbum to album of cTrack
                    set tDuration to (duration of cTrack) / 1000
                    set tPos to player position
                    return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (tDuration as string) & "|||" & (tPos as string)
                end if
            end if
        end tell
        return ""
        """
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: scriptText),
               let result = script.executeAndReturnError(&error).stringValue,
               !result.isEmpty {
                let parts = result.components(separatedBy: "|||")
                if parts.count >= 6 {
                    let isPlaying = (parts[0].lowercased() == "playing")
                    let name = parts[1]
                    let artist = parts[2]
                    let album = parts[3]
                    let dur = Double(parts[4]) ?? 0.0
                    let pos = Double(parts[5]) ?? 0.0
                    DispatchQueue.main.async {
                        self.currentState = MediaState(
                            hasTrack: !name.isEmpty,
                            player: "Spotify",
                            title: name,
                            artist: artist,
                            album: album,
                            isPlaying: isPlaying,
                            duration: dur,
                            position: pos
                        )
                        self.onMediaStateChange?(self.currentState)
                    }
                }
            }
        }
    }

    public func playPause() {
        let target = (currentState.player == "Spotify") ? "Spotify" : "Music"
        let script = "tell application \"\(target)\" to playpause"
        executeScript(script)
        currentState.isPlaying.toggle()
    }

    public func nextTrack() {
        let target = (currentState.player == "Spotify") ? "Spotify" : "Music"
        let script = "tell application \"\(target)\" to next track"
        executeScript(script)
    }

    public func previousTrack() {
        let target = (currentState.player == "Spotify") ? "Spotify" : "Music"
        let script = "tell application \"\(target)\" to previous track"
        executeScript(script)
    }

    private func executeScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                script.executeAndReturnError(&error)
            }
        }
    }
}
