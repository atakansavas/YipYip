import YipYipCore
import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isHovered: Bool
    let shortcutNumber: Int?
    /// Rendered preview for image and file items; nil for text.
    let attachment: NSImage?
    /// False when a file item points at something that has since been moved.
    let isMissingFile: Bool
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Shortcut number or type icon.
            ZStack {
                if let num = shortcutNumber, isSelected || isHovered {
                    Text("\u{2318}\(num)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                } else {
                    typeIcon
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? .primary : .tertiary)
                        .transition(.opacity)
                }
            }
            .frame(width: 28)
            .animation(.easeOut(duration: 0.12), value: isSelected)
            .animation(.easeOut(duration: 0.12), value: isHovered)

            attachmentPreview

            // Content.
            VStack(alignment: .leading, spacing: 3) {
                Text(item.preview)
                    .lineLimit(isSelected ? 3 : 1)
                    .font(.system(size: 13, weight: isSelected ? .regular : .regular))
                    .foregroundStyle(.primary.opacity(isSelected ? 1.0 : 0.85))
                    .truncationMode(.tail)
                    .animation(.easeOut(duration: 0.15), value: isSelected)

                HStack(spacing: 5) {
                    Text(formattedDate)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    if let app = item.sourceApp {
                        Circle()
                            .fill(.quaternary)
                            .frame(width: 2.5, height: 2.5)
                        Text(app)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    if isMissingFile {
                        Circle()
                            .fill(.quaternary)
                            .frame(width: 2.5, height: 2.5)
                        Text("missing")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.orange)
                    }

                    if item.isPinned {
                        HStack(spacing: 2) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                            if let board = item.pinboardName {
                                Text(board)
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .foregroundStyle(.orange)
                    }
                }
            }

            Spacer(minLength: 4)

            // Actions on hover/select.
            if isSelected || isHovered {
                HStack(spacing: 4) {
                    rowActionButton(icon: item.isPinned ? "pin.slash.fill" : "pin.fill", color: .orange) {
                        onPin()
                    }
                    rowActionButton(icon: "trash", color: .red) {
                        onDelete()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.easeOut(duration: 0.12), value: isSelected)
            }

            // Content type badge.
            Text(typeLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }

    private var backgroundColor: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(.white.opacity(0.12))
        } else if isHovered {
            return AnyShapeStyle(.white.opacity(0.05))
        }
        return AnyShapeStyle(.clear)
    }

    private func rowActionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 24, height: 24)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    /// Image items show the picture itself; file items show the Finder icon.
    @ViewBuilder
    private var attachmentPreview: some View {
        if let attachment {
            Image(nsImage: attachment)
                .resizable()
                .aspectRatio(contentMode: item.contentType == .image ? .fill : .fit)
                .frame(width: 38, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(.white.opacity(item.contentType == .image ? 0.12 : 0), lineWidth: 0.5)
                )
                .opacity(isMissingFile ? 0.45 : 1)
        }
    }

    @ViewBuilder
    private var typeIcon: some View {
        switch item.contentType {
        case .plainText: Image(systemName: "doc.text")
        case .richText: Image(systemName: "doc.richtext")
        case .image: Image(systemName: "photo")
        case .url: Image(systemName: "link")
        case .fileReference: Image(systemName: "doc")
        }
    }

    private var typeLabel: String {
        switch item.contentType {
        case .plainText: return "Text"
        case .richText: return "Rich"
        case .image: return "Image"
        case .url: return "URL"
        case .fileReference: return "File"
        }
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.createdAt, relativeTo: Date())
    }
}
