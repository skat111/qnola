import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var store: SessionStore
    let dialog: DialogItem
    @State private var draft = ""
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        ZStack {
            ChatBackground()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(groupedMessages) { group in
                                MessageDayHeader(title: group.title)

                                ForEach(group.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.messages.count) {
                        if let last = store.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = store.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                ChatComposer(draft: $draft, isFocused: $isComposerFocused) {
                    sendDraft()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatTitleView(dialog: dialog)
            }
        }
        .task {
            await store.loadMessages(for: dialog)
        }
    }

    private var groupedMessages: [MessageDayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: store.messages) { message in
            calendar.startOfDay(for: message.date)
        }
        return groups
            .map { key, value in
                MessageDayGroup(date: key, messages: value.sorted { $0.date < $1.date })
            }
            .sorted { $0.date < $1.date }
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        Task { await store.sendMessage(text) }
    }
}

private struct MessageDayGroup: Identifiable {
    let date: Date
    let messages: [MessageItem]

    var id: Date { date }

    var title: String {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ChatTitleView: View {
    @EnvironmentObject private var store: SessionStore
    let dialog: DialogItem

    var body: some View {
        HStack(spacing: 9) {
            AvatarView(title: title, id: dialog.id)
                .frame(width: 34, height: 34)
                .scaleEffect(34.0 / 52.0)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text("online")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.telegramBlue)
            }
        }
        .frame(maxWidth: 220, alignment: .leading)
    }

    private var title: String {
        store.streamerMode ? "Hidden Chat" : dialog.title
    }
}

struct MessageBubble: View {
    @EnvironmentObject private var store: SessionStore
    let message: MessageItem

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if message.outgoing {
                Spacer(minLength: 52)
            }

            VStack(alignment: message.outgoing ? .trailing : .leading, spacing: 3) {
                if !message.outgoing, let sender = message.senderName, !sender.isEmpty {
                    Text(store.streamerMode ? "Hidden Sender" : sender)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.telegramBlue)
                }

                Text(store.streamerMode ? "Message hidden" : message.text)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text(message.date.chatTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if message.outgoing {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.telegramBlue)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: 286, alignment: message.outgoing ? .trailing : .leading)
            .modifier(MessageBubbleSurface(outgoing: message.outgoing, glass: store.liquidGlassMessages))

            if !message.outgoing {
                Spacer(minLength: 52)
            }
        }
    }
}

struct MessageBubbleSurface: ViewModifier {
    let outgoing: Bool
    let glass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = TelegramBubbleShape(outgoing: outgoing)
        if glass {
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                if outgoing {
                    content
                        .glassEffect(.regular.tint(Color.white.opacity(0.24)).interactive(), in: .rect(cornerRadius: 18))
                } else {
                    content
                        .glassEffect(.regular.tint(Color.black.opacity(0.08)), in: .rect(cornerRadius: 18))
                }
            } else {
                fallback(content: content, shape: shape)
            }
            #else
            fallback(content: content, shape: shape)
            #endif
        } else {
            content
                .background(outgoing ? Color(red: 0.83, green: 0.94, blue: 0.76) : Color(.systemBackground), in: shape)
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        }
    }

    private func fallback(content: Content, shape: TelegramBubbleShape) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

struct TelegramBubbleShape: Shape {
    let outgoing: Bool

    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 6
        let radius: CGFloat = 18
        let body = outgoing
            ? CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
            : CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)

        var path = Path(roundedRect: body, cornerRadius: radius)
        if outgoing {
            path.move(to: CGPoint(x: body.maxX - 8, y: body.maxY - 10))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: body.maxY), control: CGPoint(x: body.maxX + 2, y: body.maxY - 1))
            path.addLine(to: CGPoint(x: body.maxX - 3, y: body.maxY - 2))
            path.closeSubpath()
        } else {
            path.move(to: CGPoint(x: body.minX + 8, y: body.maxY - 10))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: body.maxY), control: CGPoint(x: body.minX - 2, y: body.maxY - 1))
            path.addLine(to: CGPoint(x: body.minX + 3, y: body.maxY - 2))
            path.closeSubpath()
        }
        return path
    }
}

struct ChatComposer: View {
    @Binding var draft: String
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {} label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .frame(width: 34, height: 34)
            }
            .foregroundStyle(.secondary)
            .disabled(true)

            TextField("Message", text: $draft, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(1...5)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Color(.systemBackground), in: Capsule())
                .overlay {
                    Capsule().stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
                }
                .focused(isFocused)

            Button(action: onSend) {
                Image(systemName: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.telegramBlue, in: Circle())
                    .foregroundStyle(.white)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.65 : 1)
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 7)
        .background(.bar)
    }
}

struct MessageDayHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.22), in: Capsule())
            .padding(.vertical, 6)
    }
}

struct ChatBackground: View {
    var body: some View {
        Color(red: 0.89, green: 0.93, blue: 0.86)
            .overlay {
                GeometryReader { geometry in
                    Canvas { context, size in
                        let spacing: CGFloat = 34
                        for x in stride(from: CGFloat(0), through: size.width + spacing, by: spacing) {
                            for y in stride(from: CGFloat(0), through: size.height + spacing, by: spacing) {
                                let rect = CGRect(x: x, y: y, width: 2, height: 2)
                                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.28)))
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .ignoresSafeArea()
    }
}

private extension Date {
    var chatTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
