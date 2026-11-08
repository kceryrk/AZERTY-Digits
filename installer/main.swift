import Cocoa

let layoutName = "AZERTY-Digits.keylayout"
let installedDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Keyboard Layouts")
let installedURL = installedDir.appendingPathComponent(layoutName)
let menuBarDefaultsKey = "menuBarStyleIndex"
let underscoreDefaultsKey = "includeUnderscore"
let degreeDefaultsKey = "includeDegree"

// Rewrites key 24 and key 27 on the base (0), Caps-only (9) and Shift (1) layers.
func layoutText(from template: String, underscore: Bool, degree: Bool) -> String {
    var lines = template.components(separatedBy: "\n")
    let base27 = degree ? "°" : ")"
    let shift27 = degree ? ")" : "°"
    let plan: [(layer: String, out24: String?, out27: String)] = [
        ("0", underscore ? "_" : "-", base27),
        ("9", underscore ? "_" : "-", base27),
        ("1", nil, shift27),
    ]
    for (layer, out24, out27) in plan {
        guard let start = lines.firstIndex(where: { $0.contains("<keyMap index=\"\(layer)\">") }) else { continue }
        var i = start + 1
        while i < lines.count && !lines[i].contains("</keyMap>") {
            if let out24, lines[i].contains("<key code=\"24\" ") {
                lines[i] = setOutput(lines[i], out24)
            } else if lines[i].contains("<key code=\"27\" ") {
                lines[i] = setOutput(lines[i], out27)
            }
            i += 1
        }
    }
    return lines.joined(separator: "\n")
}

func setOutput(_ line: String, _ value: String) -> String {
    line.replacingOccurrences(of: "output=\"[^\"]*\"", with: "output=\"\(value)\"", options: .regularExpression)
}

struct MenuBarStyle {
    let title: String
    let file: String
}

let menuBarStyles = [
    MenuBarStyle(title: "FR", file: "fr"),
    MenuBarStyle(title: "123", file: "123"),
    MenuBarStyle(title: "FRPC", file: "frpc"),
    MenuBarStyle(title: "DG", file: "dg"),
]

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let iconPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let iconPreview = NSImageView()
    var toggleUnderscore: NSButton!
    var toggleDegree: NSButton!
    let underscoreHelp = NSTextField(wrappingLabelWithString:
        "Off: key 24 types - without Shift and _ with Shift.\nOn: key 24 types _ without Shift, and Shift still gives _.")
    let degreeHelp = NSTextField(wrappingLabelWithString:
        "Off: key 27 types ) without Shift and ° with Shift, so ( and ) end up on different Shift levels.\nOn: key 27 types ° without Shift and ) with Shift, so ( and ) share the Shift level.")

    var bundledLayout: URL? {
        Bundle.main.url(forResource: "AZERTY-Digits", withExtension: "keylayout")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        selectMenuBarStyle(index: UserDefaults.standard.integer(forKey: menuBarDefaultsKey))
        refreshStatus()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AZERTY Digits Installer"
        window.center()
        window.delegate = self

        let content = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = content

        let title = NSTextField(labelWithString: "AZERTY Digits")
        title.font = .boldSystemFont(ofSize: 20)

        let subtitle = NSTextField(wrappingLabelWithString:
            "Digits on the number row without Shift or Caps Lock. Option, Option+Shift and the rest of Apple's French layout are unchanged.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        iconPreview.imageScaling = .scaleProportionallyUpOrDown
        iconPreview.translatesAutoresizingMaskIntoConstraints = false

        iconPopup.addItems(withTitles: menuBarStyles.map { $0.title })
        iconPopup.target = self
        iconPopup.action = #selector(menuBarChanged)

        let iconRow = NSStackView(views: [NSTextField(labelWithString: "Menu bar icon:"), iconPopup])
        iconRow.spacing = 8

        let install = NSButton(title: "Install", target: self, action: #selector(installAction))
        let update = NSButton(title: "Update", target: self, action: #selector(updateAction))
        let uninstall = NSButton(title: "Uninstall", target: self, action: #selector(uninstallAction))
        let settings = NSButton(title: "Open Keyboard Settings", target: self, action: #selector(openSettings))
        install.bezelStyle = .rounded
        update.bezelStyle = .rounded
        uninstall.bezelStyle = .rounded
        settings.bezelStyle = .rounded
        install.keyEquivalent = "\r"

        let buttons = NSStackView(views: [install, update, uninstall])
        buttons.spacing = 10

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.preferredMaxLayoutWidth = 400

        let steps = NSTextField(wrappingLabelWithString:
            "After install or update: log out and back in, then add AZERTY Digits in System Settings > Keyboard > Input Sources (+ > Others). macOS doesn't let apps add input sources for you.")
        steps.font = .systemFont(ofSize: 11)
        steps.textColor = .secondaryLabelColor
        steps.preferredMaxLayoutWidth = 400

        UserDefaults.standard.register(defaults: [underscoreDefaultsKey: true, degreeDefaultsKey: true])
        toggleUnderscore = NSButton(checkboxWithTitle: "Include _ on the number row (key 24)", target: self, action: #selector(toggleChanged))
        toggleDegree = NSButton(checkboxWithTitle: "Include ° on the number row (key 27)", target: self, action: #selector(toggleChanged))
        toggleUnderscore.state = UserDefaults.standard.bool(forKey: underscoreDefaultsKey) ? .on : .off
        toggleDegree.state = UserDefaults.standard.bool(forKey: degreeDefaultsKey) ? .on : .off

        for help in [underscoreHelp, degreeHelp] {
            help.font = .systemFont(ofSize: 11)
            help.textColor = .secondaryLabelColor
            help.preferredMaxLayoutWidth = 400
        }

        let stack = NSStackView(views: [title, subtitle, iconPreview, iconRow, toggleUnderscore, underscoreHelp, toggleDegree, degreeHelp, buttons, settings, statusLabel, steps])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            iconPreview.widthAnchor.constraint(equalToConstant: 96),
            iconPreview.heightAnchor.constraint(equalToConstant: 96),
            subtitle.widthAnchor.constraint(equalToConstant: 400),
        ])

        window.makeKeyAndOrderFront(nil)
    }

    var selectedStyleURL: URL? {
        Bundle.main.url(forResource: menuBarStyles[iconPopup.indexOfSelectedItem].file, withExtension: "icns")
    }

    func selectMenuBarStyle(index: Int) {
        let safe = (0..<menuBarStyles.count).contains(index) ? index : 0
        iconPopup.selectItem(at: safe)
        UserDefaults.standard.set(safe, forKey: menuBarDefaultsKey)
        if let url = selectedStyleURL, let image = NSImage(contentsOf: url) {
            iconPreview.image = image
        }
    }

    @objc func toggleChanged() {
        UserDefaults.standard.set(toggleUnderscore.state == .on, forKey: underscoreDefaultsKey)
        UserDefaults.standard.set(toggleDegree.state == .on, forKey: degreeDefaultsKey)
        setStatus("Click Update to apply the new symbols.")
    }

    @objc func menuBarChanged() {
        selectMenuBarStyle(index: iconPopup.indexOfSelectedItem)
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func refreshStatus() {
        if FileManager.default.fileExists(atPath: installedURL.path) {
            setStatus("Installed at ~/Library/Keyboard Layouts.")
        } else {
            setStatus("Not installed.")
        }
    }

    @objc func installAction() {
        guard let source = bundledLayout else {
            setStatus("Layout file missing from the app bundle.")
            return
        }
        if FileManager.default.fileExists(atPath: installedURL.path) {
            setStatus("Already installed. Use Update to refresh it.")
            return
        }
        copyLayout(from: source, action: "Installed")
    }

    @objc func updateAction() {
        guard let source = bundledLayout else {
            setStatus("Layout file missing from the app bundle.")
            return
        }
        copyLayout(from: source, action: "Updated")
    }

    @objc func uninstallAction() {
        guard FileManager.default.fileExists(atPath: installedURL.path) else {
            setStatus("Nothing to remove.")
            return
        }
        do {
            try FileManager.default.removeItem(at: installedURL)
            let iconTarget = installedDir.appendingPathComponent("AZERTY-Digits.icns")
            if FileManager.default.fileExists(atPath: iconTarget.path) {
                try FileManager.default.removeItem(at: iconTarget)
            }
            setStatus("Removed. Also remove AZERTY Digits from Input Sources if it's still listed.")
        } catch {
            setStatus("Could not remove: \(error.localizedDescription)")
        }
    }

    func copyLayout(from source: URL, action: String) {
        do {
            try FileManager.default.createDirectory(at: installedDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: installedURL.path) {
                try FileManager.default.removeItem(at: installedURL)
            }
            let template = try String(contentsOf: source, encoding: .utf8)
            let text = layoutText(
                from: template,
                underscore: toggleUnderscore.state == .on,
                degree: toggleDegree.state == .on)
            try text.write(to: installedURL, atomically: true, encoding: .utf8)
            if let icon = selectedStyleURL {
                let iconTarget = installedDir.appendingPathComponent("AZERTY-Digits.icns")
                if FileManager.default.fileExists(atPath: iconTarget.path) {
                    try FileManager.default.removeItem(at: iconTarget)
                }
                try FileManager.default.copyItem(at: icon, to: iconTarget)
            }
            setStatus("\(action). Log out and back in, then add AZERTY Digits in Input Sources.")
        } catch {
            setStatus("Failed: \(error.localizedDescription)")
        }
    }

    @objc func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
