import Foundation

final class Store: ObservableObject {
    @Published var threads: [Thread] = []
    @Published var selectedID: UUID?

    private let fileUrl: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Portal", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("threads.json")
    }()

    init() {
        load()
        if threads.isEmpty {
            let t = Thread()
            threads = [t]
            selectedID = t.id
            save()
        } else if selectedID == nil {
            selectedID = threads.first?.id
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileUrl) else { return }
        if let decoded = try? JSONDecoder().decode([Thread].self, from: data) {
            threads = decoded
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(threads) {
            try? encoded.write(to: fileUrl)
        }
    }

    func update(_ mutate: (inout [Thread]) -> Void) {
        mutate(&threads)
        save()
    }
    
    var selected: Thread? {
        get {threads.first(where: { $0.id == selectedID })}
        set {
            guard let t = newValue else { return }
            update { $0 = $0.map { $0.id == t.id ? t : $0 } }
        }
    }

}