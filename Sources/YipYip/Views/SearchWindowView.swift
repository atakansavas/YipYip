import YipYipCore
import SwiftUI

struct SearchWindowView: View {
    @Bindable var state: AppState
    let onDismiss: () -> Void
    /// Closes the panel and pastes the pasteboard contents into the previous app.
    let onPaste: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var hoverIndex: Int? = nil
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            tabBar
            Divider().opacity(0.5)
            contentArea
            footerBar
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 40, y: 12)
        .frame(width: 680, height: 520)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.97)
        .onAppear {
            searchFocused = true
            state.refreshItems()
            withAnimation(.easeOut(duration: 0.2)) {
                appeared = true
            }
        }
        .overlay(alignment: .bottom) {
            toastOverlay
        }
        .overlay {
            if state.showPinSheet, let item = state.pinTargetItem {
                PinboardSheet(state: state, item: item)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onKeyPress(.escape) {
            if state.showPinSheet {
                state.showPinSheet = false
                return .handled
            }
            onDismiss()
            return .handled
        }
        .onKeyPress(.return) {
            pasteSelected()
            return .handled
        }
        .onKeyPress(.downArrow) {
            withAnimation(.easeOut(duration: 0.08)) {
                state.moveSelection(by: 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            withAnimation(.easeOut(duration: 0.08)) {
                state.moveSelection(by: -1)
            }
            return .handled
        }
        .onKeyPress(.tab) {
            withAnimation(.easeInOut(duration: 0.15)) {
                state.activeTab = state.activeTab == .all ? .pinned : .all
                state.selectedIndex = 0
                state.refreshItems()
            }
            return .handled
        }
        .onKeyPress(keys: [.delete], phases: .down) { _ in
            deleteSelected()
            return .handled
        }
        .onKeyPress(keys: ["p"], phases: .down) { press in
            if press.modifiers.contains(.command) {
                if let item = state.selectedItem {
                    state.beginPinning(item: item)
                }
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search clipboard history...", text: $state.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .light))
                .focused($searchFocused)
                .onChange(of: state.searchQuery) { _, _ in
                    state.selectedIndex = 0
                    state.refreshItems()
                }
                .onSubmit {
                    pasteSelected()
                }

            if !state.searchQuery.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        state.searchQuery = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Text("\(state.items.count)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.5))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(HistoryTab.allCases, id: \.self) { tab in
                let isActive = state.activeTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.activeTab = tab
                        state.selectedIndex = 0
                        state.refreshItems()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab == .all ? "clock.arrow.circlepath" : "pin.fill")
                            .font(.system(size: 10))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    }
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isActive ? .white.opacity(0.1) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("Tab to switch")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if state.isLoading {
            loadingView
        } else if let error = state.errorMessage {
            errorView(error)
        } else if state.items.isEmpty {
            emptyView
        } else {
            itemList
        }
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            isSelected: index == state.selectedIndex,
                            isHovered: hoverIndex == index,
                            shortcutNumber: index < 9 ? index + 1 : nil,
                            attachment: state.thumbnail(for: item) ?? state.fileIcon(for: item),
                            isMissingFile: item.contentType == .fileReference
                                && !state.filesExist(for: item),
                            onPaste: {
                                state.selectedIndex = index
                                pasteSelected()
                            },
                            onPin: {
                                if item.isPinned {
                                    state.togglePin(item)
                                } else {
                                    state.beginPinning(item: item)
                                }
                            },
                            onDelete: {
                                state.deleteItem(item)
                                if state.selectedIndex >= state.items.count {
                                    state.selectedIndex = max(0, state.items.count - 1)
                                }
                            }
                        )
                        .id(item.id)
                        .onHover { hovering in
                            hoverIndex = hovering ? index : nil
                        }
                        .onTapGesture(count: 2) {
                            state.selectedIndex = index
                            pasteSelected()
                        }
                        .onTapGesture(count: 1) {
                            withAnimation(.easeOut(duration: 0.08)) {
                                state.selectedIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: state.selectedIndex) { _, newIndex in
                if state.items.indices.contains(newIndex) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(state.items[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: state.activeTab == .pinned ? "pin.slash" : "clipboard")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))

            if state.searchQuery.isEmpty {
                if state.activeTab == .pinned {
                    Text("No pinned items")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Press \u{2318}P on any item to pin it")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No clipboard history yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Copy something to get started")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("No results for \"\(state.searchQuery)\"")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Try a different search term")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.orange)
            Text("Something went wrong")
                .font(.system(size: 15, weight: .medium))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                state.errorMessage = nil
                state.refreshItems()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 16) {
            shortcutHint(key: "\u{21A9}", label: "paste")
            shortcutHint(key: "\u{2318}P", label: "pin")
            shortcutHint(key: "\u{232B}", label: "delete")
            shortcutHint(key: "Tab", label: "switch")
            Spacer()
            shortcutHint(key: "esc", label: "close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    private func shortcutHint(key: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 10))
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = state.toastMessage {
            Text(msg)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.black.opacity(0.7))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: state.toastMessage)
        }
    }

    // MARK: - Actions

    private func pasteSelected() {
        guard let item = state.selectedItem else { return }
        // Skip the toast: the panel is closing, so it would never be seen.
        guard state.copyToClipboard(item: item, showToast: false) else { return }
        onPaste()
    }

    private func deleteSelected() {
        guard let item = state.selectedItem else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            state.deleteItem(item)
        }
    }
}
