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
                ChatHeader(dialog: dialog)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

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
                .padding(.horizontal, 8)
                .padding(.bottom, 5)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
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
        Task {
            await store.loadMessages(for: dialog)
            await store.sendMessage(text)
        }
    }
}

private struct MessageDayGroup: Identifiable {
    let date: Date
    let messages: [MessageItem]

    var id: Date { date }

    var title: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ChatHeader: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    let dialog: DialogItem

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                    Text("4")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 23, height: 23)
                        .background(.white, in: Circle())
                        .foregroundStyle(.black)
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .frame(height: 46)
                .modifier(LiquidGlassCapsule())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(dialog.id == 1 ? "избранные сообщения" : "синхронизируется")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
            .frame(height: 46)
            .modifier(LiquidGlassCapsule())

            Spacer(minLength: 0)

            AvatarView(title: title, id: dialog.id, avatarUrl: store.streamerMode ? nil : dialog.avatarUrl)
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
    }

    private var title: String {
        store.streamerMode ? "Скрытый чат" : dialog.title
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
                    Text(store.streamerMode ? "Скрытый отправитель" : sender)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.telegramBlue)
                }

                Text(store.streamerMode ? "Сообщение скрыто" : message.text)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text(message.date.chatTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))

                    if message.outgoing {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.telegramBlue)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .modifier(MessageBubbleSurface(outgoing: message.outgoing, glass: store.liquidGlassMessages))
            .frame(maxWidth: 286, alignment: message.outgoing ? .trailing : .leading)

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
                content
                    .glassEffect(.regular.tint((outgoing ? Color.telegramBlue : Color.white).opacity(0.16)).interactive(), in: shape)
            } else {
                fallback(content: content, shape: shape)
            }
            #else
            fallback(content: content, shape: shape)
            #endif
        } else {
            content
                .background(outgoing ? Color.telegramBlue.opacity(0.85) : Color.qnolaChrome, in: shape)
                .overlay(shape.stroke(Color.white.opacity(outgoing ? 0.08 : 0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
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
                    .font(.system(size: 22, weight: .regular))
                    .frame(width: 46, height: 46)
                    .modifier(LiquidGlassCircle())
            }
            .foregroundStyle(.white.opacity(0.86))
            .disabled(true)

            TextField("Сообщение", text: $draft, axis: .vertical)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .frame(minHeight: 46)
                .modifier(LiquidGlassCapsule())
                .focused(isFocused)

            Button(action: onSend) {
                Image(systemName: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "paperplane.fill")
                    .font(.system(size: 23, weight: .regular))
                    .frame(width: 46, height: 46)
                    .modifier(LiquidGlassCircle())
                    .foregroundStyle(.white)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1)
        }
        .padding(.top, 8)
    }
}

struct LiquidGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(Color.white.opacity(0.10)).interactive(), in: Capsule())
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.13), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
    }
}

struct LiquidGlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(Color.white.opacity(0.10)).interactive(), in: Circle())
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.13), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
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
        Color.black
            .ignoresSafeArea()
    }
}

private extension Date {
    var chatTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
