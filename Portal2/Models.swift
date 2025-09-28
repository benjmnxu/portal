import Foundation

enum Role: String, Codable { case system, user, assistant }

struct Message: Codable, Identifiable {
    var id = UUID()
    var role: Role
    var text: String?
    var imageDataUrls: [String] = []
    var ts: Date = .init()
}

struct Thread: Codable, Identifiable {
    var id = UUID()
    var title: String = "New Chat"
    var createdAt: Date = .init()
    var updatedAt: Date = .init()
    var messages: [Message] = []  
}