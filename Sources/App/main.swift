// DumbMonitors — menu-bar app: click a monitor to turn it off or on.

import AppKit
import CoreGraphics
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Monitors")
        image?.isTemplate = true
        statusItem.button?.image = image
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    // Rebuild the menu each time it opens so it always reflects the current screens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let active = activeDisplays()
        let lastOne = active.count < 2

        for id in active {
            let item = NSMenuItem(title: friendlyName(id), action: #selector(toggle(_:)), keyEquivalent: "")
            item.target = self
            item.state = .on
            item.tag = Int(id)
            if lastOne {
                item.isEnabled = false
                item.toolTip = "Your only active screen can't be turned off."
            }
            menu.addItem(item)
        }
        for s in savedDisplays() {
            let item = NSMenuItem(title: s.name, action: #selector(toggle(_:)), keyEquivalent: "")
            item.target = self
            item.state = .off
            item.tag = Int(s.id)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(NSMenuItem(title: "Quit DumbMonitors", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func toggle(_ sender: NSMenuItem) {
        let id = CGDirectDisplayID(sender.tag)
        do {
            if sender.state == .on { try turnOff(id) } else { try turnOn(id) }
        } catch {
            showError("\(error)")
        }
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError("Couldn't change Open at Login: \(error.localizedDescription)\n\nMove DumbMonitors.app to Applications and try again, or add it in System Settings → General → Login Items.")
        }
    }

    private func showError(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "DumbMonitors"
        alert.informativeText = text
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
