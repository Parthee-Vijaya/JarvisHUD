import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            MarkdownTextView(
                message.text,
                foregroundColor: message.role == .user ? .white : .white.opacity(0.95)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        message.role == .user
                            ? JarvisTheme.brightCyan.opacity(0.6)
                            : JarvisTheme.neonCyan.opacity(0.25),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: message.role == .user ? JarvisTheme.neonCyan.opacity(0.4) : .clear,
                radius: 6,
                y: 1
            )

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            JarvisTheme.userBubble
        } else {
            JarvisTheme.surfaceElevated.opacity(0.85)
        }
    }
}
