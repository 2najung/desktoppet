import Foundation

struct TodoItem: Codable, Identifiable {
    let id: String
    var title: String
    var isDone: Bool
    let createdAt: Date

    init(title: String) {
        self.id = UUID().uuidString
        self.title = title
        self.isDone = false
        self.createdAt = Date()
    }
}

class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = []

    init() { load() }

    var pendingCount: Int { items.filter { !$0.isDone }.count }

    func add(title: String) {
        items.append(TodoItem(title: title))
        save()
    }

    func toggle(id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isDone.toggle()
        save()
    }

    func delete(id: String) {
        items.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "todoItems")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "todoItems"),
           let saved = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = saved
        }
    }
}
