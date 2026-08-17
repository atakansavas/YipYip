import AppKit
import Foundation
import Testing
@testable import YipYipCore

@Suite("ClipboardCapture")
@MainActor
struct ClipboardCaptureTests {
    private func pasteboard() -> NSPasteboard {
        let board = NSPasteboard(name: NSPasteboard.Name("yipyip-test-\(UUID().uuidString)"))
        board.clearContents()
        return board
    }

    private func pngData(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    @Test("Plain text is captured as text")
    func plainText() {
        let board = pasteboard()
        board.setString("hello clipboard", forType: .string)

        let capture = ClipboardCapture.read(from: board)
        #expect(capture?.contentType == .plainText)
        #expect(capture?.preview == "hello clipboard")
        #expect(capture.map { String(data: $0.data, encoding: .utf8) } == "hello clipboard")
    }

    @Test("Web links are captured as URLs")
    func webURL() {
        let board = pasteboard()
        board.setString("https://example.com/path", forType: .string)

        #expect(ClipboardCapture.read(from: board)?.contentType == .url)
    }

    @Test("Text that merely looks link-ish stays text")
    func notAURL() {
        let board = pasteboard()
        board.setString("see https://example.com for details", forType: .string)

        #expect(ClipboardCapture.read(from: board)?.contentType == .plainText)
    }

    @Test("Blank text is ignored")
    func blankText() {
        let board = pasteboard()
        board.setString("   \n ", forType: .string)

        #expect(ClipboardCapture.read(from: board) == nil)
    }

    @Test("Images are stored as PNG with a descriptive preview")
    func image() {
        let board = pasteboard()
        let png = pngData(width: 40, height: 25)
        board.setData(png, forType: .png)

        let capture = ClipboardCapture.read(from: board)
        #expect(capture?.contentType == .image)
        #expect(capture?.data == png)
        #expect(capture?.preview.contains("40×25") == true)
    }

    @Test("TIFF-only images are converted to PNG")
    func tiffImage() throws {
        let board = pasteboard()
        let rep = try #require(NSBitmapImageRep(data: pngData(width: 12, height: 12)))
        board.setData(try #require(rep.tiffRepresentation), forType: .tiff)

        let capture = try #require(ClipboardCapture.read(from: board))
        #expect(capture.contentType == .image)
        #expect(NSBitmapImageRep(data: capture.data) != nil)
    }

    @Test("Copied files are stored as references, not contents")
    func fileReference() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yipyip-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let movie = dir.appendingPathComponent("holiday.mov")
        // Stand-in for a large video: the capture must not contain these bytes.
        try Data(repeating: 7, count: 512_000).write(to: movie)

        let board = pasteboard()
        board.writeObjects([movie as NSURL])

        let capture = try #require(ClipboardCapture.read(from: board))
        #expect(capture.contentType == .fileReference)
        #expect(capture.preview == "holiday.mov")
        #expect(capture.data.count < 1000)
        #expect(String(data: capture.data, encoding: .utf8) == movie.absoluteString)
    }

    @Test("Multiple files are summarised")
    func multipleFiles() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yipyip-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = dir.appendingPathComponent("a.png")
        let second = dir.appendingPathComponent("b.mov")
        try Data("a".utf8).write(to: first)
        try Data("b".utf8).write(to: second)

        let board = pasteboard()
        board.writeObjects([first as NSURL, second as NSURL])

        let capture = try #require(ClipboardCapture.read(from: board))
        #expect(capture.preview == "2 files · a.png, b.mov")
        #expect(String(data: capture.data, encoding: .utf8)?.split(separator: "\n").count == 2)
    }

    @Test("A file copied from Finder wins over its path string")
    func filePreferredOverString() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yipyip-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("report.pdf")
        try Data("pdf".utf8).write(to: file)

        let board = pasteboard()
        board.writeObjects([file as NSURL])
        board.setString(file.path, forType: .string)

        #expect(ClipboardCapture.read(from: board)?.contentType == .fileReference)
    }

    @Test("An image survives capture and restore unchanged")
    func imageRoundTrip() throws {
        let source = pasteboard()
        source.setData(pngData(width: 30, height: 20), forType: .png)
        let capture = try #require(ClipboardCapture.read(from: source))

        let target = pasteboard()
        #expect(ClipboardCapture.restore(data: capture.data, contentType: capture.contentType, to: target))

        let restored = try #require(ClipboardCapture.read(from: target))
        #expect(restored.contentType == .image)
        #expect(restored.data == capture.data)
    }

    @Test("Files are restored as real file references, not as text")
    func fileRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yipyip-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let movie = dir.appendingPathComponent("clip.mov")
        try Data("movie".utf8).write(to: movie)

        let source = pasteboard()
        source.writeObjects([movie as NSURL])
        let capture = try #require(ClipboardCapture.read(from: source))

        let target = pasteboard()
        #expect(ClipboardCapture.restore(data: capture.data, contentType: capture.contentType, to: target))

        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = target.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        #expect(urls?.map(\.lastPathComponent) == ["clip.mov"])
    }

    @Test("Text is restored as text")
    func textRoundTrip() throws {
        let source = pasteboard()
        source.setString("round trip", forType: .string)
        let capture = try #require(ClipboardCapture.read(from: source))

        let target = pasteboard()
        #expect(ClipboardCapture.restore(data: capture.data, contentType: capture.contentType, to: target))
        #expect(target.string(forType: .string) == "round trip")
    }

    @Test("Rich-text-only copies are still captured as text")
    func rtfOnly() throws {
        let board = pasteboard()
        let attributed = NSAttributedString(
            string: "biçimli metin",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        let rtf = try #require(attributed.rtf(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [:]
        ))
        board.setData(rtf, forType: .rtf)

        let capture = try #require(ClipboardCapture.read(from: board))
        #expect(capture.contentType == .plainText)
        #expect(capture.preview == "biçimli metin")
    }

    @Test("JPEG-only images are captured and normalised to PNG")
    func jpegOnly() throws {
        let board = pasteboard()
        let rep = try #require(NSBitmapImageRep(data: pngData(width: 20, height: 10)))
        let jpeg = try #require(rep.representation(using: .jpeg, properties: [:]))
        board.setData(jpeg, forType: NSPasteboard.PasteboardType("public.jpeg"))

        let capture = try #require(ClipboardCapture.read(from: board))
        #expect(capture.contentType == .image)
        #expect(capture.data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))  // PNG magic
    }

    @Test("Oversized images are skipped")
    func oversizedImage() {
        let board = pasteboard()
        board.setData(Data(repeating: 0, count: ClipboardCapture.maxImageBytes + 1), forType: .png)

        #expect(ClipboardCapture.read(from: board) == nil)
    }
}
