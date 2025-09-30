import Foundation
import OpenAI
import Combine

final class OpenAIClient {
    var apiKey: String
    var modelClient: OpenAIProtocol
    var model = "gpt-4o-mini"
    
    private var activeStream: CancellableRequest?
    
    init(apiKey: String) {
        self.apiKey = apiKey
        self.modelClient = OpenAI(apiToken: apiKey)
    }

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
        
        // Map history to your own wire structs (kept for future use if you switch APIs)
        let _ = history.map { m in
            ChatMessage(role: m.role.rawValue, content: buildContent(text: m.text, dataURLs: m.imageDataUrls))
        }
        
        let lastUserText = history.last(where: { $0.role == .user })?.text ?? ""
        let query = CreateModelResponseQuery(
            input: .textInput(lastUserText),
            model: .gpt4_1,
            stream: true
        )
        
        self.activeStream = self.modelClient.responses.createResponseStreaming(
            query: query,
            onResult: { result in
                switch result {
                case .success(let event):
                    switch event {
                    case .outputText(.delta(let deltaEvent)):
                        onDelta(deltaEvent.delta)
                    default:
                        break
                    }
                case .failure(let error):
                    onDone(error)
                }
            },
            completion: { error in
                onDone(error)
            }
        )
    }
}
