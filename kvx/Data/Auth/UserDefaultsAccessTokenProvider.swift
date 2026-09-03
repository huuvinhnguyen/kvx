import Foundation

protocol AccessTokenProvider {
    var accessToken: String? { get }
}

struct UserDefaultsAccessTokenProvider: AccessTokenProvider {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var accessToken: String? {
        defaults.string(forKey: "binblog.accessToken")
    }
}