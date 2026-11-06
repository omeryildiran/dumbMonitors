// Shared display on/off logic used by both the `monitor` CLI and DumbMonitors.app.
// Uses the private CoreGraphics call CGSConfigureDisplayEnabled (same as paid tools).

import AppKit
import CoreGraphics
import Foundation

struct MonitorError: Error, CustomStringConvertible {
    let description: String
    init(_ d: String) { description = d }
}

/// Displays we turned off, one per line: "<id>\t<name>". Shared by CLI and app.
let stateFile = (NSHomeDirectory() as NSString).appendingPathComponent(".monitor-disabled-id")

private typealias ConfigureEnabledFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

private let configureEnabled: ConfigureEnabledFn? = {
    let paths = ["/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
                 "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"]
    for p in paths {
        guard let h = dlopen(p, RTLD_NOW) else { continue }
        for name in ["CGSConfigureDisplayEnabled", "SLSConfigureDisplayEnabled"] {
            if let sym = dlsym(h, name) { return unsafeBitCast(sym, to: ConfigureEnabledFn.self) }
        }
    }
    return nil
}()

// MARK: - Listing

func activeDisplays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    return Array(ids.prefix(Int(count)))
}

/// EDID vendor codes → brand, so "acer" matches a display that calls itself "XV271U M3".
private let brands: [UInt32: String] = [
    0x0472: "Acer", 0x10AC: "Dell", 0x4C2D: "Samsung", 0x1E6D: "LG", 0x0469: "Asus",
    0x4D10: "Sharp", 0x22F0: "HP", 0x30AE: "Lenovo", 0x05E3: "AOC", 0x34AC: "MSI",
    0x38A3: "NEC", 0x4DD9: "Sony", 0x5A63: "ViewSonic", 0x09D1: "BenQ", 0x0610: "Apple",
]

func brand(_ id: CGDirectDisplayID) -> String? { brands[CGDisplayVendorNumber(id)] }

func displayName(_ id: CGDirectDisplayID) -> String {
    for s in NSScreen.screens {
        if let n = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           n.uint32Value == id { return s.localizedName }
    }
    return "Display \(id)"
}

/// Name plus brand when the name doesn't already include it, e.g. "XV271U M3 (Acer)".
func friendlyName(_ id: CGDirectDisplayID) -> String {
    let n = displayName(id)
    if let b = brand(id), !n.lowercased().contains(b.lowercased()) { return "\(n) (\(b))" }
    return n
}

/// Find an active display by ID, part of its name, or brand.
func findActive(_ query: String) -> CGDirectDisplayID? {
    let q = query.lowercased()
    return activeDisplays().first {
        String($0) == q || displayName($0).lowercased().contains(q) || brand($0)?.lowercased() == q
    }
}

// MARK: - Remembered (turned-off) displays

struct SavedDisplay { let id: CGDirectDisplayID; let name: String }

/// Displays we turned off that are still off. Entries that came back (e.g. replugged) are dropped.
func savedDisplays() -> [SavedDisplay] {
    guard let s = try? String(contentsOfFile: stateFile, encoding: .utf8) else { return [] }
    let active = Set(activeDisplays())
    let all = s.split(whereSeparator: \.isNewline).compactMap { line -> SavedDisplay? in
        let parts = line.split(separator: "\t", maxSplits: 1)
        guard let id = parts.first.flatMap({ CGDirectDisplayID($0) }) else { return nil }
        return SavedDisplay(id: id, name: parts.count > 1 ? String(parts[1]) : "Display \(id)")
    }
    let stillOff = all.filter { !active.contains($0.id) }
    if stillOff.count != all.count { writeSaved(stillOff) }
    return stillOff
}

private func writeSaved(_ list: [SavedDisplay]) {
    if list.isEmpty { try? FileManager.default.removeItem(atPath: stateFile); return }
    let text = list.map { "\($0.id)\t\($0.name)" }.joined(separator: "\n")
    try? text.write(toFile: stateFile, atomically: true, encoding: .utf8)
}

// MARK: - Switching

private func setEnabled(_ id: CGDirectDisplayID, _ on: Bool) throws {
    guard let fn = configureEnabled else {
        throw MonitorError("This macOS version doesn't expose the display on/off function.")
    }
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success else {
        throw MonitorError("Could not begin display configuration.")
    }
    let err = fn(config, id, on)
    guard err == .success else {
        CGCancelDisplayConfiguration(config)
        throw MonitorError("Failed to turn display \(id) \(on ? "on" : "off") (error \(err.rawValue)).")
    }
    guard CGCompleteDisplayConfiguration(config, .permanently) == .success else {
        throw MonitorError("Could not apply display configuration.")
    }
}

/// Turn a display off. Refuses to turn off the last active screen unless `force`.
@discardableResult
func turnOff(_ id: CGDirectDisplayID, force: Bool = false) throws -> String {
    if activeDisplays().count < 2 && !force {
        throw MonitorError("That is your only active screen. Turning it off would leave you with no picture.")
    }
    let name = friendlyName(id)
    var saved = savedDisplays().filter { $0.id != id }
    saved.append(SavedDisplay(id: id, name: name))
    writeSaved(saved)
    do { try setEnabled(id, false) } catch {
        writeSaved(saved.filter { $0.id != id })
        throw error
    }
    return name
}

func turnOn(_ id: CGDirectDisplayID) throws {
    try setEnabled(id, true)
    writeSaved(savedDisplays().filter { $0.id != id })
}

/// Turn every remembered display back on. Returns the ones turned on.
func turnOnAll() throws -> [SavedDisplay] {
    let saved = savedDisplays()
    for s in saved { try turnOn(s.id) }
    return saved
}
