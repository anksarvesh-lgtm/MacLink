// SPDX-License-Identifier: GPL-3.0-or-later
//
//  NotchGeometryTests.swift
//  Unit Tests for NotchGeometry calculation engine across real-world screen fixtures
//

import Foundation
import CoreGraphics

func assertEqual(_ a: CGFloat, _ b: CGFloat, accuracy: CGFloat = 0.5, _ message: String, file: String = #file, line: Int = #line) {
    if abs(a - b) > accuracy {
        fatalError("Assertion failed: \(a) != \(b) (diff: \(abs(a - b))) - \(message) at \(file):\(line)")
    }
}

func assertTrue(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        fatalError("Assertion failed: \(message) at \(file):\(line)")
    }
}

func runAllTests() {
    print("----------------------------------------------------------------------")
    print("RUNNING NOTCH GEOMETRY TEST SUITE")
    print("----------------------------------------------------------------------")
    
    // ------------------------------------------------------------------------
    // FIXTURE 1: 14-inch MacBook Pro (Default Retina 2x scale: 1512 × 982 pt)
    // ------------------------------------------------------------------------
    print("[TEST 1] 14-inch MacBook Pro Class (1512x982 @ 2x)...")
    let mbp14Frame = CGRect(x: 0, y: 0, width: 1512.0, height: 982.0)
    let mbp14TopInset: CGFloat = 34.0
    // Hardware notch on 14" MBP is ~204 pt wide, centered at 756.0 pt
    let mbp14AuxLeft = CGRect(x: 0, y: 948.0, width: 654.0, height: 34.0)
    let mbp14AuxRight = CGRect(x: 858.0, y: 948.0, width: 654.0, height: 34.0)
    
    let g1 = computeNotchGeometry(
        screenFrame: mbp14Frame,
        safeAreaTopInset: mbp14TopInset,
        auxiliaryTopLeftArea: mbp14AuxLeft,
        auxiliaryTopRightArea: mbp14AuxRight,
        backingScaleFactor: 2.0
    )
    assertTrue(g1.hasNotch, "Must detect physical notch")
    assertTrue(!g1.virtualNotch, "Must not be virtual notch")
    assertTrue(!g1.isFallback, "Must be exact AppKit derivation, not fallback")
    assertEqual(g1.notchWidth, 204.0, "14-inch MBP notch width must be 204 pt")
    assertEqual(g1.notchHeight, 34.0, "14-inch MBP notch height must be 34 pt")
    assertEqual(g1.notchCenterX, 756.0, "14-inch MBP notch center must be 756 pt")
    assertEqual(g1.notchRect.minX, 654.0, "14-inch MBP notch minX must be 654 pt")
    assertEqual(g1.headerCenterGap, 204.0, "Header center gap must exactly equal measured notch width")
    print("  ✓ Passed: width=\(g1.notchWidth)pt, height=\(g1.notchHeight)pt, center=\(g1.notchCenterX)pt, gap=\(g1.headerCenterGap)pt")
    
    // ------------------------------------------------------------------------
    // FIXTURE 2: 16-inch MacBook Pro (Default Retina 2x scale: 1728 × 1117 pt)
    // ------------------------------------------------------------------------
    print("[TEST 2] 16-inch MacBook Pro Class (1728x1117 @ 2x)...")
    let mbp16Frame = CGRect(x: 0, y: 0, width: 1728.0, height: 1117.0)
    let mbp16TopInset: CGFloat = 34.0
    // Hardware notch is 204 pt wide, centered at 864.0 pt
    let mbp16AuxLeft = CGRect(x: 0, y: 1083.0, width: 762.0, height: 34.0)
    let mbp16AuxRight = CGRect(x: 966.0, y: 1083.0, width: 762.0, height: 34.0)
    
    let g2 = computeNotchGeometry(
        screenFrame: mbp16Frame,
        safeAreaTopInset: mbp16TopInset,
        auxiliaryTopLeftArea: mbp16AuxLeft,
        auxiliaryTopRightArea: mbp16AuxRight,
        backingScaleFactor: 2.0
    )
    assertTrue(g2.hasNotch, "Must detect physical notch")
    assertEqual(g2.notchWidth, 204.0, "16-inch MBP notch width must be 204 pt")
    assertEqual(g2.notchHeight, 34.0, "16-inch MBP notch height must be 34 pt")
    assertEqual(g2.notchCenterX, 864.0, "16-inch MBP notch center must be 864 pt")
    assertEqual(g2.headerCenterGap, 204.0, "Header center gap must equal notch width")
    print("  ✓ Passed: width=\(g2.notchWidth)pt, height=\(g2.notchHeight)pt, center=\(g2.notchCenterX)pt")
    
    // ------------------------------------------------------------------------
    // FIXTURE 3: 13-inch MacBook Air (Scaled resolution: 1470 × 956 pt)
    // ------------------------------------------------------------------------
    print("[TEST 3] 13-inch MacBook Air Scaled Resolution (1470x956 @ 2x)...")
    let mba13Frame = CGRect(x: 0, y: 0, width: 1470.0, height: 956.0)
    let mba13TopInset: CGFloat = 32.0
    let mba13AuxLeft = CGRect(x: 0, y: 924.0, width: 645.5, height: 32.0)
    let mba13AuxRight = CGRect(x: 824.5, y: 924.0, width: 645.5, height: 32.0)
    
    let g3 = computeNotchGeometry(
        screenFrame: mba13Frame,
        safeAreaTopInset: mba13TopInset,
        auxiliaryTopLeftArea: mba13AuxLeft,
        auxiliaryTopRightArea: mba13AuxRight,
        backingScaleFactor: 2.0
    )
    assertTrue(g3.hasNotch, "Must detect physical notch")
    assertEqual(g3.notchWidth, 179.0, "13-inch MBA notch width must be 179 pt")
    assertEqual(g3.notchHeight, 32.0, "13-inch MBA notch height must be 32 pt")
    assertEqual(g3.notchCenterX, 735.0, "13-inch MBA notch center must be 735 pt")
    assertEqual(g3.leftAvailable, 645.5, "Left available must match auxLeft width")
    assertEqual(g3.rightAvailable, 645.5, "Right available must match auxRight width")
    print("  ✓ Passed: width=\(g3.notchWidth)pt, height=\(g3.notchHeight)pt, center=\(g3.notchCenterX)pt")
    
    // ------------------------------------------------------------------------
    // FIXTURE 4: 15-inch MacBook Air (Default resolution: 1710 × 1107 pt)
    // ------------------------------------------------------------------------
    print("[TEST 4] 15-inch MacBook Air Class (1710x1107 @ 2x)...")
    let mba15Frame = CGRect(x: 0, y: 0, width: 1710.0, height: 1107.0)
    let mba15TopInset: CGFloat = 32.0
    let mba15AuxLeft = CGRect(x: 0, y: 1075.0, width: 765.5, height: 32.0)
    let mba15AuxRight = CGRect(x: 944.5, y: 1075.0, width: 765.5, height: 32.0)
    
    let g4 = computeNotchGeometry(
        screenFrame: mba15Frame,
        safeAreaTopInset: mba15TopInset,
        auxiliaryTopLeftArea: mba15AuxLeft,
        auxiliaryTopRightArea: mba15AuxRight,
        backingScaleFactor: 2.0
    )
    assertTrue(g4.hasNotch, "Must detect physical notch")
    assertEqual(g4.notchWidth, 179.0, "15-inch MBA notch width must be 179 pt")
    assertEqual(g4.notchHeight, 32.0, "15-inch MBA notch height must be 32 pt")
    assertEqual(g4.notchCenterX, 855.0, "15-inch MBA notch center must be 855 pt")
    print("  ✓ Passed: width=\(g4.notchWidth)pt, height=\(g4.notchHeight)pt, center=\(g4.notchCenterX)pt")
    
    // ------------------------------------------------------------------------
    // FIXTURE 5: External 4K Display / Non-Notched Screen (3840 × 2160 pt)
    // ------------------------------------------------------------------------
    print("[TEST 5] External 4K Non-Notched Screen (3840x2160 @ 2x)...")
    let ext4kFrame = CGRect(x: 0, y: 0, width: 3840.0, height: 2160.0)
    let ext4kTopInset: CGFloat = 0.0 // No notch inset
    
    let g5 = computeNotchGeometry(
        screenFrame: ext4kFrame,
        safeAreaTopInset: ext4kTopInset,
        auxiliaryTopLeftArea: nil,
        auxiliaryTopRightArea: nil,
        backingScaleFactor: 2.0
    )
    assertTrue(!g5.hasNotch, "External screen must not report physical notch")
    assertTrue(g5.virtualNotch, "External screen must receive a virtual notch")
    assertEqual(g5.notchWidth, 160.0, "Default virtual notch width must be 160 pt")
    assertEqual(g5.notchHeight, 32.0, "Default virtual notch height must be 32 pt")
    assertEqual(g5.notchCenterX, 1920.0, "Virtual notch center must align with screen center (1920 pt)")
    assertEqual(g5.bottomCornerRadius, 16.0, "Virtual notch pill corner radius must equal height / 2 (16 pt)")
    print("  ✓ Passed: virtualNotch=true, width=\(g5.notchWidth)pt, height=\(g5.notchHeight)pt, center=\(g5.notchCenterX)pt")
    
    // ------------------------------------------------------------------------
    // FIXTURE 6: Nil Auxiliary Areas with Nonzero Inset (Fallback Path)
    // ------------------------------------------------------------------------
    print("[TEST 6] Fallback Path: Nil Auxiliary Areas with Nonzero Inset...")
    let fallbackFrame = CGRect(x: 0, y: 0, width: 1470.0, height: 956.0)
    let fallbackTopInset: CGFloat = 32.0
    
    let g6 = computeNotchGeometry(
        screenFrame: fallbackFrame,
        safeAreaTopInset: fallbackTopInset,
        auxiliaryTopLeftArea: nil, // Nil aux area simulates compatibility/scaled mode
        auxiliaryTopRightArea: nil,
        backingScaleFactor: 2.0
    )
    assertTrue(g6.hasNotch, "Must still report hasNotch = true from safeAreaTopInset")
    assertTrue(g6.isFallback, "Must flag isFallback = true")
    assertTrue(g6.fallbackReason.count > 0, "Must provide detailed fallback reason")
    assertTrue(g6.notchWidth >= 170.0 && g6.notchWidth <= 210.0, "Fallback width must be conservative within 170-210 pt")
    assertEqual(g6.notchHeight, 32.0, "Fallback height must match safeAreaTopInset")
    print("  ✓ Passed: isFallback=true, reason='\(g6.fallbackReason)', width=\(g6.notchWidth)pt")
    
    // ------------------------------------------------------------------------
    // FIXTURE 7: Manual Calibration Overrides (Nudge width, height, corner radius)
    // ------------------------------------------------------------------------
    print("[TEST 7] Manual Calibration Overrides...")
    let override = NotchManualOverride(widthNudge: 6.0, heightNudge: -2.0, radiusNudge: 3.0)
    let g7 = computeNotchGeometry(
        screenFrame: mba13Frame,
        safeAreaTopInset: mba13TopInset,
        auxiliaryTopLeftArea: mba13AuxLeft,
        auxiliaryTopRightArea: mba13AuxRight,
        backingScaleFactor: 2.0,
        manualOverride: override
    )
    assertEqual(g7.notchWidth, 185.0, "Notch width must reflect +6.0 pt nudge")
    assertEqual(g7.notchHeight, 30.0, "Notch height must reflect -2.0 pt nudge")
    assertEqual(g7.calibrationOffsetWidth, 6.0, "Must record width calibration offset")
    assertEqual(g7.calibrationOffsetHeight, -2.0, "Must record height calibration offset")
    print("  ✓ Passed: nudgedWidth=\(g7.notchWidth)pt, nudgedHeight=\(g7.notchHeight)pt")
    
    // ------------------------------------------------------------------------
    // FIXTURE 8: Odd / Zero / Negative Inputs Robustness
    // ------------------------------------------------------------------------
    print("[TEST 8] Zero / Negative Robustness...")
    let zeroFrame = CGRect(x: -10, y: -20, width: 0, height: 0)
    let g8 = computeNotchGeometry(
        screenFrame: zeroFrame,
        safeAreaTopInset: -5.0,
        auxiliaryTopLeftArea: nil,
        auxiliaryTopRightArea: nil,
        backingScaleFactor: -1.0
    )
    assertTrue(g8.screenFrame.width >= 100, "Must clamp frame width safely")
    assertTrue(g8.screenFrame.height >= 100, "Must clamp frame height safely")
    assertTrue(!g8.hasNotch, "Negative inset must not produce notch")
    assertTrue(g8.virtualNotch, "Must safely degrade to virtual notch")
    print("  ✓ Passed: safe clamping on invalid inputs")
    
    print("----------------------------------------------------------------------")
    print("ALL 8 NOTCH GEOMETRY UNIT TESTS PASSED SUCCESSFULLY!")
    print("----------------------------------------------------------------------")
}

@main
struct TestApp {
    static func main() {
        runAllTests()
    }
}
