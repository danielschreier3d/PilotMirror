import Foundation

@MainActor
final class LanguageService: ObservableObject {
    static let shared = LanguageService()

    @Published var isGerman: Bool {
        didSet { UserDefaults.standard.set(isGerman, forKey: "appIsGerman") }
    }

    private init() {
        // Default: German. If user has set a preference, use that.
        if let stored = UserDefaults.standard.object(forKey: "appIsGerman") as? Bool {
            self.isGerman = stored
        } else {
            self.isGerman = true
        }
    }

    /// Returns German or English string based on current language setting.
    func t(_ de: String, _ en: String) -> String {
        isGerman ? de : en
    }
}
