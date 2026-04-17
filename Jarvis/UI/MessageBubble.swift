import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            MarkdownTextView(
                message.text,
                foregroundColor: message.role == .user ? .white : .primary
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(.tint)
        } else {
            return AnyShapeStyle(.quaternary)
        }
    }
}
