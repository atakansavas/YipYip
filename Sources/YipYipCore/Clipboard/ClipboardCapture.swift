import AppKit
import Foundation

/// One pasteboard snapshot, already reduced to the bytes YipYip stores and
/// the text it shows. `data` is what gets encrypted, and what is written back
/// to the pasteboard when the item is used again.
public struct ClipboardCapture: Sendable, Equatable {
    public let data: Data
    public let contentType: ClipboardItem.ContentType
    public let preview: String

    public init(data: Data, contentType: ClipboardItem.ContentType, preview: String) {
        self.data = data
        self.contentType = contentType
        self.preview = preview
    }

    /// Images are stored inline, so an oversized screenshot would otherwise bloat
    /// the database. Anything larger is skipped rather than truncated.
    public static let maxImageBytes = 8 * 1024 * 1024

    /// Reads the richest representation the pasteboard offers.
    ///
    /// Order matters: a file copied in Finder also carries its path as a string,
    /// and an image dragged from a browser can carry both PNG and TIFF.
    public static func read(from pasteboard: NSPasteboard) -> ClipboardCapture? {
        if let files = fileCapture(pasteboard) { return files }
        if let image = imageCapture(pasteboard) { return image }
        return textCapture(pasteboard)
    }

    /// Writes stored content back to a pasteboard in its original form — the
    /// inverse of `read(from:)`, so what was copied is what gets pasted.
    ///
    /// The caller must outlive the paste: file URLs are written as promises that
    /// the receiving app pulls from this process.
    @discardableResult
    public static func restore(
        data: Data,
        contentType: ClipboardItem.ContentType,
        to pasteboard: NSPasteboard
    ) -> Bool {
        pasteboard.clearContents()

        switch contentType {
        case .image:
            return pasteboard.setData(data, forType: .png)

        case .fileReference:
            let urls = fileURLs(from: data)
            guard !urls.isEmpty else { return false }
            return pasteboard.writeObjects(urls as [NSURL])

        case .plainText, .richText, .url:
            guard let string = String(data: data, encoding: .utf8) else { return false }
            return pasteboard.setString(string, forType: .string)
        }
    }

    /// The file URLs encoded in a `.fileReference` item's data.
    public static func fileURLs(from data: Data) -> [URL] {
        guard let joined = String(data: data, encoding: .utf8) else { return [] }
        return joined
            .split(separator: "\n")
            .compactMap { URL(string: String($0)) }
    }

    // MARK: - File references

    private static func fileCapture(_ pasteboard: NSPasteboard) -> ClipboardCapture? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty
        else { return nil }

        // Only the references are stored — copying a 4 GB video must not copy
        // 4 GB into the history database.
        let joined = urls.map(\.absoluteString).joined(separator: "\n")
        return ClipboardCapture(
            data: Data(joined.utf8),
            contentType: .fileReference,
            preview: filePreview(for: urls)
        )
    }

    private static func filePreview(for urls: [URL]) -> String {
        let names = urls.map { $0.lastPathComponent }
        guard names.count > 1 else { return names[0] }
        return "\(names.count) files · " + names.joined(separator: ", ")
    }

    // MARK: - Images

    private static func imageCapture(_ pasteboard: NSPasteboard) -> ClipboardCapture? {
        guard let png = pngData(from: pasteboard), png.count <= maxImageBytes else { return nil }

        var preview = "Image"
        if let rep = NSBitmapImageRep(data: png) {
            preview += " · \(rep.pixelsWide)×\(rep.pixelsHigh)"
        }
        preview += " · " + ByteCountFormatter.string(fromByteCount: Int64(png.count), countStyle: .file)

        return ClipboardCapture(data: png, contentType: .image, preview: preview)
    }

    /// Normalises whatever image flavour is on the pasteboard to PNG, so there is
    /// a single format to store, hash, and write back.
    private static func pngData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) { return png }

        if let tiff = pasteboard.data(forType: .tiff) {
            return png(fromTIFF: tiff)
        }

        // JPEG, HEIC, PDF-backed images: let NSImage decode whatever flavour the
        // source app offered rather than only accepting the two common ones.
        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation
        else { return nil }
        return png(fromTIFF: tiff)
    }

    private static func png(fromTIFF tiff: Data) -> Data? {
        NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }

    // MARK: - Text

    private static func textCapture(_ pasteboard: NSPasteboard) -> ClipboardCapture? {
        guard let string = plainString(from: pasteboard) else { return nil }

        return ClipboardCapture(
            data: Data(string.utf8),
            contentType: isWebURL(string) ? .url : .plainText,
            preview: String(string.prefix(500))
        )
    }

    private static func plainString(from pasteboard: NSPasteboard) -> String? {
        if let string = nonBlank(pasteboard.string(forType: .string)) { return string }

        // Some editors put only rich text on the pasteboard. Read the text out of
        // it rather than dropping the copy entirely.
        if let rtf = pasteboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil),
           let string = nonBlank(attributed.string) {
            return string
        }
        if let rtfd = pasteboard.data(forType: .rtfd),
           let attributed = NSAttributedString(rtfd: rtfd, documentAttributes: nil),
           let string = nonBlank(attributed.string) {
            return string
        }
        return nil
    }

    private static func nonBlank(_ string: String?) -> String? {
        guard let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return string
    }

    private static func isWebURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased()
        else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }
}
