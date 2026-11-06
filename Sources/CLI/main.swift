// monitor — turn an external display off/on from the terminal.
// Usage: monitor list | off [dell|acer|ID] [--force] | on | toggle

import CoreGraphics
import Foundation

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

func off(_ target: String?, force: Bool) {
    let pick: CGDirectDisplayID?
    if let t = target {
        pick = findActive(t)
    } else {
        // Default: an external display that isn't the main one, else any external.
        let active = activeDisplays()
        pick = active.first { CGDisplayIsBuiltin($0) == 0 && CGDisplayIsMain($0) == 0 }
            ?? active.first { CGDisplayIsBuiltin($0) == 0 }
    }
    guard let id = pick else { fail("No matching active display. Run `monitor list` to see names.") }
    do {
        let name = try turnOff(id, force: force)
        print("\(name) turned off. Run `monitor on` to bring it back.")
    } catch {
        fail("\(error)\(force ? "" : "\nRun with --force if you really mean it.")")
    }
}

func on() {
    do {
        let list = try turnOnAll()
        if list.isEmpty { fail("No turned-off display remembered. Unplug/replug the cable if needed.") }
        print("Turned back on: \(list.map(\.name).joined(separator: ", ")).")
    } catch { fail("\(error)") }
}

let args = Array(CommandLine.arguments.dropFirst())
let force = args.contains("--force")
switch args.first ?? "toggle" {
case "list":
    for id in activeDisplays() {
        let main = CGDisplayIsMain(id) != 0 ? ", main" : ""
        print("\(id)  \(friendlyName(id))  on\(main)  \(CGDisplayPixelsWide(id))x\(CGDisplayPixelsHigh(id))")
    }
    for s in savedDisplays() { print("\(s.id)  \(s.name)  off") }
case "off": off(args.dropFirst().first { $0 != "--force" }, force: force)
case "on": on()
case "toggle": savedDisplays().isEmpty ? off(nil, force: force) : on()
default: print("Usage: monitor [list | off [dell|acer|ID] [--force] | on | toggle]")
}
