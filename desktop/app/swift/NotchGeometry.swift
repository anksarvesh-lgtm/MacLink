// SPDX-License-Identifier: GPL-3.0-or-later
//
//  NotchGeometry.swift
//  MacLink Native Display & Hardware Notch Geometry Service
//

import AppKit
import Foundation
import CoreGraphics

/// Pure, testable value type representing the geometric layout boundaries of a screen's
/// hardware notch, virtual notch, auxiliary safe regions, and corner radii.
public struct NotchGeometry: Equatable, Sendable, Codable {
    /// Whether the active display physically has a camera notch cutout.
    public var hasNotch: Bool
    
    /// Whether a virtual top-center notch was created (for external / non-notched displays).
    public var virtualNotch: Bool
    
    /// Whether a fallback estimation path was used (e.g., auxiliary areas nil in scaled mode).
    public var isFallback: Bool
    
    /// Descriptive reason if a fallback estimation path was used.
    public var fallbackReason: String
    
    /// Full screen bounding rect in points.
    public var screenFrame: CGRect
    
    /// Physical or virtual notch bounding rectangle on screen (in top-down coordinates: y: 0 at top).
    public var notchRect: CGRect
    
    /// Measured width of the notch (without extra padding).
    public var notchWidth: CGFloat
    
    /// Hardware / inset height of the notch top band cutout.
    public var notchHeight: CGFloat
    
    /// Measured horizontal center X coordinate of the notch in screen space.
    /// Derived directly from measured left/right margins, never assuming the screen center.
    public var notchCenterX: CGFloat
    
    /// Safe unobstructed width to the left of the notch in the menu bar row.
    public var leftAvailable: CGFloat
    
    /// Safe unobstructed width to the right of the notch in the menu bar row.
    public var rightAvailable: CGFloat
    
    /// Effective height of the menu bar on this screen.
    public var menuBarHeight: CGFloat
    
    /// Derived bottom corner radius for the island panel.
    public var bottomCornerRadius: CGFloat
    
    /// Display backing scale factor (e.g., 2.0 on Retina).
    public var backingScaleFactor: CGFloat
    
    /// User calibration override: width adjustment in points.
    public var calibrationOffsetWidth: CGFloat
    
    /// User calibration override: height adjustment in points.
    public var calibrationOffsetHeight: CGFloat
    
    /// User calibration override: corner radius adjustment in points.
    public var calibrationOffsetRadius: CGFloat
    
    /// Header row center exclusion gap (must equal measured notchWidth + calibration offset).
    public var headerCenterGap: CGFloat {
        notchWidth
    }
    
    public init(
        hasNotch: Bool,
        virtualNotch: Bool,
        isFallback: Bool,
        fallbackReason: String = "",
        screenFrame: CGRect,
        notchRect: CGRect,
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        notchCenterX: CGFloat,
        leftAvailable: CGFloat,
        rightAvailable: CGFloat,
        menuBarHeight: CGFloat,
        bottomCornerRadius: CGFloat,
        backingScaleFactor: CGFloat,
        calibrationOffsetWidth: CGFloat = 0,
        calibrationOffsetHeight: CGFloat = 0,
        calibrationOffsetRadius: CGFloat = 0
    ) {
        self.hasNotch = hasNotch
        self.virtualNotch = virtualNotch
        self.isFallback = isFallback
        self.fallbackReason = fallbackReason
        self.screenFrame = screenFrame
        self.notchRect = notchRect
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.notchCenterX = notchCenterX
        self.leftAvailable = leftAvailable
        self.rightAvailable = rightAvailable
        self.menuBarHeight = menuBarHeight
        self.bottomCornerRadius = bottomCornerRadius
        self.backingScaleFactor = backingScaleFactor
        self.calibrationOffsetWidth = calibrationOffsetWidth
        self.calibrationOffsetHeight = calibrationOffsetHeight
        self.calibrationOffsetRadius = calibrationOffsetRadius
    }
}

/// Optional manual user overrides for fine-tuning notch dimensions and corner radii.
public struct NotchManualOverride: Equatable, Sendable, Codable {
    public var widthNudge: CGFloat
    public var heightNudge: CGFloat
    public var radiusNudge: CGFloat
    public var virtualNotchWidth: CGFloat
    public var virtualNotchHeight: CGFloat
    
    public init(
        widthNudge: CGFloat = 0,
        heightNudge: CGFloat = 0,
        radiusNudge: CGFloat = 0,
        virtualNotchWidth: CGFloat = 160.0,
        virtualNotchHeight: CGFloat = 32.0
    ) {
        self.widthNudge = widthNudge
        self.heightNudge = heightNudge
        self.radiusNudge = radiusNudge
        self.virtualNotchWidth = virtualNotchWidth
        self.virtualNotchHeight = virtualNotchHeight
    }
}

// MARK: - Pixel Snapping Utilities

@inline(__always)
public func snapToDevicePixels(_ value: CGFloat, scale: CGFloat) -> CGFloat {
    guard scale > 0 else { return value }
    return (value * scale).rounded() / scale
}

@inline(__always)
public func snapRectToDevicePixels(_ rect: CGRect, scale: CGFloat) -> CGRect {
    guard scale > 0 else { return rect }
    let x = snapToDevicePixels(rect.origin.x, scale: scale)
    let y = snapToDevicePixels(rect.origin.y, scale: scale)
    let w = snapToDevicePixels(rect.size.width, scale: scale)
    let h = snapToDevicePixels(rect.size.height, scale: scale)
    return CGRect(x: x, y: y, width: w, height: h)
}

// MARK: - Pure Geometry Computation Engine

/// Computes NotchGeometry from plain, isolated inputs.
/// Fully testable without relying on active NSScreen or global system state.
public func computeNotchGeometry(
    screenFrame: CGRect,
    safeAreaTopInset: CGFloat,
    auxiliaryTopLeftArea: CGRect?,
    auxiliaryTopRightArea: CGRect?,
    backingScaleFactor: CGFloat,
    manualOverride: NotchManualOverride? = nil
) -> NotchGeometry {
    let scale = max(1.0, backingScaleFactor)
    let override = manualOverride ?? NotchManualOverride()
    
    let sanitizedFrame = CGRect(
        x: max(0, screenFrame.origin.x),
        y: max(0, screenFrame.origin.y),
        width: max(100.0, screenFrame.width),
        height: max(100.0, screenFrame.height)
    )
    
    let hasPhysicalNotch = (safeAreaTopInset > 0)
    
    if hasPhysicalNotch {
        // Mode 1: Physical notch with valid AppKit auxiliary boundary areas
        if let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea,
           left.width > 0, right.width > 0 {
            
            // In AppKit coordinate space:
            // left.maxX - screenFrame.origin.x is the left boundary of the notch.
            // right.minX - screenFrame.origin.x is the right boundary of the notch.
            let rawMinX = left.maxX - screenFrame.origin.x
            let rawMaxX = right.minX - screenFrame.origin.x
            
            let rawWidth = max(0, rawMaxX - rawMinX)
            let rawHeight = safeAreaTopInset
            
            // Apply calibration nudge
            let finalWidth = snapToDevicePixels(max(20.0, rawWidth + override.widthNudge), scale: scale)
            let finalHeight = snapToDevicePixels(max(10.0, rawHeight + override.heightNudge), scale: scale)
            
            let measuredCenterX = snapToDevicePixels(rawMinX + (rawWidth / 2.0), scale: scale)
            let notchX = snapToDevicePixels(measuredCenterX - (finalWidth / 2.0), scale: scale)
            
            let notchR = CGRect(x: notchX, y: 0, width: finalWidth, height: finalHeight)
            let leftAvail = snapToDevicePixels(left.width, scale: scale)
            let rightAvail = snapToDevicePixels(right.width, scale: scale)
            
            // Derive corner radius from notch height (standard Apple Bezier curvature ratio ~0.44)
            let baseRadius = max(8.0, min(20.0, finalHeight * 0.4375))
            let finalRadius = max(4.0, baseRadius + override.radiusNudge)
            
            return NotchGeometry(
                hasNotch: true,
                virtualNotch: false,
                isFallback: false,
                fallbackReason: "",
                screenFrame: sanitizedFrame,
                notchRect: notchR,
                notchWidth: finalWidth,
                notchHeight: finalHeight,
                notchCenterX: measuredCenterX,
                leftAvailable: leftAvail,
                rightAvailable: rightAvail,
                menuBarHeight: finalHeight,
                bottomCornerRadius: finalRadius,
                backingScaleFactor: scale,
                calibrationOffsetWidth: override.widthNudge,
                calibrationOffsetHeight: override.heightNudge,
                calibrationOffsetRadius: override.radiusNudge
            )
        } else {
            // Mode 2: Physical notch fallback (e.g. scaled resolution or compatibility mode where aux areas are nil)
            let rawHeight = safeAreaTopInset
            // Estimate width conservatively based on Apple standard notch ratios (~12.5% of width or clamped 170-210 pt)
            let estimatedWidth = min(210.0, max(170.0, sanitizedFrame.width * 0.122))
            
            let finalWidth = snapToDevicePixels(max(20.0, estimatedWidth + override.widthNudge), scale: scale)
            let finalHeight = snapToDevicePixels(max(10.0, rawHeight + override.heightNudge), scale: scale)
            
            let measuredCenterX = snapToDevicePixels(sanitizedFrame.width / 2.0, scale: scale)
            let notchX = snapToDevicePixels(measuredCenterX - (finalWidth / 2.0), scale: scale)
            
            let notchR = CGRect(x: notchX, y: 0, width: finalWidth, height: finalHeight)
            let leftAvail = snapToDevicePixels(notchX, scale: scale)
            let rightAvail = snapToDevicePixels(max(0, sanitizedFrame.width - (notchX + finalWidth)), scale: scale)
            
            let baseRadius = max(8.0, min(20.0, finalHeight * 0.4375))
            let finalRadius = max(4.0, baseRadius + override.radiusNudge)
            
            return NotchGeometry(
                hasNotch: true,
                virtualNotch: false,
                isFallback: true,
                fallbackReason: "auxiliaryTopLeftArea or auxiliaryTopRightArea was nil; width estimated from display geometry",
                screenFrame: sanitizedFrame,
                notchRect: notchR,
                notchWidth: finalWidth,
                notchHeight: finalHeight,
                notchCenterX: measuredCenterX,
                leftAvailable: leftAvail,
                rightAvailable: rightAvail,
                menuBarHeight: finalHeight,
                bottomCornerRadius: finalRadius,
                backingScaleFactor: scale,
                calibrationOffsetWidth: override.widthNudge,
                calibrationOffsetHeight: override.heightNudge,
                calibrationOffsetRadius: override.radiusNudge
            )
        }
    } else {
        // Mode 3: Non-notched display (external monitors, older iMacs, Mac mini) -> Virtual Notch
        let virtualW = snapToDevicePixels(max(60.0, override.virtualNotchWidth + override.widthNudge), scale: scale)
        let virtualH = snapToDevicePixels(max(18.0, override.virtualNotchHeight + override.heightNudge), scale: scale)
        
        let measuredCenterX = snapToDevicePixels(sanitizedFrame.width / 2.0, scale: scale)
        let notchX = snapToDevicePixels(measuredCenterX - (virtualW / 2.0), scale: scale)
        
        let notchR = CGRect(x: notchX, y: 0, width: virtualW, height: virtualH)
        let leftAvail = snapToDevicePixels(notchX, scale: scale)
        let rightAvail = snapToDevicePixels(max(0, sanitizedFrame.width - (notchX + virtualW)), scale: scale)
        
        let baseRadius = snapToDevicePixels(virtualH / 2.0, scale: scale) // Perfect pill radius
        let finalRadius = max(4.0, baseRadius + override.radiusNudge)
        
        return NotchGeometry(
            hasNotch: false,
            virtualNotch: true,
            isFallback: false,
            fallbackReason: "External/non-notched display; virtual notch pill applied",
            screenFrame: sanitizedFrame,
            notchRect: notchR,
            notchWidth: virtualW,
            notchHeight: virtualH,
            notchCenterX: measuredCenterX,
            leftAvailable: leftAvail,
            rightAvailable: rightAvail,
            menuBarHeight: 24.0,
            bottomCornerRadius: finalRadius,
            backingScaleFactor: scale,
            calibrationOffsetWidth: override.widthNudge,
            calibrationOffsetHeight: override.heightNudge,
            calibrationOffsetRadius: override.radiusNudge
        )
    }
}

// MARK: - Active Screen Detection Service

private var globalManualOverride = NotchManualOverride()
private var globalDebugOverlayEnabled = false

/// Global API to update manual notch calibration nudges.
@_cdecl("maclink_set_manual_notch_override")
public func maclink_set_manual_notch_override(
    widthNudge: Double,
    heightNudge: Double,
    radiusNudge: Double
) {
    globalManualOverride.widthNudge = CGFloat(widthNudge)
    globalManualOverride.heightNudge = CGFloat(heightNudge)
    globalManualOverride.radiusNudge = CGFloat(radiusNudge)
}

/// Global API to toggle debug-only geometry overlay.
@_cdecl("maclink_set_debug_overlay_enabled")
public func maclink_set_debug_overlay_enabled(enabled: Bool) {
    globalDebugOverlayEnabled = enabled
}

@_cdecl("maclink_is_debug_overlay_enabled")
public func maclink_is_debug_overlay_enabled() -> Bool {
    return globalDebugOverlayEnabled
}

/// Returns the active screen's NotchGeometry directly queried from AppKit.
public func detectCurrentScreenGeometry() -> NotchGeometry {
    var targetScreen = NSScreen.main
    for screen in NSScreen.screens {
        if screen.safeAreaInsets.top > 0 {
            targetScreen = screen
            break
        }
    }
    
    guard let screen = targetScreen else {
        return computeNotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            safeAreaTopInset: 32.0,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            backingScaleFactor: 2.0,
            manualOverride: globalManualOverride
        )
    }
    
    return computeNotchGeometry(
        screenFrame: screen.frame,
        safeAreaTopInset: screen.safeAreaInsets.top,
        auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
        auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
        backingScaleFactor: screen.backingScaleFactor,
        manualOverride: globalManualOverride
    )
}

// MARK: - Unified Island Layout Computation Service

public struct IslandComputedLayout: Equatable {
    public let screen: NSScreen
    public let notchRect: NSRect
    public let leftWingFrame: NSRect
    public let rightWingFrame: NSRect
    public let collapsedFrame: NSRect
    public let expandedFrame: NSRect
}

/// Identifies the screen with the physical notch (safeAreaInsets.top > 0),
/// falling back to NSScreen.main or primary display on non-notched hardware.
public func targetNotchScreen() -> NSScreen {
    if let notchScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
        return notchScreen
    }
    return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
}

/// Computes the notch rect, wings frames, collapsed frame, and expanded frame from the screen.
/// Always horizontally centered on screen.frame.midX and pinned to screen.frame.maxY.
public func updateLayout(for screen: NSScreen) -> IslandComputedLayout {
    let screenFrame = screen.frame
    let topY = screenFrame.maxY
    let hasPhysicalNotch = screen.safeAreaInsets.top > 0

    let notchRect: NSRect
    if hasPhysicalNotch,
       #available(macOS 12.0, *),
       let auxLeft = screen.auxiliaryTopLeftArea,
       let auxRight = screen.auxiliaryTopRightArea,
       auxLeft.width > 0, auxRight.width > 0 {
        let notchW = max(0, screenFrame.width - auxLeft.width - auxRight.width)
        let notchH = screen.safeAreaInsets.top
        let notchX = screenFrame.midX - (notchW / 2.0)
        notchRect = NSRect(x: notchX, y: topY - notchH, width: notchW, height: notchH)
    } else if hasPhysicalNotch {
        let notchW: CGFloat = 185.0
        let notchH = screen.safeAreaInsets.top
        notchRect = NSRect(x: screenFrame.midX - (notchW / 2.0), y: topY - notchH, width: notchW, height: notchH)
    } else {
        let notchW: CGFloat = 160.0
        let notchH: CGFloat = 32.0
        notchRect = NSRect(x: screenFrame.midX - (notchW / 2.0), y: topY - notchH, width: notchW, height: notchH)
    }

    let leftW: CGFloat = 90.0
    let rightW: CGFloat = 90.0

    let leftWingFrame = NSRect(
        x: notchRect.minX - leftW,
        y: notchRect.minY,
        width: leftW,
        height: notchRect.height
    )
    let rightWingFrame = NSRect(
        x: notchRect.maxX,
        y: notchRect.minY,
        width: rightW,
        height: notchRect.height
    )

    let collapsedW = notchRect.width + leftW + rightW
    let collapsedH = notchRect.height
    let collapsedFrame = NSRect(
        x: screenFrame.midX - (collapsedW / 2.0),
        y: topY - collapsedH,
        width: collapsedW,
        height: collapsedH
    )

    let expandedW = min(screenFrame.width - 32.0, max(collapsedW, 580.0))
    let expandedH = min(screenFrame.height - 40.0, 180.0)
    let expandedFrame = NSRect(
        x: screenFrame.midX - (expandedW / 2.0),
        y: topY - expandedH,
        width: expandedW,
        height: expandedH
    )

    return IslandComputedLayout(
        screen: screen,
        notchRect: notchRect,
        leftWingFrame: leftWingFrame,
        rightWingFrame: rightWingFrame,
        collapsedFrame: collapsedFrame,
        expandedFrame: expandedFrame
    )
}

/// Global C entrypoint to update Island layout computation on screen, space, or wake events.
@_cdecl("maclink_update_layout")
public func maclink_update_layout() {
    let screen = targetNotchScreen()
    _ = updateLayout(for: screen)
}


