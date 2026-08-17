import Foundation
import Testing
@testable import YipYipCore

@Suite("DataExporter")
struct DataExporterTests {

    @Test("Safe filename contains no special characters")
    func safeFilename() {
        let name = DataExporter.safeFilename(prefix: "my/export file!")
        #expect(!name.contains("/"))
        #expect(!name.contains("!"))
        #expect(name.hasSuffix(".json"))
    }

    @Test("Safe filename includes timestamp")
    func filenameTimestamp() {
        let name = DataExporter.safeFilename()
        // Format: yipyip-export_YYYY-MM-DD_HHMMSS.json
        #expect(name.contains("yipyip-export_"))
        #expect(name.count > 30) // has a timestamp
    }

    @Test("Export metadata round-trips")
    func exportMetadata() throws {
        let key = Data(repeating: 0xCC, count: 32)
        let enc = EncryptionManager(keyData: key)
        let items = [
            ClipboardItem(
                encryptedContent: try enc.encrypt(Data("test".utf8)),
                contentType: .plainText,
                preview: "test",
                contentHash: EncryptionManager.contentHash(Data("test".utf8))
            ),
        ]

        let data = try DataExporter.exportMetadata(items: items)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            [DataExporter.ExportableItem].self,
            from: data
        )
        #expect(decoded.count == 1)
        #expect(decoded[0].preview == "test")
    }

    @Test("Full export and import round-trip")
    func fullRoundTrip() throws {
        let key = Data(repeating: 0xDD, count: 32)
        let enc = EncryptionManager(keyData: key)
        let original = [
            ClipboardItem(
                encryptedContent: try enc.encrypt(Data("full test".utf8)),
                contentType: .url,
                preview: "full test",
                isPinned: true,
                pinboardName: "Work",
                contentHash: EncryptionManager.contentHash(Data("full test".utf8))
            ),
        ]

        let data = try DataExporter.exportFull(items: original)
        let imported = try DataExporter.importFull(data: data)

        #expect(imported.count == 1)
        #expect(imported[0].preview == "full test")
        #expect(imported[0].isPinned == true)
        #expect(imported[0].pinboardName == "Work")
        #expect(imported[0].contentType == .url)
    }

    @Test("Diagnostics report contains required fields")
    func diagnosticsReport() {
        let report = DataExporter.diagnosticsReport(
            itemCount: 42,
            dbPath: "/tmp/test.db",
            settingsPath: "/tmp/settings.json",
            accessibilityGranted: true
        )
        #expect(report.contains("42"))
        #expect(report.contains("/tmp/test.db"))
        #expect(report.contains("YipYip Diagnostics"))
        #expect(report.contains("macOS"))
    }

    @Test("Diagnostics report flags a missing Accessibility grant")
    func diagnosticsAccessibility() {
        let denied = DataExporter.diagnosticsReport(
            itemCount: 0,
            dbPath: "/tmp/test.db",
            settingsPath: "/tmp/settings.json",
            accessibilityGranted: false
        )
        // The single most common reason paste stops working, so it must be
        // obvious in the report rather than inferred.
        #expect(denied.contains("NOT GRANTED"))
    }
}
