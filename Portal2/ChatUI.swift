import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: Store
    @State private var apiKey: String = "a"
    @State private var model: String = "gpt-4o-mini"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chats").font(.headline)
                Spacer()
                Button {
                    let t = Thread()
                    store.update { $0.insert(t, at: 0) }
                    store.selectedID = t.id
                } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            List(selection: $store.selectedID) {
                ForEach(store.threads) { t in
                    Text(t.title).tag(t.id as UUID?)
                }
                .onDelete { idx in store.update { $0.remove(atOffsets: idx) } }
            }

            Divider()
            HStack {
                SecureField("OpenAI API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Button("Save") { /*Keychain.set(apiKey)*/ }
                Spacer()
                Picker("Model", selection: $model) {
                    Text("gpt-4o-mini").tag("gpt-4o-mini")
                    Text("gpt-4o").tag("gpt-4o")
                }
                .pickerStyle(.menu)
            }
            .padding()
        }
        .frame(minWidth: 260)
        .environment(\._modelBinding, .constant(model))
    }
}

private struct ModelKey: EnvironmentKey { static let defaultValue: Binding<String> = .constant("gpt-4o-mini") }
extension EnvironmentValues { var _modelBinding: Binding<String> { get { self[ModelKey.self] } set { self[ModelKey.self] = newValue } } }

struct ChatContainerView: View {
    @EnvironmentObject var store: Store
    @Environment(\._modelBinding) var modelBinding
    @State private var apiKey: String = "a" //Keychain.get()

    var body: some View {
        if let thread = store.selected {
            ChatView(thread: thread, model: modelBinding.wrappedValue, apiKey: apiKey)
        } else {
            Text("Select or create a chat").foregroundStyle(.secondary)
        }
    }
}

struct ChatView: View {
    @EnvironmentObject var store: Store
    var thread: Thread
    var model: String
    var apiKey: String

    @State private var input = ""
    @State private var pendingImages: [String] = []
    @State private var isStreaming = false

    // Keep the logic out of `body`
    private var sendDisabled: Bool {
        (input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty)
        || apiKey.isEmpty
        || isStreaming
    }

    var body: some View {
        VStack(spacing: 0) {
            MessagesList(
                messages: thread.messages,
                isStreaming: isStreaming
            )

            Divider()

            ComposerBar(
                input: $input,
                pendingImages: $pendingImages,
                sendDisabled: sendDisabled,
                onAttach: attachScreenshot,
                onSend: send
            )
            .padding()
        }
        .navigationTitle(thread.title)
    }

    // MARK: - Actions

    private func attachScreenshot() {
        do {
            if let dataURL = try ScreenshotHelper.captureInteractivePNG() {
                pendingImages.append(dataURL)
            }
        } catch {
            print("Screenshot capture failed: \(error)")
        }
    }

    private func send() {
        guard !apiKey.isEmpty else { return }
        var t = thread

        let user = Message(
            role: .user,
            text: input.trimmingCharacters(in: .whitespacesAndNewlines),
            imageDataUrls: pendingImages
        )
        t.messages.append(user)
        t.updatedAt = .init()
        if t.title == "New Chat", let text = user.text, !text.isEmpty {
            t.title = String(text.prefix(60))
        }
        store.selected = t

        input = ""
        pendingImages = []
        isStreaming = true

        let limited = limitHistory(t.messages, keepTurns: 8)

        let client = OpenAIClient(apiKey: apiKey)
        client.model = model

        client.streamChat(history: limited, onDelta: { delta in
            DispatchQueue.main.async {
                var cur = store.selected ?? t
                if cur.messages.last?.role != .assistant {
                    cur.messages.append(Message(role: .assistant, text: ""))
                }
                cur.messages[cur.messages.count - 1].text = (cur.messages.last?.text ?? "") + delta
                cur.updatedAt = .init()
                store.selected = cur
            }
        }, onDone: { err in
            DispatchQueue.main.async { isStreaming = false }
            if let e = err {
                DispatchQueue.main.async {
                    var cur = store.selected ?? t
                    if cur.messages.last?.role == .assistant {
                        cur.messages[cur.messages.count - 1].text = (cur.messages.last?.text ?? "") + "\n\n❌ \(e.localizedDescription)"
                    } else {
                        cur.messages.append(Message(role: .assistant, text: "❌ \(e.localizedDescription)"))
                    }
                    cur.updatedAt = .init()
                    store.selected = cur
                }
            }
        })
    }

    private func limitHistory(_ msgs: [Message], keepTurns: Int) -> [Message] {
        let sys = msgs.filter { $0.role == .system }
        let ua = msgs.filter { $0.role != .system }
        let tail = ua.suffix(keepTurns * 2)
        return sys + tail
    }
}

struct MessageBubble: View {
    let message: Message

    private var headerText: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Assistant"
        case .system: return "System"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let text = message.text, !text.isEmpty {
                Text(text).textSelection(.enabled)
            }

            if !message.imageDataUrls.isEmpty {
                ImageStrip(urls: message.imageDataUrls)
            }
        }
        .padding(12)
        .background(message.role == .user ? Color.blue.opacity(0.08) : Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .id(message.id)
    }
}

struct ImageStrip: View {
    let urls: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                    ImageThumb(dataURL: url)
                }
            }
        }
        .frame(height: 130)
    }
}

struct ImageThumb: View {
    let dataURL: String
    var body: some View {
        if let img = decode(dataURL: dataURL) {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        } else {
            Text("image")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 160, height: 120)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }
    private func decode(dataURL: String) -> NSImage? {
        let prefix = "data:image/png;base64,"
        let base64 = dataURL.hasPrefix(prefix) ? String(dataURL.dropFirst(prefix.count)) : dataURL
        guard let data = Data(base64Encoded: base64) else { return nil }
        return NSImage(data: data)
    }
}

/// Message list split out so `body` stays simple
struct MessagesList: View {
    let messages: [Message]
    let isStreaming: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { m in
                        MessageBubble(message: m).id(m.id)
                    }
                    if isStreaming {
                        Text("Assistant is typing…")
                            .italic()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            // macOS 14+ deprecation-safe onChange
            .onChange(of: messages.count) {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}


struct ComposerBar: View {
    @Binding var input: String
    @Binding var pendingImages: [String]
    let sendDisabled: Bool
    let onAttach: () -> Void
    let onSend: () -> Void
    
    private let gap: CGFloat = 8
    private let btnSize: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Button(action: onAttach) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: btnSize, height: btnSize) // centers the glyph
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                TextField("Message…", text: $input, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .frame(width: btnSize, height: btnSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(sendDisabled || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, gap)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            )

            if !pendingImages.isEmpty {
                Text("Attached: \(pendingImages.count) screenshot(s)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
