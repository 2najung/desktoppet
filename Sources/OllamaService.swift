import Foundation

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
}

struct OllamaChatResponse: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    let message: Message?
}

class OllamaService: ObservableObject {
    @Published var isLoading = false

    private let baseURL = "http://localhost:11434"
    private var history: [OllamaMessage] = []

    func loadHistory(from messages: [SavedMessage]) {
        history = messages
            .filter { $0.role != "system" }
            .suffix(10)
            .map { OllamaMessage(role: $0.role, content: $0.content) }
    }

    func checkConnection() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func chat(message: String, mood: PetMood, petName: String) async throws -> String {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        let systemPrompt = """
        [IMPORTANT] You are a cute desktop pet named '\(petName)'.
        You MUST ALWAYS respond in Korean (한국어).
        You speak in casual/informal tone (반말).
        You are adorable, friendly, and love chatting with your owner.
        Keep responses SHORT: 1-2 sentences max.
        Use cute emoticons sometimes like 😊🥺😆

        Your current mood: \(mood.label)

        Mood affects your speech:
        - 행복(happy): energetic and excited
        - 배고픔(hungry): weak, begging for food
        - 졸림(tired): slow, yawning
        - 슬픔(sad): depressed, asking to play
        - 화남(angry): grumpy, short-tempered
        - 보통(normal): relaxed and friendly

        REMEMBER: Always reply in Korean, keep it short and cute!
        """

        var messages: [OllamaMessage] = [
            OllamaMessage(role: "system", content: systemPrompt)
        ]
        messages.append(contentsOf: history.suffix(10))
        messages.append(OllamaMessage(role: "user", content: message))

        let body = OllamaChatRequest(model: "gemma2", messages: messages, stream: false)

        var request = URLRequest(url: URL(string: "\(baseURL)/api/chat")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        let reply = response.message?.content ?? "..."

        history.append(OllamaMessage(role: "user", content: message))
        history.append(OllamaMessage(role: "assistant", content: reply))

        return reply
    }
}
