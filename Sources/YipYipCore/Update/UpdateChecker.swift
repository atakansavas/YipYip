import Foundation

/// A three-part version, compared numerically rather than as text — "1.10.0"
/// must sort above "1.9.0".
public struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    /// Accepts "1.2.3", "v1.2.3", and shorter forms like "1.2".
    public init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "v" || $0 == "V" })
        // Ignore any pre-release or build suffix: "1.2.3-beta.1" compares as 1.2.3.
        let core = trimmed.prefix(while: { $0.isNumber || $0 == "." })
        let parts = core.split(separator: ".").map(String.init)

        guard !parts.isEmpty, let major = Int(parts[0]) else { return nil }
        self.major = major
        self.minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        self.patch = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

public struct Release: Sendable, Equatable {
    public let version: AppVersion
    public let url: URL
    public let notes: String

    public init(version: AppVersion, url: URL, notes: String) {
        self.version = version
        self.url = url
        self.notes = notes
    }
}

public enum UpdateCheckResult: Sendable, Equatable {
    case upToDate(current: AppVersion)
    case updateAvailable(Release)
}

public enum UpdateCheckError: Error, LocalizedError, Sendable {
    case badResponse
    case noPublishedRelease

    public var errorDescription: String? {
        switch self {
        case .badResponse: "Could not read the release information from GitHub."
        case .noPublishedRelease: "No published release was found."
        }
    }
}

/// Checks GitHub Releases for a newer version.
///
/// The network call is injected so the logic is testable offline, and so the app
/// can guarantee this only ever runs when the user opted in — YipYip makes no
/// network requests otherwise.
public struct UpdateChecker: Sendable {
    public typealias Fetcher = @Sendable (URL) async throws -> Data

    private let repository: String
    private let fetch: Fetcher

    public init(repository: String = AppInfo.repository, fetch: @escaping Fetcher = UpdateChecker.load) {
        self.repository = repository
        self.fetch = fetch
    }

    public func check(currentVersion: String = AppInfo.version) async throws -> UpdateCheckResult {
        guard let current = AppVersion(currentVersion) else { throw UpdateCheckError.badResponse }

        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        let release = try Self.parse(try await fetch(url))

        return release.version > current ? .updateAvailable(release) : .upToDate(current: current)
    }

    static func parse(_ data: Data) throws -> Release {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UpdateCheckError.badResponse
        }
        // GitHub's "latest" endpoint already excludes drafts and prereleases, but
        // a repository with only those returns a message object instead.
        guard let tag = json["tag_name"] as? String,
              let version = AppVersion(tag),
              let link = json["html_url"] as? String,
              let url = URL(string: link)
        else {
            throw UpdateCheckError.noPublishedRelease
        }

        return Release(
            version: version,
            url: url,
            notes: (json["body"] as? String) ?? ""
        )
    }

    /// The real network call. Public only so it can serve as the default
    /// argument above; call `check(currentVersion:)` instead.
    public static func load(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppInfo.name)/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UpdateCheckError.badResponse
        }
        return data
    }
}
