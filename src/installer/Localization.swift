import Cocoa

enum AppLanguage: String {
    case en = "en"
    case fr = "fr"
    
    var toggleTitle: String {
        switch self {
        case .en: return "🇫🇷 Français"
        case .fr: return "🇬🇧 English"
        }
    }
}

final class L10n {
    static var current: AppLanguage {
        get {
            let saved = UserDefaults.standard.string(forKey: "appLanguage")
            if let saved = saved, let lang = AppLanguage(rawValue: saved) {
                return lang
            }
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("fr") ? .fr : .en
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage")
        }
    }

    static var isFR: Bool { current == .fr }

    // MARK: - Localized Strings

    static var windowTitle: String {
        isFR ? "Installateur AZERTY Digits" : "AZERTY Digits Installer"
    }

    static var subtitle: String {
        isFR
            ? "Chiffres accessibles directement sur la rangée supérieure sans Shift ni Verrouillage Majuscule. Touches Option, Option+Shift et le reste de la disposition Apple restent inchangés."
            : "Digits on the number row without Shift or Caps Lock. Option, Option+Shift and the rest of Apple's French layout are unchanged."
    }

    static var menuBarIconLabel: String {
        isFR ? "Icône barre des menus" : "Menu Bar Icon"
    }

    static var menuBarIconSubtitle: String {
        isFR ? "Choisissez le badge affiché dans la barre des menus de macOS." : "Choose the badge shown in your macOS menu bar."
    }

    static var alwaysDarkIcon: String {
        isFR ? "Toujours utiliser l'icône sombre (badge noir)" : "Always use dark icon (black badge)"
    }

    static var layoutLabel: String {
        isFR ? "Disposition :" : "Layout:"
    }

    static var otherLayout: String {
        isFR ? "Autre disposition..." : "Other Layout..."
    }

    static var previewLegend: String {
        isFR
            ? "Les touches en surbrillance tapent les chiffres par défaut sans Shift. Maintenez Shift pour les symboles standards."
            : "Highlighted keys type digits by default without Shift. Hold Shift to access standard symbols."
    }

    static var installAllUsers: String {
        isFR
            ? "Installer pour tous les utilisateurs (Écran de verrouillage & Session)"
            : "Install for all users (Lock screen & Login window)"
    }

    static var allUsersHelp: String {
        isFR
            ? "Requis pour saisir des chiffres sans Shift sur l'écran de verrouillage et à l'ouverture de session (codes PIN, mots de passe). S'installe dans /Library/Keyboard Layouts/ avec privilèges administrateur."
            : "Required if you want this layout to be used on the lock screen and login window (e.g. typing digits in password or PIN codes without Shift). Installs to /Library/Keyboard Layouts/ with administrator privileges."
    }

    static var toggleUnderscore: String {
        isFR ? "Inclure _ sur la rangée des chiffres (touche 24)" : "Include _ on the number row (key 24)"
    }

    static var underscoreHelp: String {
        isFR
            ? "Désactivé : touche 24 tape - sans Shift et _ avec Shift.\nActivé : touche 24 tape _ sans Shift, et Shift donne toujours _."
            : "Off: key 24 types - without Shift and _ with Shift.\nOn: key 24 types _ without Shift, and Shift still gives _."
    }

    static var toggleDegree: String {
        isFR ? "Inclure ° sur la rangée des chiffres (touche 27)" : "Include ° on the number row (key 27)"
    }

    static var degreeHelp: String {
        isFR
            ? "Désactivé : touche 27 tape ) sans Shift et ° avec Shift.\nActivé : touche 27 tape ° sans Shift et ) avec Shift, afin que ( et ) soient au même niveau Shift."
            : "Off: key 27 types ) without Shift and ° with Shift, so ( and ) end up on different Shift levels.\nOn: key 27 types ° without Shift and ) with Shift, so ( and ) share the Shift level."
    }

    static var optionsTitle: String {
        isFR ? "Options de la disposition" : "Layout Options"
    }

    static var installButton: String {
        isFR ? "Installer" : "Install"
    }

    static var updateButton: String {
        isFR ? "Mettre à jour" : "Update"
    }

    static var uninstallButton: String {
        isFR ? "Désinstaller" : "Uninstall"
    }

    static var keyboardSettingsButton: String {
        isFR ? "Ouvrir Réglages Clavier" : "Open Keyboard Settings"
    }

    static var checkUpdatesButton: String {
        isFR ? "Rechercher des mises à jour" : "Check for Updates"
    }

    static var supportButton: String {
        isFR ? "☕ Soutenir sur Ko-fi" : "☕ Support on Ko-fi"
    }

    static var nextStepsNote: String {
        isFR
            ? "💡 Étapes suivantes : Après l'installation ou mise à jour, fermez votre session ou redémarrez, puis ajoutez AZERTY Digits dans Réglages Système > Clavier > Méthodes de saisie (+ > Autres). macOS n'autorise pas les applications à activer les dispositions automatiquement."
            : "💡 Next steps: After install or update, log out and back in, then add AZERTY Digits in System Settings > Keyboard > Input Sources (+ > Others). macOS doesn't let apps add input sources for you."
    }

    static var releaseNotesButton: String {
        isFR ? "Notes de version" : "Release Notes"
    }

    static var updateNowButton: String {
        isFR ? "Mettre à jour maintenant" : "Update Now"
    }

    static func iconSubtitleForStyle(file: String) -> String {
        switch file {
        case "fr": return isFR ? "France (2 lettres)" : "France (2 letters)"
        case "be": return isFR ? "Belgique (2 lettres)" : "Belgium (2 letters)"
        case "f":  return isFR ? "France (1 lettre)" : "France (1 letter)"
        case "b":  return isFR ? "Belgique (1 lettre)" : "Belgium (1 letter)"
        case "app": return isFR ? "Icône AZERTY Digits" : "AZERTY Digits App Icon"
        case "lu": return isFR ? "Luxembourg (2 lettres)" : "Luxembourg (2 letters)"
        case "l":  return isFR ? "Luxembourg (1 lettre)" : "Luxembourg (1 letter)"
        case "ma": return isFR ? "Maroc (2 lettres)" : "Morocco (2 letters)"
        case "m":  return isFR ? "Maroc (1 lettre)" : "Morocco (1 letter)"
        case "dz": return isFR ? "Algérie (2 lettres)" : "Algeria (2 letters)"
        case "d":  return isFR ? "Algérie (1 lettre)" : "Algeria (1 letter)"
        case "dg": return isFR ? "Chiffres (DG)" : "Digits"
        case "123": return isFR ? "Numérique (123)" : "Numeric"
        case "frpc": return isFR ? "Français PC" : "French PC"
        default: return ""
        }
    }
}

extension L10n {
    static func statusInstalledSystem(ver: String) -> String {
        isFR
            ? "Disposition installée (v\(ver)) pour tous les utilisateurs (/Library/Keyboard Layouts). Active sur l'écran de verrouillage."
            : "Keyboard layout: installed (v\(ver)) for all users (/Library/Keyboard Layouts). Available on lock screen."
    }

    static func statusInstalledUser(ver: String) -> String {
        isFR
            ? "Disposition installée (v\(ver)) dans ~/Library/Keyboard Layouts (Utilisateur actuel uniquement)."
            : "Keyboard layout: installed (v\(ver)) at ~/Library/Keyboard Layouts (Current user only)."
    }

    static var statusNotInstalled: String {
        isFR ? "Disposition non installée." : "Keyboard layout: not installed."
    }

    static func statusSelectedLayout(name: String) -> String {
        isFR
            ? "Disposition sélectionnée : \(name). Cliquez sur Installer ou Mettre à jour."
            : "Selected layout: \(name). Click Install/Update to apply."
    }

    static var statusInstallAllSelected: String {
        isFR
            ? "Installation pour tous les utilisateurs sélectionnée. Cliquez sur Installer ou Mettre à jour (mot de passe administrateur requis)."
            : "Install for all users selected. Click Install or Update (requires admin password)."
    }

    static var statusInstallUserSelected: String {
        isFR
            ? "Installation pour l'utilisateur actuel sélectionnée. Cliquez sur Installer ou Mettre à jour."
            : "Install for current user selected. Click Install or Update."
    }

    static var statusClickUpdateToApply: String {
        isFR
            ? "Cliquez sur Mettre à jour pour appliquer les nouveaux symboles."
            : "Click Update to apply the new symbols."
    }

    static var statusAlreadyInstalled: String {
        isFR
            ? "Déjà installé. Utilisez Mettre à jour pour actualiser."
            : "Already installed. Use Update to refresh it."
    }

    static var statusRemoved: String {
        isFR
            ? "Désinstallé. Supprimez également AZERTY Digits des Méthodes de saisie si toujours listé."
            : "Removed. Also remove AZERTY Digits from Input Sources if it's still listed."
    }

    static var statusNothingToRemove: String {
        isFR ? "Rien à désinstaller." : "Nothing to remove."
    }

    static func statusActionSuccessSystem(action: String, name: String, ver: String) -> String {
        let localizedAction = isFR ? (action == "Installed" ? "Installé" : "Mis à jour") : action
        return isFR
            ? "\(localizedAction) \(name) (v\(ver)) pour tous les utilisateurs (/Library). Disponible sur l'écran de verrouillage !"
            : "\(action) \(name) (v\(ver)) for all users (/Library). Available on lock screen!"
    }

    static func statusActionSuccessUser(action: String, name: String, ver: String) -> String {
        let localizedAction = isFR ? (action == "Installed" ? "Installé" : "Mis à jour") : action
        return isFR
            ? "\(localizedAction) \(name) (v\(ver)) dans ~/Library/Keyboard Layouts."
            : "\(action) \(name) (v\(ver)) at ~/Library/Keyboard Layouts."
    }
}
