import AppKit
import SwiftUI

/// Left-edge drawer showing past conversations. v1.4 Fase 2c redesign mirrors
/// the Gemini macOS layout: search field at top, highlighted "Ny chat"
/// + "Mine ting" quick rows, "Chatsamtaler" section with the live list,
/// user avatar + full name anchored to the bottom. Hover a conversation to
/// reveal a trash icon (unchanged from v1.1.5).
struct ConversationSidebar: View {
    let conversations: [ConversationStore.Metadata]
    let currentID: UUID?
    let onSelect: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onClose: () -> Void
    /// v1.4: optional "Ny chat" handler — when present, the top quick row is
    /// wired to this. When nil (legacy callers) the row still renders but is
    /// disabled.
    var onNewChat: (() -> Void)? = nil

    @State private var hoveringID: UUID?
    @State private var searchText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerControls
            searchField
            quickRows
            sectionLabel("CHATSAMTALER")
            conversationList
            Spacer(minLength: 0)
            Divider().background(JarvisTheme.hairline)
            avatarFooter
        }
        .frame(width: 248)
        .background(JarvisTheme.surfaceBase.opacity(0.92))
    }

    // MARK: - Top controls (sidebar toggle)

    private var headerControls: some View {
        HStack(spacing: 8) {
            // Left side reserved for the system traffic lights on a window
            // that hosts its own titlebar; the chat panel is borderless so
            // we just pad.
            Spacer().frame(width: 70)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(JarvisTheme.textSecondary)
                    .frame(width: 26, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(JarvisTheme.surfaceElevated.opacity(0.8))
                    )
            }
            .buttonStyle(.plain)
            .help("Skjul sidebjælke")
            .accessibilityLabel("Skjul sidebjælke")
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(JarvisTheme.textMuted)
            TextField("Søg", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(JarvisTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(JarvisTheme.surfaceElevated.opacity(0.65))
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    // MARK: - Quick rows (Ny chat primary CTA, Mine ting)

    /// v1.4 Fase 2c polish: promote "Ny chat" to a proper primary action
    /// button — bigger, brand-accent-tinted, keyboard-shortcut-hinted. Sits
    /// directly under the search field so it's the first thing the eye
    /// catches when the sidebar opens.
    private var quickRows: some View {
        VStack(spacing: 6) {
            newChatButton
            mineTingRow
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 14)
    }

    private var newChatButton: some View {
        Button {
            onNewChat?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Ny chat")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("⌘N")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(JarvisTheme.textPrimary.opacity(0.6))
            }
            .foregroundStyle(JarvisTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(JarvisTheme.accent.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(JarvisTheme.accent.opacity(0.45), lineWidth: 0.75)
                    )
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
        .disabled(onNewChat == nil)
        .help("Ny samtale (⌘N)")
        .accessibilityLabel("Ny chat")
        .accessibilityHint("Starter en ny tom samtale")
    }

    private var mineTingRow: some View {
        Button(action: {}) {
            HStack(spacing: 10) {
                Image(systemName: "star")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(JarvisTheme.textMuted)
                    .frame(width: 18)
                Text("Mine ting")
                    .font(.system(size: 12))
                    .foregroundStyle(JarvisTheme.textMuted)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(true)
        .opacity(0.7)
        .accessibilityHidden(true)
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(JarvisTheme.textMuted)
            .padding(.horizontal, 18)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Conversation list

    @ViewBuilder
    private var conversationList: some View {
        if filteredConversations.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredConversations) { meta in
                        row(meta)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }

    private var filteredConversations: [ConversationStore.Metadata] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return conversations }
        return conversations.filter { $0.title.lowercased().contains(query) }
    }

    // MARK: - Row

    private func row(_ meta: ConversationStore.Metadata) -> some View {
        let isCurrent = meta.id == currentID
        let isHovering = hoveringID == meta.id

        return HStack(spacing: 6) {
            Button { onSelect(meta.id) } label: {
                Text(meta.title)
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? JarvisTheme.textPrimary : JarvisTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isCurrent ? JarvisTheme.surfaceElevated.opacity(0.9) :
                                  (isHovering ? JarvisTheme.surfaceElevated.opacity(0.4) : Color.clear))
                    )
            }
            .buttonStyle(.plain)

            if isHovering {
                Button { onDelete(meta.id) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(JarvisTheme.textMuted)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(JarvisTheme.surfaceElevated)
                        )
                }
                .buttonStyle(.plain)
                .help("Slet samtale")
                .accessibilityLabel("Slet samtale")
            }
        }
        .onHover { hovering in
            hoveringID = hovering ? meta.id : (hoveringID == meta.id ? nil : hoveringID)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 16))
                .foregroundStyle(JarvisTheme.textMuted)
            Text(searchText.isEmpty ? "Ingen tidligere samtaler" : "Ingen match")
                .font(.system(size: 11))
                .foregroundStyle(JarvisTheme.textMuted)
        }
        .padding(.top, 30)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Avatar footer

    /// Shows the user's nickname (default "P") next to a circular avatar.
    /// Kept short so the sidebar width stays tight — full name was too noisy
    /// in the Gemini reference layout and clashed with the short-nickname
    /// greeting ("Hej P") up top.
    private var avatarFooter: some View {
        HStack(spacing: 10) {
            avatar
            Text(Self.displayNickname)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(JarvisTheme.textPrimary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// Circular avatar with the user's first initial on a muted tint. v1.4
    /// Fase 2c swapped the earlier amber-gradient fill for a neutral
    /// surface-elevated background so the avatar doesn't compete visually
    /// with the brand-accent elements elsewhere.
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(JarvisTheme.surfaceElevated)
                .overlay(Circle().stroke(JarvisTheme.hairline, lineWidth: 0.5))
            Text(Self.displayNickname)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(JarvisTheme.textPrimary)
        }
        .frame(width: 28, height: 28)
    }

    /// User-preferred short nickname shown both on the avatar and the
    /// footer label. Hardcoded to "P" per user preference (2026-04-19);
    /// future Settings surface lets other users set their own.
    private static let displayNickname: String = "P"
}
