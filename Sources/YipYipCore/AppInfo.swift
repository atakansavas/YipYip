import Foundation

/// Identity constants shared by the app and its tooling.
public enum AppInfo {
    /// The single source of truth for the version. `Scripts/build-app.sh` reads
    /// this line to stamp the bundle, and the app prefers the stamped value at
    /// runtime so a bundled build always reports what it actually shipped as.
    static let fallbackVersion = "1.0.0"

    public static let name = "YipYip"
    public static let bundleIdentifier = "com.benatakan.yipyip"
    public static let repository = "atakansavas/YipYip"

    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? fallbackVersion
    }

    public static var repositoryURL: URL {
        URL(string: "https://github.com/\(repository)")!
    }

    public static var releasesURL: URL {
        repositoryURL.appendingPathComponent("releases")
    }
}
