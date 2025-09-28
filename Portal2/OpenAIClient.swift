import Foundation

final class OpenAIClient {
    var apiKey: String
    var model = "gpt-4o-mini"

    init(apiKey: String) { self.apiKey = apiKey }

    struct Part: Codable {
        let type: String
        let text: String?
        let image_url: Img?
        struct Img: Codable { let url: String }
    }
    struct ChatMessage: Codable {
        let role: String
        let content: [Part]
    }
    struct ChatRequest: Codable {
        let model: String
        let stream: Bool
        let messages: [ChatMessage]
    }

    private func buildContent(text: String?, dataURLs: [String]) -> [Part] {
        var a: [Part] = []
        if let t = text, !t.isEmpty { a.append(.init(type: "text", text: t, image_url: nil)) }
        for url in dataURLs { a.append(.init(type: "image_url", text: nil, image_url: .init(url: url))) }
        return a
    }

    func streamChat(history: [Message],
                    onDelta: @Sendable @escaping (String) -> Void,
                    onDone: @Sendable @escaping (Error?) -> Void) {
        guard !apiKey.isEmpty else {
            onDone(NSError(domain: "OpenAI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing API key"]))
            return
        }

        // Map history
        let msgs: [ChatMessage] = history.map { m in
            .init(role: m.role.rawValue, content: buildContent(text: m.text, dataURLs: m.imageDataUrls))
        }
        let body = ChatRequest(model: model, stream: true, messages: msgs)
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions"),
              let data = try? JSONEncoder().encode(body) else {
            onDone(NSError(domain: "OpenAI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Bad request"]))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = data

        if #available(macOS 12.0, *) {
            Task {
                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                        throw NSError(domain: "OpenAI", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { continue }
                        if let json = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = (choices.first?["delta"] as? [String: Any])?["content"] as? String,
                           !delta.isEmpty {
                            onDelta(delta)
                        }
                    }
                    onDone(nil)
                } catch {
                    onDone(error)
                }
            }
        } else {
            onDone(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Requires macOS 12+"]))
        }
    }
}
