import Foundation

// Groq API (OpenAI 호환 형식)
struct GroqMessage: Codable {
    let role: String
    let content: String
}

struct GroqRequest: Codable {
    let model: String
    let messages: [GroqMessage]
    let temperature: Double
    let max_tokens: Int
    let stream: Bool
}

struct GroqStreamChunk: Codable {
    struct Choice: Codable {
        struct Delta: Codable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}

class GroqService: ObservableObject {
    @Published var isLoading = false
    @Published var streamingContent: String = ""

    private var history: [GroqMessage] = []

    var apiKey: String {
        get {
            // geminiAPIKey → groqAPIKey 마이그레이션
            if let old = UserDefaults.standard.string(forKey: "geminiAPIKey"), !old.isEmpty {
                UserDefaults.standard.set(old, forKey: "groqAPIKey")
                UserDefaults.standard.removeObject(forKey: "geminiAPIKey")
            }
            return UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
        }
        set { UserDefaults.standard.set(newValue, forKey: "groqAPIKey") }
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static let tagRegex = try? NSRegularExpression(
        pattern: "\\[(OPEN|APP|FINDER|SCRIPT|SHELL|SEARCH|TODO|DONE|DELETE):.+?\\]"
    )

    private func stripTags(_ text: String) -> String {
        guard let regex = Self.tagRegex else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func loadHistory(from messages: [SavedMessage]) {
        history = messages
            .filter { $0.role != "system" }
            .suffix(20)
            .map { GroqMessage(role: $0.role, content: stripTags($0.content)) }
    }

    func chatStream(message: String, systemPrompt: String) async throws -> String {
        await MainActor.run { isLoading = true; streamingContent = "" }
        defer { Task { @MainActor in isLoading = false; streamingContent = "" } }

        guard hasAPIKey else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "API 키가 설정되지 않았어요. 설정에서 입력해주세요."])
        }

        var messages: [GroqMessage] = [GroqMessage(role: "system", content: systemPrompt)]
        messages.append(contentsOf: history.suffix(20))
        messages.append(GroqMessage(role: "user", content: message))

        let body = GroqRequest(model: "llama-3.3-70b-versatile", messages: messages,
                               temperature: 0.7, max_tokens: 1024, stream: true)

        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "API 오류 (\(http.statusCode))"])
        }

        var fullReply = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard jsonStr != "[DONE]" else { break }
            if let data = jsonStr.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(GroqStreamChunk.self, from: data),
               let delta = chunk.choices.first?.delta.content {
                fullReply += delta
                let snapshot = fullReply
                await MainActor.run { streamingContent = snapshot }
            }
        }

        history.append(GroqMessage(role: "user", content: message))
        history.append(GroqMessage(role: "assistant", content: fullReply))
        return fullReply
    }

    func clearHistory() { history = [] }

    func updateLastReply(_ content: String) {
        guard !history.isEmpty, history[history.count - 1].role == "assistant" else { return }
        history[history.count - 1] = GroqMessage(role: "assistant", content: content)
    }
}
