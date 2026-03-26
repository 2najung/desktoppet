import Foundation

struct SavedMessage: Codable, Identifiable {
    let id: String
    let role: String
    let content: String

    init(role: String, content: String) {
        self.id = UUID().uuidString
        self.role = role
        self.content = content
    }
}

class ChatStore: ObservableObject {
    @Published var petMessages: [SavedMessage] = []
    @Published var secretaryMessages: [SavedMessage] = []

    init() {
        load()
    }

    func addPetMessage(role: String, content: String) {
        petMessages.append(SavedMessage(role: role, content: content))
        // 최대 100개만 유지
        if petMessages.count > 100 {
            petMessages = Array(petMessages.suffix(100))
        }
        save()
    }

    func addSecretaryMessage(role: String, content: String) {
        secretaryMessages.append(SavedMessage(role: role, content: content))
        if secretaryMessages.count > 100 {
            secretaryMessages = Array(secretaryMessages.suffix(100))
        }
        save()
    }

    func clearPet() {
        petMessages.removeAll()
        save()
    }

    func clearSecretary() {
        secretaryMessages.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(petMessages) {
            UserDefaults.standard.set(data, forKey: "chatPetMessages")
        }
        if let data = try? JSONEncoder().encode(secretaryMessages) {
            UserDefaults.standard.set(data, forKey: "chatSecretaryMessages")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "chatPetMessages"),
           let msgs = try? JSONDecoder().decode([SavedMessage].self, from: data) {
            petMessages = msgs
        }
        if let data = UserDefaults.standard.data(forKey: "chatSecretaryMessages"),
           let msgs = try? JSONDecoder().decode([SavedMessage].self, from: data) {
            secretaryMessages = msgs
        }
    }
}
