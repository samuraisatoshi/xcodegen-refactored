import Foundation

/// Supported locales for `--guide` output.
enum GuideLocale: String, CaseIterable {
    case en = "en"
    case ptBR = "pt-br"
    case es = "es"

    /// Infer locale from the `LANG` environment variable, falling back to `.en`.
    static var detected: GuideLocale {
        let lang = ProcessInfo.processInfo.environment["LANG"] ?? ""
        if lang.lowercased().hasPrefix("pt") { return .ptBR }
        if lang.lowercased().hasPrefix("es") { return .es }
        return .en
    }

    /// Parse from a CLI `--lang` value, falling back to `.detected`.
    static func resolve(_ value: String?) -> GuideLocale {
        guard let value else { return .detected }
        return GuideLocale(rawValue: value.lowercased()) ?? .detected
    }
}
