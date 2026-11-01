// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick
import app.nectarlink

// The active theme: Bloom (Material You, seed presets, the default), Hive
// (honey on charcoal or wax), Glass, or Graphite (paper and slate), light
// or dark, resolved from Preferences and the system. Colors
// come from Tokens (generated from docs/design/tokens.json); Material's
// "onX" roles are named "xContent" because QML reserves the "on" prefix.
QtObject {
    id: theme

    readonly property bool hive: false
    readonly property bool graphite: false
    readonly property bool glass: true
    readonly property bool dark: AppController.systemDark
    readonly property bool amoled: false
    readonly property bool reduceMotion: AppController.reduceMotion

    // ---- Hive's comb ----
    readonly property var comb: Tokens.data.themes.hive.comb
    // Breathes and pulses: the user's setting, never with reduced motion or
    // battery saver (it holds still then).
    readonly property bool combMotion: hive && Preferences.combMotion && !reduceMotion && !AppController.powerSaver
    readonly property color combLine: Qt.rgba(primary.r, primary.g, primary.b,
                                              dark ? comb.lineAlphaDark : comb.lineAlphaLight)
    readonly property color combGlow: dark ? Qt.rgba(1.0, 0.62, 0.18, comb.glowAlphaDark)
                                           : Qt.rgba(1.0, 0.72, 0.37, comb.glowAlphaLight)
    // One clock for every comb in the app (seconds), so two combs never draw
    // twice as often. The main window runs it while it's in front.
    property real combTime: 0
    property bool combClockRunning: false
    // A comb is on screen outside Hive (the invitation to try it).
    property bool combPreviewShown: false
    property double _combSince: 0
    property real _combBase: 0
    readonly property Timer _combClock: Timer {
        interval: theme.comb.frameMs
        repeat: true
        running: theme.combClockRunning
                 && (theme.combMotion || (theme.combPreviewShown && !theme.reduceMotion && !AppController.powerSaver))
        onRunningChanged: {
            if (running)
                theme._combSince = Date.now()
            else
                theme._combBase = theme.combTime
        }
        onTriggered: theme.combTime = theme._combBase + (Date.now() - theme._combSince) / 1000
    }

    readonly property var bloomSeeds: Tokens.data.themes.bloom.seeds
    // Colors made from the desktop wallpaper (or null until they're known),
    // in the shape of a preset seed.
    readonly property var wallpaperSeed: AppController.wallpaperColors !== ""
        ? JSON.parse(AppController.wallpaperColors) : null
    // Material You color scheme extracted from the currently playing media artwork.
    readonly property var artworkSeed: {
        if (MediaList.activeColors === "")
            return null
        try {
            return JSON.parse(MediaList.activeColors)
        } catch (e) {
            return null
        }
    }
    readonly property string artworkUrl: MediaList.activeArt
    readonly property bool isArtworkSeed: false
    readonly property bool artworkAmbientActive: false
    readonly property bool ambientBlurActive: glass
    // Material You color schemes from paired phones (`[{ id, key, name, label, hasAccent, scheme }]`).
    readonly property var phoneSeeds: AppController.phoneColors !== ""
        ? JSON.parse(AppController.phoneColors) : []
    readonly property bool isPhoneSeed: false
    readonly property var activePhoneSeed: null
    function phonePalette(deviceId) {
        for (let i = 0; i < phoneSeeds.length; i++) {
            const p = phoneSeeds[i]
            if ((deviceId === "" || p.id === deviceId) && p.scheme)
                return p.scheme[dark ? "dark" : "light"]
        }
        return null
    }
    // "artwork", "wallpaper", "phone" / "phone:<id>", or a preset name; dynamic
    // seeds fall back to wallpaper or the default preset until their colors are known.
    readonly property string seed: wallpaperSeed ? "wallpaper" : Tokens.data.themes.bloom.defaultSeed
    readonly property var seedColors: wallpaperSeed ? wallpaperSeed : bloomSeeds[Tokens.data.themes.bloom.defaultSeed]
    readonly property var palette: hive
        ? Tokens.data.themes.hive.variants[dark ? "comb" : "wax"]
        : (graphite
            ? Tokens.data.themes.graphite.variants[dark ? "slate" : "paper"]
            : seedColors[dark ? "dark" : "light"])
    readonly property var status: graphite || hive ? palette : Tokens.data.themes.bloom.status[dark ? "dark" : "light"]

    // ---- Color roles ----
    readonly property color primary: palette.primary
    readonly property color primaryContent: palette.onPrimary
    readonly property color primaryContainer: palette.primaryContainer
    readonly property color primaryContainerContent: palette.onPrimaryContainer
    readonly property color secondaryContainer: palette.secondaryContainer
    readonly property color secondaryContainerContent: palette.onSecondaryContainer
    readonly property color surface: amoled ? "#000000" : palette.surface
    readonly property color surfaceLow: amoled ? "#050507" : palette.surfaceContainerLow
    readonly property color surfaceContainerLow: amoled ? "#050507" : palette.surfaceContainerLow
    readonly property color surfaceContainer: amoled ? "#0A0B0E" : palette.surfaceContainer
    readonly property color surfaceContainerHigh: amoled ? "#121318" : palette.surfaceContainerHigh
    readonly property color surfaceContainerHighest: amoled ? "#1A1C23" : palette.surfaceContainerHighest
    readonly property color surfaceContent: palette.onSurface
    readonly property color surfaceContentVariant: palette.onSurfaceVariant
    readonly property color outline: palette.outline
    readonly property color outlineVariant: amoled ? "#22242C" : palette.outlineVariant
    // Success never gets its own (green) color: it uses the theme's ink.
    readonly property color success: primary
    readonly property color warning: status.warning
    readonly property color error: status.error
    readonly property color errorContent: status.onError
    // A quiet error surface (the "sharing your screen" pill): the error hue
    // over the surface, with the surface's own ink so text stays readable.
    readonly property color errorContainer: Qt.tint(surfaceContainerHigh, Qt.rgba(error.r, error.g, error.b, dark ? 0.22 : 0.14))
    readonly property color errorContainerContent: surfaceContent

    // ---- Component colors (Liquid Glass UI) ----
    readonly property color cardColor: Qt.tint(
        Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, dark ? 0.38 : 0.52),
        Qt.rgba(primary.r, primary.g, primary.b, dark ? 0.08 : 0.06)
    )
    readonly property color cardBorder: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.30)
    readonly property color tileColor: Qt.tint(
        Qt.rgba(1, 1, 1, dark ? 0.08 : 0.48),
        Qt.rgba(primary.r, primary.g, primary.b, dark ? 0.08 : 0.06)
    )
    readonly property color heroColor: Qt.tint(
        Qt.rgba(surface.r, surface.g, surface.b, dark ? 0.36 : 0.50),
        Qt.rgba(primaryContainer.r, primaryContainer.g, primaryContainer.b, dark ? 0.30 : 0.38)
    )
    readonly property color heroContent: primaryContainerContent
    readonly property color railColor: Qt.rgba(surfaceLow.r, surfaceLow.g, surfaceLow.b, dark ? 0.28 : 0.42)
    readonly property color indicator: secondaryContainer
    readonly property color indicatorContent: secondaryContainerContent
    readonly property color glow: Qt.rgba(primary.r, primary.g, primary.b, dark ? 0.30 : 0.22)
    readonly property color buttonShadow: "transparent"
    readonly property color scrim: Qt.rgba(0, 0, 0, dark ? 0.5 : 0.32)

    // ---- Shape ----
    readonly property var shape: graphite ? Tokens.data.themes.graphite.shape
        : (hive ? Tokens.data.themes.hive.shape : Tokens.data.themes.bloom.shape)
    readonly property int radiusXs: shape.xs
    readonly property int radiusSm: shape.sm
    readonly property int radiusMd: shape.md
    readonly property int radiusLg: shape.lg
    readonly property int radiusXl: shape.xl
    // "Pill": half the height of whatever uses it, in Bloom.
    function pill(height) { return graphite ? shape.full : height / 2 }

    // ---- Type ----
    // Bundled with the app (assets/fonts).
    readonly property string fontUi: "Figtree"
    readonly property string fontDisplay: graphite ? "Instrument Serif" : "Figtree"
    readonly property string fontMono: "Space Mono"
    readonly property var typography: Tokens.data.typography
    readonly property var labelStyle: graphite ? Tokens.data.themes.graphite.label
        : (hive ? Tokens.data.themes.hive.label : Tokens.data.themes.bloom.label)

    // ---- Layout and spacing ----
    readonly property var layout: Tokens.data.layout.desktop
    readonly property int railWidth: layout.railWidth
    readonly property int topBarHeight: layout.topBarHeight
    readonly property int contentPadding: layout.contentPadding
    readonly property int gutter: layout.gutter
    function space(step) { return Tokens.data.spacing.scale[step] }

    // Focus rings show for keyboard focus only, not after a click (TapHandler
    // doesn't take activeFocus on click; activeFocus on a control comes from Tab).
    function focusVisible(item) {
        return item !== null && item !== undefined && item.activeFocus
            && (item.focusReason === undefined
                || item.focusReason === Qt.TabFocusReason
                || item.focusReason === Qt.BacktabFocusReason)
    }

    // ---- Motion ----
    // QML springs take a strength and a damping ratio; these are tuned to
    // match the token springs (gentle / standard / snappy).
    readonly property real springGentle: 2.4
    readonly property real dampingGentle: 0.36
    readonly property real springStandard: 3.6
    readonly property real dampingStandard: 0.32
    readonly property real springSnappy: 5.6
    readonly property real dampingSnappy: 0.34
    readonly property int fadeFast: Tokens.data.motion.fade.fast
    readonly property int fadeNormal: Tokens.data.motion.fade.normal
    readonly property real hoverLift: reduceMotion ? 0 : Tokens.data.motion.hoverLift
    readonly property real pressScale: reduceMotion ? 1 : Tokens.data.motion.pressScale
}
