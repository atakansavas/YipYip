import Foundation
import Testing
@testable import YipYipCore

@Suite("UpdateChecker")
struct UpdateCheckerTests {
    private func releaseJSON(tag: String) -> Data {
        Data("""
        {
          "tag_name": "\(tag)",
          "html_url": "https://github.com/atakansavas/YipYip/releases/tag/\(tag)",
          "body": "Bug fixes."
        }
        """.utf8)
    }

    private func checker(returning data: Data) -> UpdateChecker {
        UpdateChecker(repository: "atakansavas/YipYip", fetch: { _ in data })
    }

    @Test("Versions compare numerically, not alphabetically")
    func versionOrdering() throws {
        let ten = try #require(AppVersion("1.10.0"))
        let nine = try #require(AppVersion("1.9.0"))
        #expect(ten > nine)  // "1.10.0" < "1.9.0" as strings — the trap this guards
        #expect(try #require(AppVersion("2.0.0")) > ten)
        #expect(try #require(AppVersion("1.0.1")) > #require(AppVersion("1.0.0")))
    }

    @Test("Tag formats GitHub actually produces are parsed", arguments: [
        ("v1.2.3", "1.2.3"),
        ("1.2.3", "1.2.3"),
        ("V2.0", "2.0.0"),
        ("3", "3.0.0"),
        ("1.4.0-beta.2", "1.4.0"),
    ])
    func tagParsing(tag: String, expected: String) throws {
        #expect(try #require(AppVersion(tag)).description == expected)
    }

    @Test("Nonsense tags are rejected")
    func badTags() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("latest") == nil)
    }

    @Test("A newer release is reported as available")
    func updateAvailable() async throws {
        let result = try await checker(returning: releaseJSON(tag: "v1.1.0"))
            .check(currentVersion: "1.0.0")

        guard case .updateAvailable(let release) = result else {
            Issue.record("expected an update, got \(result)")
            return
        }
        #expect(release.version.description == "1.1.0")
        #expect(release.notes == "Bug fixes.")
    }

    @Test("The same or an older release means up to date")
    func upToDate() async throws {
        let same = try await checker(returning: releaseJSON(tag: "v1.0.0")).check(currentVersion: "1.0.0")
        #expect(same == .upToDate(current: AppVersion("1.0.0")!))

        let older = try await checker(returning: releaseJSON(tag: "v0.9.0")).check(currentVersion: "1.0.0")
        #expect(older == .upToDate(current: AppVersion("1.0.0")!))
    }

    @Test("A repository with no releases surfaces a clear error")
    func noReleases() async {
        let empty = Data(#"{"message": "Not Found"}"#.utf8)
        await #expect(throws: UpdateCheckError.noPublishedRelease) {
            try await checker(returning: empty).check(currentVersion: "1.0.0")
        }
    }

    @Test("Malformed responses do not crash the check")
    func malformed() async {
        await #expect(throws: (any Error).self) {
            try await checker(returning: Data("not json".utf8)).check(currentVersion: "1.0.0")
        }
    }
}
