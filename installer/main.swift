import Cocoa
import Carbon

let layoutName = "AZERTY-Digits.keylayout"
let userInstalledDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Keyboard Layouts")
let userInstalledURL = userInstalledDir.appendingPathComponent(layoutName)
let installedDir = userInstalledDir
let installedURL = userInstalledURL

let systemInstalledDir = URL(fileURLWithPath: "/Library/Keyboard Layouts")
let systemInstalledURL = systemInstalledDir.appendingPathComponent(layoutName)

var isInstalledSystemWide: Bool {
    FileManager.default.fileExists(atPath: systemInstalledURL.path)
}
var isInstalledUserLevel: Bool {
    FileManager.default.fileExists(atPath: userInstalledURL.path)
}
var isInstalledAnywhere: Bool {
    isInstalledSystemWide || isInstalledUserLevel
}

let allUsersDefaultsKey = "installForAllUsers"
let menuBarDefaultsKey = "menuBarStyleIndex"
let baseLayoutDefaultsKey = "baseLayoutFlavorIndex"
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

// MARK: - Layout Conversion Engine (Ukelele Compatible)

func convertLayoutToDigits(xml: String, newName: String, newId: Int, underscore: Bool, degree: Bool) -> String {
    var lines = xml.components(separatedBy: "\n")

    // Update <keyboard> tag name and id
    for (i, line) in lines.enumerated() {
        if line.contains("<keyboard ") {
            lines[i] = line
                .replacingOccurrences(of: #"name="[^"]*""#, with: "name=\"\(newName)\"", options: .regularExpression)
                .replacingOccurrences(of: #"id="[^"]*""#, with: "id=\"\(newId)\"", options: .regularExpression)
            break
        }
    }

    let numberKeyCodes: [String] = ["18", "19", "20", "21", "23", "22", "26", "28", "25", "29"]
    let numberKeyCodesSet: Set<String> = Set(numberKeyCodes)

    func parseKeyOutputs(mapIndex: String) -> [String: String] {
        var outputs: [String: String] = [:]
        guard let start = lines.firstIndex(where: {
            $0.contains("<keyMap index=\"\(mapIndex)\">") || $0.contains("<keyMap index=\"\(mapIndex)\" ")
        }) else { return outputs }
        var i = start + 1
        while i < lines.count && !lines[i].contains("</keyMap>") {
            let l = lines[i]
            for code in numberKeyCodesSet {
                if l.contains("code=\"\(code)\"") {
                    if let range = l.range(of: #"output="([^"]*)""#, options: .regularExpression) {
                        let match = String(l[range])
                        let val = match.replacingOccurrences(of: "output=\"", with: "").replacingOccurrences(of: "\"", with: "")
                        outputs[code] = val
                    }
                }
            }
            i += 1
        }
        return outputs
    }

    let baseOutputs = parseKeyOutputs(mapIndex: "0")
    let shiftOutputs = parseKeyOutputs(mapIndex: "1")

    func setKeyOutputInMap(mapIndex: String, code: String, newOutput: String) {
        guard let start = lines.firstIndex(where: {
            $0.contains("<keyMap index=\"\(mapIndex)\">") || $0.contains("<keyMap index=\"\(mapIndex)\" ")
        }) else { return }
        var i = start + 1
        while i < lines.count && !lines[i].contains("</keyMap>") {
            if lines[i].contains("code=\"\(code)\"") {
                lines[i] = lines[i].replacingOccurrences(of: #"output="[^"]*""#, with: "output=\"\(newOutput)\"", options: .regularExpression)
                return
            }
            i += 1
        }
    }

    let digitsMap: [String: String] = [
        "18": "1", "19": "2", "20": "3", "21": "4", "23": "5",
        "22": "6", "26": "7", "28": "8", "25": "9", "29": "0"
    ]
    let digitsSet: Set<String> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

    let fallbackSymbols: [String: String] = [
        "18": "&#x0026;", "19": "é", "20": "&#x0022;", "21": "&#x0027;", "23": "(",
        "22": "§", "26": "è", "28": "!", "25": "ç", "29": "à"
    ]

    for code in numberKeyCodes {
        let digit = digitsMap[code] ?? "0"

        var symbol: String = ""
        if let b = baseOutputs[code], !digitsSet.contains(b) {
            symbol = b
        } else if let s = shiftOutputs[code], !digitsSet.contains(s) {
            symbol = s
        } else {
            symbol = fallbackSymbols[code] ?? digit
        }

        // Base layer (0) and Caps Lock (2, 9): always type digits without Shift
        setKeyOutputInMap(mapIndex: "0", code: code, newOutput: digit)
        setKeyOutputInMap(mapIndex: "2", code: code, newOutput: digit)
        setKeyOutputInMap(mapIndex: "9", code: code, newOutput: digit)

        // Shift layer (1) and Shift+Caps (8): type the symbols
        setKeyOutputInMap(mapIndex: "1", code: code, newOutput: symbol)
        setKeyOutputInMap(mapIndex: "8", code: code, newOutput: symbol)
    }

    // Key 24 customization: '-' vs '_'
    if underscore {
        for mapIdx in ["0", "2", "9"] {
            setKeyOutputInMap(mapIndex: mapIdx, code: "24", newOutput: "_")
        }
        setKeyOutputInMap(mapIndex: "1", code: "24", newOutput: "_")
        setKeyOutputInMap(mapIndex: "8", code: "24", newOutput: "_")
    }

    // Key 27 customization: ')' vs '°'
    let base27 = degree ? "°" : ")"
    let shift27 = degree ? ")" : "°"
    for mapIdx in ["0", "2", "9"] {
        setKeyOutputInMap(mapIndex: mapIdx, code: "27", newOutput: base27)
    }
    setKeyOutputInMap(mapIndex: "1", code: "27", newOutput: shift27)
    setKeyOutputInMap(mapIndex: "8", code: "27", newOutput: shift27)

    return lines.joined(separator: "\n")
}

// Rewrites key 24 and key 27 on the base (0), Caps-only (9) and Shift (1) layers.
func layoutText(from template: String, underscore: Bool, degree: Bool) -> String {
    convertLayoutToDigits(xml: template, newName: "AZERTY Digits", newId: -28851, underscore: underscore, degree: degree)
}

struct MenuBarStyle {
    let title: String
    let subtitle: String
    let file: String
}

let menuBarStyles = [
    MenuBarStyle(title: "FR", subtitle: "France", file: "fr"),
    MenuBarStyle(title: "BE", subtitle: "Belgium", file: "be"),
    MenuBarStyle(title: "LU", subtitle: "Luxembourg", file: "lu"),
    MenuBarStyle(title: "MA", subtitle: "Morocco", file: "ma"),
    MenuBarStyle(title: "DZ", subtitle: "Algeria", file: "dz"),
    MenuBarStyle(title: "DG", subtitle: "Digits", file: "dg"),
    MenuBarStyle(title: "123", subtitle: "Numeric", file: "123"),
    MenuBarStyle(title: "FRPC", subtitle: "French PC", file: "frpc"),
]

struct BaseFlavor {
    let name: String
    let filename: String
    let defaultIconIndex: Int
}

let baseFlavors = [
    BaseFlavor(name: "Belgian (Belge)", filename: "Belgian.keylayout", defaultIconIndex: 1),
    BaseFlavor(name: "French (France)", filename: "French.keylayout", defaultIconIndex: 0),
    BaseFlavor(name: "French – PC (Français - PC)", filename: "French-PC.keylayout", defaultIconIndex: 7),
]

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let updateBanner = NSTextField(wrappingLabelWithString: "Checking for updates...")
    let iconPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let flavorPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let iconPreview = NSImageView()
    var toggleAllUsers: NSButton!
    var toggleUnderscore: NSButton!
    var toggleDegree: NSButton!
    var checkUpdatesButton: NSButton!
    var viewNotesButton: NSButton!

    var cachedReleases: [GitHubRelease] = []
    var isCheckingUpdates = false
    var lastSelectedFlavorIndex = 0

    let allUsersHelp = NSTextField(wrappingLabelWithString:
        "Required if you want this layout to be used on the lock screen and login window (e.g. typing digits in password or PIN codes without Shift). Installs to /Library/Keyboard Layouts/ with administrator privileges.")
    let underscoreHelp = NSTextField(wrappingLabelWithString:
        "Off: key 24 types - without Shift and _ with Shift.\nOn: key 24 types _ without Shift, and Shift still gives _.")
    let degreeHelp = NSTextField(wrappingLabelWithString:
        "Off: key 27 types ) without Shift and ° with Shift, so ( and ) end up on different Shift levels.\nOn: key 27 types ° without Shift and ) with Shift, so ( and ) share the Shift level.")

    var kluchrtoxmlURL: URL? {
        if let bundled = Bundle.main.url(forResource: "kluchrtoxml", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        let ukeleleApp = "/Applications/Ukelele.app/Contents/MacOS/kluchrtoxml"
        if FileManager.default.isExecutableFile(atPath: ukeleleApp) {
            return URL(fileURLWithPath: ukeleleApp)
        }
        let local = URL(fileURLWithPath: "kluchrtoxml")
        if FileManager.default.isExecutableFile(atPath: local.path) {
            return local
        }
        return nil
    }

    var selectedFlavor: BaseFlavor {
        let idx = flavorPopup.indexOfSelectedItem
        if (0..<baseFlavors.count).contains(idx) {
            return baseFlavors[idx]
        }
        return baseFlavors[0]
    }

    var bundledLayout: URL? {
        let name = selectedFlavor.filename.replacingOccurrences(of: ".keylayout", with: "")
        return Bundle.main.url(forResource: name, withExtension: "keylayout")
            ?? Bundle.main.url(forResource: "AZERTY-Digits", withExtension: "keylayout")
    }

    func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func getInstalledVersion() -> String? {
        if let stored = UserDefaults.standard.string(forKey: installedVersionDefaultsKey), !stored.isEmpty {
            return stored
        }
        let checkURL = isInstalledSystemWide ? systemInstalledURL : userInstalledURL
        guard FileManager.default.fileExists(atPath: checkURL.path) else {
            return nil
        }
        if let content = try? String(contentsOf: checkURL, encoding: .utf8) {
            let pattern = #"<!--\s*version="([^"]+)"\s*-->"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                let v = String(content[range])
                UserDefaults.standard.set(v, forKey: installedVersionDefaultsKey)
                return v
            }
        }
        return "1.0.0"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        let savedFlavor = UserDefaults.standard.integer(forKey: baseLayoutDefaultsKey)
        lastSelectedFlavorIndex = (0..<baseFlavors.count).contains(savedFlavor) ? savedFlavor : 0
        flavorPopup.selectItem(at: lastSelectedFlavorIndex)
        let defaultIcon = baseFlavors[lastSelectedFlavorIndex].defaultIconIndex
        let savedIcon = UserDefaults.standard.object(forKey: menuBarDefaultsKey) != nil
            ? UserDefaults.standard.integer(forKey: menuBarDefaultsKey)
            : defaultIcon
        selectMenuBarStyle(index: savedIcon)
        refreshStatus()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Listen for system appearance / theme change (Light / Dark mode)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceDidChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // Automatic update check in background
        checkForUpdates(silent: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 740),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AZERTY Digits Installer"
        window.center()
        window.delegate = self

        let content = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = content

        // Header
        let title = NSTextField(labelWithString: "AZERTY Digits")
        title.font = .boldSystemFont(ofSize: 22)

        let subtitle = NSTextField(wrappingLabelWithString:
            "Digits on the number row without Shift or Caps Lock. Option, Option+Shift and the rest of Apple's French layout are unchanged.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        // Icon Preview & Menu Bar Style Card
        iconPreview.imageScaling = .scaleProportionallyUpOrDown
        iconPreview.translatesAutoresizingMaskIntoConstraints = false

        iconPopup.target = self
        iconPopup.action = #selector(menuBarChanged)
        refreshMenuBarStyleItems()

        let iconLabel = NSTextField(labelWithString: "Menu Bar Icon")
        iconLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let iconSubtitle = NSTextField(wrappingLabelWithString: "Choose the badge shown in your macOS menu bar.")
        iconSubtitle.font = .systemFont(ofSize: 11)
        iconSubtitle.textColor = .secondaryLabelColor

        let iconControls = NSStackView(views: [iconLabel, iconPopup, iconSubtitle])
        iconControls.orientation = .vertical
        iconControls.alignment = .leading
        iconControls.spacing = 5

        let iconSection = NSStackView(views: [iconPreview, iconControls])
        iconSection.orientation = .horizontal
        iconSection.alignment = .centerY
        iconSection.spacing = 16

        // Base Layout Flavor Selection
        flavorPopup.removeAllItems()
        for flavor in baseFlavors {
            flavorPopup.addItem(withTitle: flavor.name)
        }
        flavorPopup.menu?.addItem(NSMenuItem.separator())
        flavorPopup.addItem(withTitle: "Other Layout...")
        flavorPopup.target = self
        flavorPopup.action = #selector(flavorChanged)

        let flavorLabel = NSTextField(labelWithString: "Layout:")
        flavorLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        let flavorRow = NSStackView(views: [flavorLabel, flavorPopup])
        flavorRow.spacing = 8
        flavorRow.alignment = .centerY

        // Install for all users (placed right below Layout picker)
        UserDefaults.standard.register(defaults: [allUsersDefaultsKey: false])
        toggleAllUsers = NSButton(
            checkboxWithTitle: "Install for all users (Lock screen & Login window)",
            target: self,
            action: #selector(toggleAllUsersChanged))
        toggleAllUsers.font = .systemFont(ofSize: 12, weight: .medium)
        if isInstalledSystemWide {
            toggleAllUsers.state = .on
        } else if isInstalledUserLevel {
            toggleAllUsers.state = .off
        } else {
            toggleAllUsers.state = UserDefaults.standard.bool(forKey: allUsersDefaultsKey) ? .on : .off
        }

        allUsersHelp.font = .systemFont(ofSize: 11)
        allUsersHelp.textColor = .secondaryLabelColor
        allUsersHelp.preferredMaxLayoutWidth = 440

        // Checkboxes Section
        UserDefaults.standard.register(defaults: [underscoreDefaultsKey: false, degreeDefaultsKey: true])
        toggleUnderscore = NSButton(checkboxWithTitle: "Include _ on the number row (key 24)", target: self, action: #selector(toggleChanged))
        toggleDegree = NSButton(checkboxWithTitle: "Include ° on the number row (key 27)", target: self, action: #selector(toggleChanged))
        toggleUnderscore.font = .systemFont(ofSize: 12, weight: .medium)
        toggleDegree.font = .systemFont(ofSize: 12, weight: .medium)
        toggleUnderscore.state = UserDefaults.standard.bool(forKey: underscoreDefaultsKey) ? .on : .off
        toggleDegree.state = UserDefaults.standard.bool(forKey: degreeDefaultsKey) ? .on : .off

        for help in [underscoreHelp, degreeHelp] {
            help.font = .systemFont(ofSize: 11)
            help.textColor = .secondaryLabelColor
            help.preferredMaxLayoutWidth = 440
        }

        let optionsTitle = NSTextField(labelWithString: "Layout Options")
        optionsTitle.font = .systemFont(ofSize: 13, weight: .semibold)

        let optionsStack = NSStackView(views: [
            optionsTitle,
            flavorRow,
            toggleAllUsers, allUsersHelp,
            toggleUnderscore, underscoreHelp,
            toggleDegree, degreeHelp
        ])
        optionsStack.orientation = .vertical
        optionsStack.alignment = .leading
        optionsStack.spacing = 6

        // Action Buttons (Row 1)
        let install = NSButton(title: "Install", target: self, action: #selector(installAction))
        let update = NSButton(title: "Update", target: self, action: #selector(updateAction))
        let uninstall = NSButton(title: "Uninstall", target: self, action: #selector(uninstallAction))
        install.bezelStyle = .rounded
        update.bezelStyle = .rounded
        uninstall.bezelStyle = .rounded
        install.keyEquivalent = "\r"

        let buttons = NSStackView(views: [install, update, uninstall])
        buttons.spacing = 10

        // Secondary Buttons (Row 2)
        let settings = NSButton(title: "Open Keyboard Settings", target: self, action: #selector(openSettings))
        settings.bezelStyle = .rounded

        checkUpdatesButton = NSButton(title: "Check for Updates", target: self, action: #selector(checkUpdatesAction))
        checkUpdatesButton.bezelStyle = .rounded

        let supportButton = NSButton(title: "☕ Support on Ko-fi", target: self, action: #selector(supportAction))
        supportButton.bezelStyle = .rounded

        let extraButtons = NSStackView(views: [settings, checkUpdatesButton, supportButton])
        extraButtons.spacing = 8

        // Status & Update Info
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.preferredMaxLayoutWidth = 440

        viewNotesButton = NSButton(title: "Release Notes", target: self, action: #selector(viewNotesAction))
        viewNotesButton.bezelStyle = .inline
        viewNotesButton.isHidden = true

        updateBanner.font = .systemFont(ofSize: 11)
        updateBanner.textColor = .secondaryLabelColor

        let updateRow = NSStackView(views: [updateBanner, viewNotesButton])
        updateRow.spacing = 8
        updateRow.alignment = .centerY

        // Help Note
        let steps = NSTextField(wrappingLabelWithString:
            "💡 Next steps: After install or update, log out and back in, then add AZERTY Digits in System Settings > Keyboard > Input Sources (+ > Others). macOS doesn't let apps add input sources for you.")
        steps.font = .systemFont(ofSize: 11)
        steps.textColor = .secondaryLabelColor
        steps.preferredMaxLayoutWidth = 440

        let sep1 = makeSeparator()
        let sep2 = makeSeparator()
        let sep3 = makeSeparator()

        let stack = NSStackView(views: [
            title, subtitle,
            sep1,
            iconSection,
            sep2,
            optionsStack,
            buttons,
            extraButtons,
            statusLabel,
            updateRow,
            sep3,
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
            iconPreview.widthAnchor.constraint(equalToConstant: 76),
            iconPreview.heightAnchor.constraint(equalToConstant: 76),
            subtitle.widthAnchor.constraint(equalToConstant: 450),
            sep1.widthAnchor.constraint(equalToConstant: 450),
            sep2.widthAnchor.constraint(equalToConstant: 450),
            sep3.widthAnchor.constraint(equalToConstant: 450),
            iconPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
        ])

        window.makeKeyAndOrderFront(nil)
    }

    var isSystemDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    func iconURL(for file: String, forceBlack: Bool? = nil) -> URL? {
        let useBlack = forceBlack ?? !isSystemDark
        let suffix = useBlack ? "-black" : ""
        if let u = Bundle.main.url(forResource: "\(file)\(suffix)", withExtension: "icns") {
            return u
        }
        return Bundle.main.url(forResource: file, withExtension: "icns")
    }

    var selectedStyle: MenuBarStyle {
        let safe = (0..<menuBarStyles.count).contains(iconPopup.indexOfSelectedItem) ? iconPopup.indexOfSelectedItem : 0
        return menuBarStyles[safe]
    }

    var selectedStyleURL: URL? {
        iconURL(for: selectedStyle.file)
    }

    func refreshMenuBarStyleItems() {
        let currentIdx = (0..<menuBarStyles.count).contains(iconPopup.indexOfSelectedItem) ? iconPopup.indexOfSelectedItem : 0
        iconPopup.removeAllItems()
        for style in menuBarStyles {
            let item = NSMenuItem(title: "\(style.title)  (\(style.subtitle))", action: nil, keyEquivalent: "")
            if let url = iconURL(for: style.file), let image = NSImage(contentsOf: url) {
                let thumb = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                    image.draw(in: rect)
                    return true
                }
                item.image = thumb
            }
            iconPopup.menu?.addItem(item)
        }
        iconPopup.selectItem(at: currentIdx)
        updateIconPreview()
    }

    func updateIconPreview() {
        if let url = selectedStyleURL, let image = NSImage(contentsOf: url) {
            iconPreview.image = image
        }
    }

    func selectMenuBarStyle(index: Int) {
        let safe = (0..<menuBarStyles.count).contains(index) ? index : 0
        iconPopup.selectItem(at: safe)
        UserDefaults.standard.set(safe, forKey: menuBarDefaultsKey)
        updateIconPreview()
    }

    @objc func appearanceDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refreshMenuBarStyleItems()
            self.syncInstalledIconIfNeeded()
        }
    }

    func syncInstalledIconIfNeeded() {
        let targets = [
            (isInstalledSystemWide, systemInstalledDir),
            (isInstalledUserLevel, userInstalledDir)
        ]
        for (installed, dir) in targets where installed {
            let whiteTarget = dir.appendingPathComponent(".AZERTY-Digits-white.icns")
            let blackTarget = dir.appendingPathComponent(".AZERTY-Digits-black.icns")
            let activeTarget = dir.appendingPathComponent("AZERTY-Digits.icns")

            let source = isSystemDark ? whiteTarget : blackTarget
            if FileManager.default.fileExists(atPath: source.path) {
                try? FileManager.default.removeItem(at: activeTarget)
                try? FileManager.default.copyItem(at: source, to: activeTarget)
            }
        }
    }

    @objc func flavorChanged() {
        let idx = flavorPopup.indexOfSelectedItem
        if idx < baseFlavors.count {
            lastSelectedFlavorIndex = idx
            UserDefaults.standard.set(idx, forKey: baseLayoutDefaultsKey)
            let recommendedIcon = selectedFlavor.defaultIconIndex
            selectMenuBarStyle(index: recommendedIcon)
            setStatus("Selected layout: \(selectedFlavor.name). Click Install/Update to apply.")
        } else {
            // "Other Layout..." selected: restore previous selection in popup and open exporter sheet
            flavorPopup.selectItem(at: lastSelectedFlavorIndex)
            openExporterAction()
        }
    }

    @objc func toggleAllUsersChanged() {
        let isAll = toggleAllUsers.state == .on
        UserDefaults.standard.set(isAll, forKey: allUsersDefaultsKey)
        if isAll {
            setStatus("Install for all users selected. Click Install or Update (requires admin password).")
        } else {
            setStatus("Install for current user selected. Click Install or Update.")
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
        let ver = getInstalledVersion() ?? getAppVersion()
        if isInstalledSystemWide {
            setStatus("Installed (v\(ver)) for all users (/Library/Keyboard Layouts). Available on lock screen.")
        } else if isInstalledUserLevel {
            setStatus("Installed (v\(ver)) at ~/Library/Keyboard Layouts (Current user only).")
        } else {
            setStatus("Not installed.")
        }
    }

    // MARK: - Admin Execution Helper

    func runAsAdmin(_ command: String) throws {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        var errorInfo: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&errorInfo)
            if let errorInfo = errorInfo {
                let msg = errorInfo[NSAppleScript.errorMessage] as? String ?? "Authentication cancelled or failed."
                throw NSError(domain: "AZERTYDigitsAdmin", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
        } else {
            throw NSError(domain: "AZERTYDigitsAdmin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize NSAppleScript."])
        }
    }

    // MARK: - Actions

    @objc func installAction() {
        guard let source = bundledLayout else {
            setStatus("Layout file missing from the app bundle.")
            return
        }
        let targetExists = toggleAllUsers.state == .on ? isInstalledSystemWide : isInstalledUserLevel
        if targetExists {
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
        var didRemove = false
        if isInstalledSystemWide {
            do {
                let cmd = "rm -f '/Library/Keyboard Layouts/AZERTY-Digits.keylayout' '/Library/Keyboard Layouts/AZERTY-Digits.icns' '/Library/Keyboard Layouts/.AZERTY-Digits-white.icns' '/Library/Keyboard Layouts/.AZERTY-Digits-black.icns'"
                try runAsAdmin(cmd)
                didRemove = true
            } catch {
                setStatus("Could not remove system layout: \(error.localizedDescription)")
                return
            }
        }
        if isInstalledUserLevel {
            do {
                try FileManager.default.removeItem(at: userInstalledURL)
                let iconTarget = userInstalledDir.appendingPathComponent("AZERTY-Digits.icns")
                if FileManager.default.fileExists(atPath: iconTarget.path) {
                    try FileManager.default.removeItem(at: iconTarget)
                }
                didRemove = true
            } catch {
                setStatus("Could not remove user layout: \(error.localizedDescription)")
                return
            }
        }
        if didRemove {
            uninstallThemeSyncAgent()
            UserDefaults.standard.removeObject(forKey: installedVersionDefaultsKey)
            setStatus("Removed. Also remove AZERTY Digits from Input Sources if it's still listed.")
        } else {
            setStatus("Nothing to remove.")
        }
    }

    func copyLayout(from source: URL, action: String) {
        do {
            let template = try String(contentsOf: source, encoding: .utf8)
            let text = layoutText(
                from: template,
                underscore: toggleUnderscore.state == .on,
                degree: toggleDegree.state == .on)

            let whiteIcon = iconURL(for: selectedStyle.file, forceBlack: false)
            let blackIcon = iconURL(for: selectedStyle.file, forceBlack: true)
            let activeSource = (isSystemDark ? whiteIcon : blackIcon) ?? whiteIcon

            let isAllUsers = toggleAllUsers.state == .on

            if isAllUsers {
                let tempDir = FileManager.default.temporaryDirectory
                let tempLayout = tempDir.appendingPathComponent("AZERTY-Digits.keylayout")
                let tempIcon = tempDir.appendingPathComponent("AZERTY-Digits.icns")
                let tempWhite = tempDir.appendingPathComponent(".AZERTY-Digits-white.icns")
                let tempBlack = tempDir.appendingPathComponent(".AZERTY-Digits-black.icns")

                try text.write(to: tempLayout, atomically: true, encoding: .utf8)
                if let activeSource = activeSource {
                    try? FileManager.default.removeItem(at: tempIcon)
                    try FileManager.default.copyItem(at: activeSource, to: tempIcon)
                }
                if let whiteIcon = whiteIcon {
                    try? FileManager.default.removeItem(at: tempWhite)
                    try FileManager.default.copyItem(at: whiteIcon, to: tempWhite)
                }
                if let blackIcon = blackIcon {
                    try? FileManager.default.removeItem(at: tempBlack)
                    try FileManager.default.copyItem(at: blackIcon, to: tempBlack)
                }

                let adminCmd = """
                mkdir -p "/Library/Keyboard Layouts" && \
                cp -f "\(tempLayout.path)" "/Library/Keyboard Layouts/AZERTY-Digits.keylayout" && \
                cp -f "\(tempIcon.path)" "/Library/Keyboard Layouts/AZERTY-Digits.icns" && \
                ([ ! -f "\(tempWhite.path)" ] || cp -f "\(tempWhite.path)" "/Library/Keyboard Layouts/.AZERTY-Digits-white.icns") && \
                ([ ! -f "\(tempBlack.path)" ] || cp -f "\(tempBlack.path)" "/Library/Keyboard Layouts/.AZERTY-Digits-black.icns") && \
                chmod 644 "/Library/Keyboard Layouts/AZERTY-Digits.keylayout" && \
                chmod 666 "/Library/Keyboard Layouts/AZERTY-Digits.icns" && \
                ([ ! -f "/Library/Keyboard Layouts/.AZERTY-Digits-white.icns" ] || chmod 666 "/Library/Keyboard Layouts/.AZERTY-Digits-white.icns") && \
                ([ ! -f "/Library/Keyboard Layouts/.AZERTY-Digits-black.icns" ] || chmod 666 "/Library/Keyboard Layouts/.AZERTY-Digits-black.icns")
                """
                try runAsAdmin(adminCmd)

                // Clean up any user-level copy so macOS has no duplicate
                if FileManager.default.fileExists(atPath: userInstalledURL.path) {
                    try? FileManager.default.removeItem(at: userInstalledURL)
                    let userIcon = userInstalledDir.appendingPathComponent("AZERTY-Digits.icns")
                    try? FileManager.default.removeItem(at: userIcon)
                }

                installThemeSyncAgent(targetDir: systemInstalledDir)

                let ver = getAppVersion()
                UserDefaults.standard.set(ver, forKey: installedVersionDefaultsKey)
                setStatus("\(action) \(selectedFlavor.name) (v\(ver)) for all users (/Library). Available on lock screen!")
            } else {
                try FileManager.default.createDirectory(at: userInstalledDir, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: userInstalledURL.path) {
                    try FileManager.default.removeItem(at: userInstalledURL)
                }
                try text.write(to: userInstalledURL, atomically: true, encoding: .utf8)

                let whiteTarget = userInstalledDir.appendingPathComponent(".AZERTY-Digits-white.icns")
                let blackTarget = userInstalledDir.appendingPathComponent(".AZERTY-Digits-black.icns")
                let activeTarget = userInstalledDir.appendingPathComponent("AZERTY-Digits.icns")

                if let whiteIcon = whiteIcon {
                    try? FileManager.default.removeItem(at: whiteTarget)
                    try? FileManager.default.copyItem(at: whiteIcon, to: whiteTarget)
                }
                if let blackIcon = blackIcon {
                    try? FileManager.default.removeItem(at: blackTarget)
                    try? FileManager.default.copyItem(at: blackIcon, to: blackTarget)
                }
                if let activeSource = activeSource {
                    try? FileManager.default.removeItem(at: activeTarget)
                    try? FileManager.default.copyItem(at: activeSource, to: activeTarget)
                }

                // If installed in /Library, remove it with admin privileges so it doesn't conflict
                if isInstalledSystemWide {
                    let cmd = "rm -f '/Library/Keyboard Layouts/AZERTY-Digits.keylayout' '/Library/Keyboard Layouts/AZERTY-Digits.icns' '/Library/Keyboard Layouts/.AZERTY-Digits-white.icns' '/Library/Keyboard Layouts/.AZERTY-Digits-black.icns'"
                    try? runAsAdmin(cmd)
                }

                installThemeSyncAgent(targetDir: userInstalledDir)

                let ver = getAppVersion()
                UserDefaults.standard.set(ver, forKey: installedVersionDefaultsKey)
                setStatus("\(action) \(selectedFlavor.name) (v\(ver)) at ~/Library/Keyboard Layouts.")
            }
        } catch {
            setStatus("Failed: \(error.localizedDescription)")
        }
    }

    var launchAgentsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
    }
    var agentPlistURL: URL {
        launchAgentsDir.appendingPathComponent("com.kceryrk.azerty-digits.theme-sync.plist")
    }
    var syncScriptURL: URL {
        userInstalledDir.appendingPathComponent(".theme-sync.sh")
    }

    func installThemeSyncAgent(targetDir: URL) {
        let script = """
        #!/bin/sh
        STYLE=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
        DIR="\(targetDir.path)"
        if [ "$STYLE" = "Dark" ]; then
            [ -f "$DIR/.AZERTY-Digits-white.icns" ] && cp -f "$DIR/.AZERTY-Digits-white.icns" "$DIR/AZERTY-Digits.icns" 2>/dev/null
        else
            [ -f "$DIR/.AZERTY-Digits-black.icns" ] && cp -f "$DIR/.AZERTY-Digits-black.icns" "$DIR/AZERTY-Digits.icns" 2>/dev/null
        fi
        """
        try? FileManager.default.createDirectory(at: userInstalledDir, withIntermediateDirectories: true)
        try? script.write(to: syncScriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: syncScriptURL.path)

        let globalPrefs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/.GlobalPreferences.plist").path

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.kceryrk.azerty-digits.theme-sync</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/sh</string>
                <string>\(syncScriptURL.path)</string>
            </array>
            <key>WatchPaths</key>
            <array>
                <string>\(globalPrefs)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
        try? FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        try? plist.write(to: agentPlistURL, atomically: true, encoding: .utf8)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["load", agentPlistURL.path]
        try? task.run()
    }

    func uninstallThemeSyncAgent() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", agentPlistURL.path]
        try? task.run()
        task.waitUntilExit()

        try? FileManager.default.removeItem(at: agentPlistURL)
        try? FileManager.default.removeItem(at: syncScriptURL)
        try? FileManager.default.removeItem(at: installedDir.appendingPathComponent(".AZERTY-Digits-white.icns"))
        try? FileManager.default.removeItem(at: installedDir.appendingPathComponent(".AZERTY-Digits-black.icns"))
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

        var targetReleases = releases.filter { SemanticVersion($0.tagName) >= installedSem }
        if targetReleases.isEmpty {
            targetReleases = releases
        }

        let sheetRect = NSRect(x: 0, y: 0, width: 520, height: 490)
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
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 8
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 14, height: 14)
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

        let buttonRow = NSStackView(views: [NSView(), buttonStack])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fill
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = NSStackView(views: [header, subtitle, scrollView, buttonRow])
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
            buttonRow.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
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

    func parseMarkdown(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        let baseFont = NSFont.systemFont(ofSize: 12)
        let boldFont = NSFont.boldSystemFont(ofSize: 12)
        let monoFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let h2Font = NSFont.boldSystemFont(ofSize: 14)
        let h3Font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        func parseInline(_ text: String, defaultFont: NSFont) -> NSAttributedString {
            let attr = NSMutableAttributedString()
            var i = text.startIndex

            while i < text.endIndex {
                if text[i...].hasPrefix("**") {
                    let start = text.index(i, offsetBy: 2)
                    if let end = text[start...].range(of: "**") {
                        let boldText = String(text[start..<end.lowerBound])
                        attr.append(NSAttributedString(string: boldText, attributes: [
                            .font: boldFont,
                            .foregroundColor: NSColor.labelColor
                        ]))
                        i = end.upperBound
                        continue
                    }
                } else if text[i] == "`" {
                    let start = text.index(after: i)
                    if let end = text[start...].firstIndex(of: "`") {
                        let codeText = String(text[start..<end])
                        attr.append(NSAttributedString(string: codeText, attributes: [
                            .font: monoFont,
                            .foregroundColor: NSColor.labelColor,
                            .backgroundColor: NSColor.quaternaryLabelColor
                        ]))
                        i = text.index(after: end)
                        continue
                    }
                }

                attr.append(NSAttributedString(string: String(text[i]), attributes: [
                    .font: defaultFont,
                    .foregroundColor: NSColor.labelColor
                ]))
                i = text.index(after: i)
            }
            return attr
        }

        var lastWasEmpty = true

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !lastWasEmpty {
                    result.append(NSAttributedString(string: "\n"))
                    lastWasEmpty = true
                }
                continue
            }
            lastWasEmpty = false

            if trimmed.hasPrefix("## ") {
                let title = String(trimmed.dropFirst(3))
                result.append(NSAttributedString(string: "\n" + title + "\n\n", attributes: [
                    .font: h2Font,
                    .foregroundColor: NSColor.labelColor
                ]))
            } else if trimmed.hasPrefix("### ") {
                let title = String(trimmed.dropFirst(4))
                result.append(NSAttributedString(string: "\n" + title + "\n\n", attributes: [
                    .font: h3Font,
                    .foregroundColor: NSColor.labelColor
                ]))
            } else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                let content = String(trimmed.dropFirst(2))
                let indent = rawLine.prefix(while: { $0 == " " || $0 == "\t" }).count
                let prefix = indent >= 2 ? "      ◦  " : "  •  "
                result.append(NSAttributedString(string: prefix, attributes: [
                    .font: baseFont,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]))
                result.append(parseInline(content, defaultFont: baseFont))
                result.append(NSAttributedString(string: "\n"))
            } else {
                result.append(parseInline(trimmed, defaultFont: baseFont))
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
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

        let installedSem = SemanticVersion(installed)

        for (i, rel) in releases.enumerated() {
            if i > 0 {
                result.append(NSAttributedString(string: "\n\n──────────────────────────────────────────────────\n\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor.separatorColor
                ]))
            }

            let relSem = SemanticVersion(rel.tagName)
            let rawName = (rel.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let heading: String
            if rawName.isEmpty {
                heading = rel.tagName
            } else if rawName.hasPrefix(rel.tagName) {
                heading = rawName
            } else {
                heading = "\(rel.tagName) — \(rawName)"
            }

            result.append(NSAttributedString(string: heading, attributes: tagAttrs))

            if let dateStr = rel.publishedAt, let date = isoFormatter.date(from: dateStr) {
                result.append(NSAttributedString(string: "  •  \(dateFormatter.string(from: date))", attributes: dateAttrs))
            }

            if relSem == installedSem {
                result.append(NSAttributedString(string: "  [Current Version]", attributes: badgeInstalledAttrs))
            } else if relSem > installedSem {
                result.append(NSAttributedString(string: "  [New Update]", attributes: badgeNewAttrs))
            }

            result.append(NSAttributedString(string: "\n"))

            let body = (rel.body ?? "No release notes provided.").trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(parseMarkdown(body))
        }

        return result
    }

    // MARK: - Ukelele Layout Exporter & Customizer

    @objc func openExporterAction() {
        showExporterSheet()
    }

    func showExporterSheet() {
        let sheetRect = NSRect(x: 0, y: 0, width: 520, height: 520)
        let sheet = NSWindow(contentRect: sheetRect, styleMask: [.titled], backing: .buffered, defer: false)
        let content = NSView(frame: sheetRect)
        sheet.contentView = content

        let header = NSTextField(labelWithString: "Other Layout Exporter")
        header.font = .boldSystemFont(ofSize: 18)

        let subtitle = NSTextField(wrappingLabelWithString:
            "Export or convert any macOS keyboard layout (such as French – PC, Belgian, or your active layout) to have digits by default on the number row.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        // Source Layout Selection
        let sourceLabel = NSTextField(labelWithString: "Source Keyboard Layout:")
        sourceLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        let sourcePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        sourcePopup.addItem(withTitle: "French – PC (Français - PC)")
        sourcePopup.addItem(withTitle: "French (Standard Apple)")
        sourcePopup.addItem(withTitle: "Current System Active Layout")
        sourcePopup.addItem(withTitle: "Choose .keylayout file...")

        let customFileLabel = NSTextField(wrappingLabelWithString: "No file selected.")
        customFileLabel.font = .systemFont(ofSize: 11)
        customFileLabel.textColor = .secondaryLabelColor
        customFileLabel.isHidden = true

        let browseButton = NSButton(title: "Browse...", target: nil, action: nil)
        browseButton.bezelStyle = .rounded
        browseButton.isHidden = true

        let sourceRow = NSStackView(views: [sourcePopup, browseButton])
        sourceRow.spacing = 8
        sourceRow.alignment = .centerY

        // Layout Name Field
        let nameLabel = NSTextField(labelWithString: "Exported Layout Name:")
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        let nameField = NSTextField(string: "French – PC Digits")
        nameField.font = .systemFont(ofSize: 12)

        sourcePopup.target = self
        sourcePopup.action = #selector(exporterSourceChanged(_:))

        // Options
        let expUnderscore = NSButton(checkboxWithTitle: "Include _ on key 24 (off: -)", target: nil, action: nil)
        let expDegree = NSButton(checkboxWithTitle: "Include ° on key 27 (off: ))", target: nil, action: nil)
        expUnderscore.font = .systemFont(ofSize: 12)
        expDegree.font = .systemFont(ofSize: 12)
        expUnderscore.state = toggleUnderscore.state
        expDegree.state = toggleDegree.state

        // Associated Icon
        let iconLabel = NSTextField(labelWithString: "Menu Bar Icon Badge:")
        iconLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        let expIconPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for style in menuBarStyles {
            let item = NSMenuItem(title: "\(style.title) (\(style.subtitle))", action: nil, keyEquivalent: "")
            if let url = iconURL(for: style.file),
               let img = NSImage(contentsOf: url) {
                let thumb = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                    img.draw(in: rect)
                    return true
                }
                item.image = thumb
            }
            expIconPopup.menu?.addItem(item)
        }
        expIconPopup.selectItem(at: 7) // Default to FRPC

        // Info box
        let infoBox = NSTextField(wrappingLabelWithString:
            "✨ Digits Conversion: Swaps number keys (1..0) onto unshifted base and Caps Lock layers. Original symbols (& é \" ' ( - è _ ç à) remain directly accessible with Shift.")
        infoBox.font = .systemFont(ofSize: 11)
        infoBox.textColor = .secondaryLabelColor
        infoBox.preferredMaxLayoutWidth = 460

        // Buttons
        let exportFileButton = NSButton(title: "Save .keylayout...", target: nil, action: nil)
        exportFileButton.bezelStyle = .rounded

        let installCustomButton = NSButton(title: "Install to macOS", target: nil, action: nil)
        installCustomButton.bezelStyle = .rounded

        let ukeleleAppPath = "/Applications/Ukelele.app"
        let hasUkelele = FileManager.default.fileExists(atPath: ukeleleAppPath)
        let openUkeleleButton = NSButton(title: "Open in Ukelele", target: nil, action: nil)
        openUkeleleButton.bezelStyle = .rounded
        openUkeleleButton.isEnabled = hasUkelele

        let cancelSheetButton = NSButton(title: "Close", target: self, action: #selector(closeSheetAction(_:)))
        cancelSheetButton.bezelStyle = .rounded

        var actionButtons: [NSView] = [cancelSheetButton]
        if hasUkelele { actionButtons.insert(openUkeleleButton, at: 0) }
        actionButtons.insert(exportFileButton, at: 0)
        actionButtons.insert(installCustomButton, at: 0)

        let bottomStack = NSStackView(views: actionButtons)
        bottomStack.spacing = 8
        bottomStack.alignment = .centerY

        let bottomRow = NSStackView(views: [NSView(), bottomStack])
        bottomRow.orientation = .horizontal
        bottomRow.distribution = .fill
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        let formStack = NSStackView(views: [
            header, subtitle,
            makeSeparator(),
            sourceLabel, sourceRow, customFileLabel,
            nameLabel, nameField,
            iconLabel, expIconPopup,
            expUnderscore, expDegree,
            infoBox,
            makeSeparator(),
            bottomRow
        ])
        formStack.orientation = .vertical
        formStack.alignment = .leading
        formStack.spacing = 10
        formStack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        formStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(formStack)

        NSLayoutConstraint.activate([
            formStack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            formStack.topAnchor.constraint(equalTo: content.topAnchor),
            formStack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            subtitle.widthAnchor.constraint(equalToConstant: 480),
            nameField.widthAnchor.constraint(equalToConstant: 280),
            bottomRow.widthAnchor.constraint(equalToConstant: 480),
        ])

        // Generator Closure
        func generateConvertedXML() -> (xml: String, filename: String)? {
            let choice = sourcePopup.indexOfSelectedItem
            var sourceXML: String? = nil

            if choice == 0 {
                // French-PC
                if let u = Bundle.main.url(forResource: "French-PC", withExtension: "keylayout"),
                   let s = try? String(contentsOf: u, encoding: .utf8) {
                    sourceXML = s
                } else {
                    sourceXML = exportLayoutWithTool(inputSourceID: "com.apple.keylayout.French-PC")
                }
            } else if choice == 1 {
                // French Standard
                if let u = Bundle.main.url(forResource: "AZERTY-Digits", withExtension: "keylayout"),
                   let s = try? String(contentsOf: u, encoding: .utf8) {
                    sourceXML = s
                }
            } else if choice == 2 {
                // Current Active
                sourceXML = exportLayoutWithTool(inputSourceID: nil)
            } else if choice == 3, let u = objc_getAssociatedObject(sheet, "importedURL") as? URL {
                sourceXML = try? String(contentsOf: u, encoding: .utf8)
            }

            guard let raw = sourceXML, !raw.isEmpty else {
                let alert = NSAlert()
                alert.messageText = "Could Not Read Layout"
                alert.informativeText = "Unable to read source keyboard layout data. Please verify your selection."
                alert.runModal()
                return nil
            }

            let chosenName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Custom Digits"
                : nameField.stringValue
            let randomId = -Int.random(in: 28860...32000)

            let resultXML = convertLayoutToDigits(
                xml: raw,
                newName: chosenName,
                newId: randomId,
                underscore: expUnderscore.state == .on,
                degree: expDegree.state == .on
            )

            let safeFilename = chosenName
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            return (resultXML, "\(safeFilename).keylayout")
        }

        // Browse handler
        browseButton.target = self
        browseButton.action = #selector(browseCustomFileAction(_:))

        // Export button handler
        exportFileButton.target = self
        exportFileButton.action = #selector(exportCustomLayoutSaveAction(_:))

        // Install button handler
        installCustomButton.target = self
        installCustomButton.action = #selector(installCustomLayoutAction(_:))

        // Open in Ukelele handler
        openUkeleleButton.target = self
        openUkeleleButton.action = #selector(openInUkeleleAction(_:))

        // Retain references for event handlers
        objc_setAssociatedObject(sheet, "generateXML", generateConvertedXML, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(sheet, "sourcePopup", sourcePopup, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(sheet, "nameField", nameField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(sheet, "customFileLabel", customFileLabel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(sheet, "browseButton", browseButton, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(sheet, "expIconPopup", expIconPopup, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        window.beginSheet(sheet, completionHandler: nil)
    }

    @objc func exporterSourceChanged(_ sender: NSPopUpButton) {
        guard let sheet = sender.window else { return }
        let nameField = objc_getAssociatedObject(sheet, "nameField") as? NSTextField
        let browseButton = objc_getAssociatedObject(sheet, "browseButton") as? NSButton
        let customFileLabel = objc_getAssociatedObject(sheet, "customFileLabel") as? NSTextField
        let expIconPopup = objc_getAssociatedObject(sheet, "expIconPopup") as? NSPopUpButton

        switch sender.indexOfSelectedItem {
        case 0:
            nameField?.stringValue = "French – PC Digits"
            expIconPopup?.selectItem(at: 7) // FRPC
            browseButton?.isHidden = true
            customFileLabel?.isHidden = true
        case 1:
            nameField?.stringValue = "French Digits"
            expIconPopup?.selectItem(at: 0) // FR
            browseButton?.isHidden = true
            customFileLabel?.isHidden = true
        case 2:
            nameField?.stringValue = "Current Layout Digits"
            expIconPopup?.selectItem(at: 5) // DG
            browseButton?.isHidden = true
            customFileLabel?.isHidden = true
        case 3:
            nameField?.stringValue = "Custom Digits"
            browseButton?.isHidden = false
            customFileLabel?.isHidden = false
        default:
            break
        }
    }

    @objc func browseCustomFileAction(_ sender: NSButton) {
        guard let sheet = sender.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose an existing .keylayout XML file to convert:"

        panel.beginSheetModal(for: sheet) { response in
            if response == .OK, let url = panel.url {
                objc_setAssociatedObject(sheet, "importedURL", url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                let customFileLabel = objc_getAssociatedObject(sheet, "customFileLabel") as? NSTextField
                customFileLabel?.stringValue = url.lastPathComponent
                let nameField = objc_getAssociatedObject(sheet, "nameField") as? NSTextField
                let base = url.deletingPathExtension().lastPathComponent
                nameField?.stringValue = "\(base) Digits"
            }
        }
    }

    @objc func exportCustomLayoutSaveAction(_ sender: NSButton) {
        guard let sheet = sender.window,
              let gen = objc_getAssociatedObject(sheet, "generateXML") as? () -> (xml: String, filename: String)?
        else { return }

        guard let result = gen() else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = result.filename
        panel.allowedContentTypes = []
        panel.message = "Export Ukelele-Compatible Keyboard Layout:"

        panel.beginSheetModal(for: sheet) { response in
            if response == .OK, let url = panel.url {
                do {
                    try result.xml.write(to: url, atomically: true, encoding: .utf8)
                    let alert = NSAlert()
                    alert.messageText = "Layout Exported! 🎉"
                    alert.informativeText = "Saved to \(url.lastPathComponent).\nYou can open and edit it in Ukelele or copy it into ~/Library/Keyboard Layouts."
                    alert.beginSheetModal(for: sheet, completionHandler: nil)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = error.localizedDescription
                    alert.beginSheetModal(for: sheet, completionHandler: nil)
                }
            }
        }
    }

    @objc func installCustomLayoutAction(_ sender: NSButton) {
        guard let sheet = sender.window,
              let gen = objc_getAssociatedObject(sheet, "generateXML") as? () -> (xml: String, filename: String)?
        else { return }

        guard let result = gen() else { return }

        let targetURL = installedDir.appendingPathComponent(result.filename)
        let iconPopup = objc_getAssociatedObject(sheet, "expIconPopup") as? NSPopUpButton
        let iconIndex = iconPopup?.indexOfSelectedItem ?? 0
        let iconURL = self.iconURL(for: menuBarStyles[iconIndex].file)

        do {
            try FileManager.default.createDirectory(at: installedDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try result.xml.write(to: targetURL, atomically: true, encoding: .utf8)

            let iconTargetName = result.filename.replacingOccurrences(of: ".keylayout", with: ".icns")
            let iconTargetURL = installedDir.appendingPathComponent(iconTargetName)
            if let iconURL = iconURL {
                if FileManager.default.fileExists(atPath: iconTargetURL.path) {
                    try FileManager.default.removeItem(at: iconTargetURL)
                }
                try FileManager.default.copyItem(at: iconURL, to: iconTargetURL)
            }

            let alert = NSAlert()
            alert.messageText = "Layout Installed! 🎉"
            alert.informativeText = "Installed \(result.filename) to ~/Library/Keyboard Layouts.\n\nNext: Log out and back into macOS, then add it in System Settings > Keyboard > Input Sources (+ > Others)."
            alert.beginSheetModal(for: sheet) { _ in
                self.window.endSheet(sheet)
                self.refreshStatus()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Install Failed"
            alert.informativeText = error.localizedDescription
            alert.beginSheetModal(for: sheet, completionHandler: nil)
        }
    }

    @objc func openInUkeleleAction(_ sender: NSButton) {
        guard let sheet = sender.window,
              let gen = objc_getAssociatedObject(sheet, "generateXML") as? () -> (xml: String, filename: String)?
        else { return }

        guard let result = gen() else { return }

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(result.filename)
        do {
            try result.xml.write(to: tempURL, atomically: true, encoding: .utf8)
            let ukeleleURL = URL(fileURLWithPath: "/Applications/Ukelele.app")
            NSWorkspace.shared.open([tempURL], withApplicationAt: ukeleleURL, configuration: NSWorkspace.OpenConfiguration()) { _, err in
                if let err = err {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Could Not Open in Ukelele"
                        alert.informativeText = err.localizedDescription
                        alert.beginSheetModal(for: sheet, completionHandler: nil)
                    }
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could Not Create Temporary File"
            alert.informativeText = error.localizedDescription
            alert.beginSheetModal(for: sheet, completionHandler: nil)
        }
    }

    func exportLayoutWithTool(inputSourceID: String?) -> String? {
        guard let toolURL = kluchrtoxmlURL else { return nil }

        var originalSource: TISInputSource?
        if let targetID = inputSourceID {
            let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
            originalSource = current
            let list = TISCreateInputSourceList(nil, false).takeRetainedValue() as! [TISInputSource]
            if let target = list.first(where: {
                if let idPtr = TISGetInputSourceProperty($0, kTISPropertyInputSourceID) {
                    return (Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String) == targetID
                }
                return false
            }) {
                TISEnableInputSource(target)
                TISSelectInputSource(target)
            }
        }

        defer {
            if let orig = originalSource {
                TISSelectInputSource(orig)
            }
        }

        let task = Process()
        task.executableURL = toolURL
        task.arguments = ["-k", "-s"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
