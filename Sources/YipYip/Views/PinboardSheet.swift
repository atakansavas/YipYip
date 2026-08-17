import YipYipCore
import SwiftUI

struct PinboardSheet: View {
    @Bindable var state: AppState
    let item: ClipboardItem
    @State private var newBoardName: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Header.
                HStack {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.orange)
                    Text("Pin to board")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().opacity(0.3)

                // Existing boards.
                if !state.availablePinboards.isEmpty {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(state.availablePinboards, id: \.self) { board in
                                Button {
                                    state.togglePin(item, pinboard: board)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "folder")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                        Text(board)
                                            .font(.system(size: 13))
                                        Spacer()
                                        if item.pinboardName == board {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 160)

                    Divider().opacity(0.3)
                }

                // New board.
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("New board name...", text: $newBoardName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($inputFocused)
                        .onSubmit {
                            createAndPin()
                        }
                    if !newBoardName.isEmpty {
                        Button { createAndPin() } label: {
                            Text("Create")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Quick pin without board.
                Button {
                    state.togglePin(item)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "pin")
                            .font(.system(size: 12))
                        Text(item.isPinned ? "Unpin item" : "Pin without board")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.03))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 320)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        }
        .onAppear { inputFocused = state.availablePinboards.isEmpty }
    }

    private func createAndPin() {
        let name = newBoardName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        state.togglePin(item, pinboard: name)
        dismiss()
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            state.showPinSheet = false
            state.pinTargetItem = nil
        }
    }
}
