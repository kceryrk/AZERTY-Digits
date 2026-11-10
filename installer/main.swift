import Cocoa

let layoutName = "AZERTY-Digits.keylayout"
let installedDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Keyboard Layouts")
let installedURL = installedDir.appendingPathComponent(layoutName)
let menuBarDefaultsKey = "menuBarStyleIndex"
let underscoreDefaultsKey = "includeUnderscore"
let degreeDefaultsKey = "includeDegree"
let installedVersionDefaultsKey = "installedLayoutVersion"
let kofiURLString = "https://ko-fi.com/kaecr"
let githubReleasesURLString = "https://api.github.com/repos/kceryrk/AZERTY-Digits/releases"

// MARK: - Semantic Versioning

struct SemanticVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    let raw: String

    init(_ string: String) {
        self.raw = string
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let parts = cleaned.split(separator: ".").compactMap { Int($0) }
        self.major = parts.indices.contains(0) ? parts[0] : 0
        self.minor = parts.indices.contains(1) ? parts[1] : 0
        self.patch = parts.indices.contains(2) ? parts[2] : 0
    }

    var description: String { "v\(major).\(minor).\(patch)" }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}

// MARK: - GitHub Release Model

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let publishedAt: String?
    let draft: Bool
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case draft
        case prerelease
    }
}

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

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let updateBanner = NSTextField(wrappingLabelWithString: "Checking for updates...")
    let iconPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let iconPreview = NSImageView()
    var toggleUnderscore: NSButton!
    var toggleDegree: NSButton!
    var checkUpdatesButton: NSButton!
    var viewNotesButton: NSButton!

    var cachedReleases: [GitHubRelease] = []
    var isCheckingUpdates = false

    let underscoreHelp = NSTextField(wrappingLabelWithString:
        "Off: key 24 types - without Shift and _ with Shift.\nOn: key 24 types _ without Shift, and Shift still gives _.")
    let degreeHelp = NSTextField(wrappingLabelWithString:
        "Off: key 27 types ) without Shift and ° with Shift, so ( and ) end up on different Shift levels.\nOn: key 27 types ° without Shift and ) with Shift, so ( and ) share the Shift level.")

    var bundledLayout: URL? {
        Bundle.main.url(forResource: "AZERTY-Digits", withExtension: "keylayout")
    }

    func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func getInstalledVersion() -> String? {
        if let stored = UserDefaults.standard.string(forKey: installedVersionDefaultsKey), !stored.isEmpty {
            return stored
        }
        guard FileManager.default.fileExists(atPath: installedURL.path) else {
            return nil
        }
        if let content = try? String(contentsOf: installedURL, encoding: .utf8) {
            let pattern = #"<!--\s*version="([^"]+)"\s*-->"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                let v = String(content[range])
                UserDefaults.standard.set(v, forKey: installedVersionDefaultsKey)
                return v
            }
        }
        // Fallback: If installed file exists but has no version tag, assume 1.0.0
        return "1.0.0"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        selectMenuBarStyle(index: UserDefaults.standard.integer(forKey: menuBarDefaultsKey))
        refreshStatus()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Automatic update check in background
        checkForUpdates(silent: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 660),
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
        install.bezelStyle = .rounded
        update.bezelStyle = .rounded
        uninstall.bezelStyle = .rounded
        install.keyEquivalent = "\r"

        let buttons = NSStackView(views: [install, update, uninstall])
        buttons.spacing = 10

        let settings = NSButton(title: "Open Keyboard Settings", target: self, action: #selector(openSettings))
        settings.bezelStyle = .rounded

        checkUpdatesButton = NSButton(title: "Check for Updates", target: self, action: #selector(checkUpdatesAction))
        checkUpdatesButton.bezelStyle = .rounded

        let supportButton = NSButton(title: "☕ Support on Ko-fi", target: self, action: #selector(supportAction))
        supportButton.bezelStyle = .rounded

        let extraButtons = NSStackView(views: [settings, checkUpdatesButton, supportButton])
        extraButtons.spacing = 8

        viewNotesButton = NSButton(title: "Release Notes", target: self, action: #selector(viewNotesAction))
        viewNotesButton.bezelStyle = .inline
        viewNotesButton.isHidden = true

        updateBanner.font = .systemFont(ofSize: 11)
        updateBanner.textColor = .secondaryLabelColor

        let updateRow = NSStackView(views: [updateBanner, viewNotesButton])
        updateRow.spacing = 8
        updateRow.alignment = .centerY

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.preferredMaxLayoutWidth = 430

        let steps = NSTextField(wrappingLabelWithString:
            "After install or update: log out and back in, then add AZERTY Digits in System Settings > Keyboard > Input Sources (+ > Others). macOS doesn't let apps add input sources for you.")
        steps.font = .systemFont(ofSize: 11)
        steps.textColor = .secondaryLabelColor
        steps.preferredMaxLayoutWidth = 430

        UserDefaults.standard.register(defaults: [underscoreDefaultsKey: true, degreeDefaultsKey: true])
        toggleUnderscore = NSButton(checkboxWithTitle: "Include _ on the number row (key 24)", target: self, action: #selector(toggleChanged))
        toggleDegree = NSButton(checkboxWithTitle: "Include ° on the number row (key 27)", target: self, action: #selector(toggleChanged))
        toggleUnderscore.state = UserDefaults.standard.bool(forKey: underscoreDefaultsKey) ? .on : .off
        toggleDegree.state = UserDefaults.standard.bool(forKey: degreeDefaultsKey) ? .on : .off

        for help in [underscoreHelp, degreeHelp] {
            help.font = .systemFont(ofSize: 11)
            help.textColor = .secondaryLabelColor
            help.preferredMaxLayoutWidth = 430
        }

        let stack = NSStackView(views: [
            title, subtitle,
            iconPreview, iconRow,
            toggleUnderscore, underscoreHelp,
            toggleDegree, degreeHelp,
            buttons,
            extraButtons,
            updateRow,
            statusLabel,
            steps
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 24, bottom: 18, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            iconPreview.widthAnchor.constraint(equalToConstant: 80),
            iconPreview.heightAnchor.constraint(equalToConstant: 80),
            subtitle.widthAnchor.constraint(equalToConstant: 430),
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
            let ver = getInstalledVersion() ?? getAppVersion()
            setStatus("Installed (v\(ver)) at ~/Library/Keyboard Layouts.")
        } else {
            setStatus("Not installed.")
        }
    }

    // MARK: - Actions

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
            UserDefaults.standard.removeObject(forKey: installedVersionDefaultsKey)
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
            let ver = getAppVersion()
            UserDefaults.standard.set(ver, forKey: installedVersionDefaultsKey)
            setStatus("\(action) v\(ver). Log out and back in, then add AZERTY Digits in Input Sources.")
        } catch {
            setStatus("Failed: \(error.localizedDescription)")
        }
    }

    @objc func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Support Me (Ko-fi)

    @objc func supportAction() {
        let alert = NSAlert()
        alert.messageText = "Support AZERTY Digits ❤️"
        alert.informativeText = "AZERTY Digits is free and open-source.\n\nIf it makes typing easier and saves you time every day, consider supporting its development on Ko-fi!"
        alert.addButton(withTitle: "☕ Support on Ko-fi")
        alert.addButton(withTitle: "Maybe Later")
        alert.alertStyle = .informational

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                if let url = URL(string: kofiURLString) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - GitHub Releases & Update Checking

    @objc func checkUpdatesAction() {
        checkForUpdates(silent: false)
    }

    @objc func viewNotesAction() {
        guard !cachedReleases.isEmpty else { return }
        showReleaseNotesSheet(releases: cachedReleases)
    }

    func checkForUpdates(silent: Bool) {
        guard !isCheckingUpdates else { return }
        isCheckingUpdates = true
        if !silent {
            checkUpdatesButton.isEnabled = false
            updateBanner.stringValue = "Checking for updates..."
        }

        guard let url = URL(string: githubReleasesURLString) else {
            isCheckingUpdates = false
            return
        }

        var req = URLRequest(url: url)
        req.setValue("AZERTY-Digits-Installer", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCheckingUpdates = false
                self.checkUpdatesButton.isEnabled = true

                guard let data = data, error == nil else {
                    if !silent {
                        self.updateBanner.stringValue = "Failed to check for updates."
                    }
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode([GitHubRelease].self, from: data)
                    let validReleases = decoded
                        .filter { !$0.draft && !$0.prerelease }
                        .sorted { SemanticVersion($0.tagName) > SemanticVersion($1.tagName) }

                    self.cachedReleases = validReleases

                    guard let latest = validReleases.first else {
                        self.updateBanner.stringValue = "No releases found on GitHub."
                        return
                    }

                    let installed = self.getInstalledVersion() ?? self.getAppVersion()
                    let installedSem = SemanticVersion(installed)
                    let latestSem = SemanticVersion(latest.tagName)

                    if latestSem > installedSem {
                        self.updateBanner.stringValue = "✨ New release available: \(latest.tagName)"
                        self.viewNotesButton.isHidden = false
                        if !silent {
                            self.showReleaseNotesSheet(releases: validReleases)
                        }
                    } else {
                        self.updateBanner.stringValue = "✓ Up to date (\(latest.tagName))"
                        self.viewNotesButton.isHidden = false
                        if !silent {
                            self.showReleaseNotesSheet(releases: validReleases)
                        }
                    }
                } catch {
                    if !silent {
                        self.updateBanner.stringValue = "Could not parse GitHub release data."
                    }
                }
            }
        }.resume()
    }

    // MARK: - Release Notes Sheet Modal

    func showReleaseNotesSheet(releases: [GitHubRelease]) {
        let installed = getInstalledVersion() ?? getAppVersion()
        let installedSem = SemanticVersion(installed)

        // Show releases from installed version up to latest, with newest on top.
        // If installed is not set or not in list, show all releases.
        var targetReleases = releases.filter { SemanticVersion($0.tagName) >= installedSem }
        if targetReleases.isEmpty {
            targetReleases = releases
        }

        let sheetRect = NSRect(x: 0, y: 0, width: 520, height: 480)
        let sheet = NSWindow(contentRect: sheetRect, styleMask: [.titled], backing: .buffered, defer: false)

        let content = NSView(frame: sheetRect)
        sheet.contentView = content

        let header = NSTextField(labelWithString: "Release Notes")
        header.font = .boldSystemFont(ofSize: 18)

        let subtitleText: String
        let latestSem = releases.first.map { SemanticVersion($0.tagName) } ?? installedSem
        if latestSem > installedSem {
            subtitleText = "Showing updates from your installed version (\(installed)) to latest (\(releases.first?.tagName ?? "")):"
        } else {
            subtitleText = "You are on the latest version (\(installed)). Release history:"
        }
        let subtitle = NSTextField(wrappingLabelWithString: subtitleText)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textStorage?.setAttributedString(buildReleaseNotesAttributedString(releases: targetReleases, installed: installed))
        scrollView.documentView = textView

        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeSheetAction(_:)))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"

        var bottomViews: [NSView] = []
        if latestSem > installedSem, let latestRelease = releases.first {
            let downloadButton = NSButton(title: "Download \(latestRelease.tagName)", target: self, action: #selector(downloadLatestAction(_:)))
            downloadButton.bezelStyle = .rounded
            bottomViews.append(downloadButton)
        }
        bottomViews.append(closeButton)

        let buttonStack = NSStackView(views: bottomViews)
        buttonStack.spacing = 10
        buttonStack.alignment = .centerY

        let mainStack = NSStackView(views: [header, subtitle, scrollView, buttonStack])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: content.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scrollView.widthAnchor.constraint(equalToConstant: 480),
            scrollView.heightAnchor.constraint(equalToConstant: 330),
            buttonStack.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor, constant: -20),
        ])

        window.beginSheet(sheet, completionHandler: nil)
    }

    @objc func closeSheetAction(_ sender: NSButton) {
        if let sheet = sender.window {
            window.endSheet(sheet)
        }
    }

    @objc func downloadLatestAction(_ sender: NSButton) {
        if let latest = cachedReleases.first, let url = URL(string: latest.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
        if let sheet = sender.window {
            window.endSheet(sheet)
        }
    }

    func buildReleaseNotesAttributedString(releases: [GitHubRelease], installed: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let isoFormatter = ISO8601DateFormatter()

        let tagAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 15),
            .foregroundColor: NSColor.labelColor
        ]
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let badgeInstalledAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.systemBlue
        ]
        let badgeNewAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.systemGreen
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]

        let installedSem = SemanticVersion(installed)

        for (i, rel) in releases.enumerated() {
            if i > 0 {
                result.append(NSAttributedString(string: "\n\n──────────────────────────────────────────────────\n\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor.separatorColor
                ]))
            }

            let relSem = SemanticVersion(rel.tagName)
            let heading = rel.name?.isEmpty == false ? "\(rel.tagName) - \(rel.name!)" : rel.tagName
            result.append(NSAttributedString(string: heading, attributes: tagAttrs))

            if let dateStr = rel.publishedAt, let date = isoFormatter.date(from: dateStr) {
                result.append(NSAttributedString(string: "  •  \(dateFormatter.string(from: date))", attributes: dateAttrs))
            }

            if relSem == installedSem {
                result.append(NSAttributedString(string: "  [Current Version]", attributes: badgeInstalledAttrs))
            } else if relSem > installedSem {
                result.append(NSAttributedString(string: "  [New Update]", attributes: badgeNewAttrs))
            }

            result.append(NSAttributedString(string: "\n\n"))

            let body = (rel.body ?? "No release notes provided.").trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(NSAttributedString(string: body, attributes: bodyAttrs))
        }

        return result
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
