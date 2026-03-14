import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        // Check for initial file from CLI
        if let path = UserDefaults.standard.string(forKey: "initialFilePath") {
            UserDefaults.standard.removeObject(forKey: "initialFilePath")
            appState.openFile(URL(fileURLWithPath: path))
            showWindow()
        } else {
            showFileOpenDialog()
        }
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About mdview", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit mdview", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open...", action: #selector(openFile(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        // Theme submenu
        let themeMenuItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: "Theme")
        themeMenu.delegate = self

        let lightItem = NSMenuItem(title: "Light", action: #selector(setThemeLight), keyEquivalent: "")
        lightItem.target = self
        lightItem.tag = 0
        themeMenu.addItem(lightItem)

        let darkItem = NSMenuItem(title: "Dark", action: #selector(setThemeDark), keyEquivalent: "")
        darkItem.target = self
        darkItem.tag = 1
        themeMenu.addItem(darkItem)

        let autoItem = NSMenuItem(title: "Auto (System)", action: #selector(setThemeAuto), keyEquivalent: "")
        autoItem.target = self
        autoItem.tag = 2
        themeMenu.addItem(autoItem)

        themeMenuItem.submenu = themeMenu
        viewMenu.addItem(themeMenuItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc func openFile(_ sender: Any?) {
        showFileOpenDialog()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // We handle this manually
    }

    func showWindow() {
        let contentView = ContentView()
            .environmentObject(appState)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window?.center()
        window?.setFrameAutosaveName("MarkdownViewer")
        window?.contentView = NSHostingView(rootView: contentView)
        window?.makeKeyAndOrderFront(nil)
        window?.delegate = self

        updateWindowTitle()
    }

    func updateWindowTitle() {
        if let url = appState.currentFile {
            window?.title = url.lastPathComponent
        } else {
            window?.title = "mdview"
        }
    }

    func showFileOpenDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select a Markdown file to preview"

        let response = panel.runModal()

        if response == .OK, let url = panel.url {
            appState.openFile(url)
            showWindow()
        } else {
            NSApp.terminate(nil)
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        appState.closeFile()

        // Return to file open dialog after a brief delay
        DispatchQueue.main.async { [weak self] in
            self?.window = nil
            self?.showFileOpenDialog()
        }
    }
}

// Menu commands for theme switching
extension AppDelegate {
    @objc func setThemeLight() {
        ThemeManager.shared.setTheme(.light)
        appState.triggerRefresh()
    }

    @objc func setThemeDark() {
        ThemeManager.shared.setTheme(.dark)
        appState.triggerRefresh()
    }

    @objc func setThemeAuto() {
        ThemeManager.shared.setTheme(.auto)
        appState.triggerRefresh()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "Theme" else { return }

        let currentTheme = ThemeManager.shared.currentTheme
        for item in menu.items {
            switch item.tag {
            case 0: item.state = currentTheme == .light ? .on : .off
            case 1: item.state = currentTheme == .dark ? .on : .off
            case 2: item.state = currentTheme == .auto ? .on : .off
            default: break
            }
        }
    }
}
