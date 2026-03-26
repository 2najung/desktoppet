import SwiftUI

extension Notification.Name {
    static let showQuickCommand = Notification.Name("showQuickCommand")
}

struct QuickCommandView: View {
    @ObservedObject var chatStore: ChatStore
    @ObservedObject var petManager: PetManager
    @ObservedObject var todoStore: TodoStore
    @StateObject private var groq = GroqService()
    @State private var inputText = ""
    @State private var resultText: String? = nil
    @State private var isLoading = false
    var onDismiss: () -> Void
    var onResize: ((CGFloat) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 입력 바
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)

                TextField("무엇을 도와줄까?", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit { send() }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Text("⌘⇧Space")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // 결과
            if let result = resultText {
                Divider()
                ScrollView {
                    Text(result)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .frame(maxHeight: 200)
            }
        }
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThickMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            groq.loadHistory(from: chatStore.secretaryMessages)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showQuickCommand)) { _ in
            inputText = ""
            resultText = nil
            isLoading = false
            groq.loadHistory(from: chatStore.secretaryMessages)
            onResize?(52)
        }
        .onChange(of: resultText) { newValue in
            onResize?(newValue != nil ? 260 : 52)
        }
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }

        isLoading = true
        resultText = nil
        petManager.isSecretaryMode = true
        chatStore.addSecretaryMessage(role: "user", content: text)
        inputText = ""

        Task {
            do {
                groq.loadHistory(from: chatStore.secretaryMessages)
                let reply = try await groq.chatStream(message: text, systemPrompt: buildPrompt())
                let cleanReply = processActions(reply)
                groq.updateLastReply(cleanReply)
                chatStore.addSecretaryMessage(role: "assistant", content: cleanReply)
                resultText = cleanReply
                isLoading = false
            } catch {
                resultText = "⚠️ \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    func buildPrompt() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 (E) HH:mm"
        let now = f.string(from: Date())
        let todos = todoStore.items.filter { !$0.isDone }.map { "- \($0.title)" }.joined(separator: "\n")
        let todoCtx = todos.isEmpty ? "할 일 없음" : "할 일 목록:\n\(todos)"

        return """
        너는 '\(petManager.name)' AI 비서. 한국어 반말로 간결하게 답해.
        현재: \(now)
        \(todoCtx)

        액션 태그 (답변 뒤에 붙이면 시스템이 자동 실행함):
        [TODO:내용] 추가, [DONE:내용] 완료, [DELETE:내용] 삭제
        [OPEN:URL] 웹열기, [APP:이름] 앱실행, [FINDER:경로] 폴더
        [SCRIPT:코드] AppleScript, [SHELL:명령어] 터미널, [SEARCH:검색어] 파일검색

        !!! 매우 중요 !!!
        - 사용자가 "열어", "실행해", "찾아", "검색해" 등 직접 요청한 경우에만 태그를 써.
        - 일반 대화(인사, 질문, 잡담)에는 절대 태그를 붙이지 마.
        - 이전 대화에서 했던 액션을 반복하지 마.
        - 위험 명령(rm, sudo) 금지.
        """
    }

    func processActions(_ reply: String) -> String {
        var cleaned = reply
        let cs = chatStore

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[TODO:(.+?)\\]") { title in
            if !todoStore.items.contains(where: { $0.title == title && !$0.isDone }) {
                todoStore.add(title: title)
            }
        }
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[DONE:(.+?)\\]") { title in
            if let item = todoStore.items.first(where: { $0.title == title && !$0.isDone }) {
                todoStore.toggle(id: item.id)
                petManager.completedTodo()
            }
        }
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[DELETE:(.+?)\\]") { title in
            if let item = todoStore.items.first(where: { $0.title == title }) {
                todoStore.delete(id: item.id)
            }
        }
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[OPEN:(.+?)\\]") { ActionExecutor.openURL($0) }
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[APP:(.+?)\\]") { ActionExecutor.openApp($0) }
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[FINDER:(.+?)\\]") { ActionExecutor.openFinder($0) }
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[SCRIPT:(.+?)\\]") { ActionExecutor.runAppleScript($0) }
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[SHELL:(.+?)\\]") { command in
            Task {
                let result = await ActionExecutor.runShell(command)
                if let output = result.output, !output.isEmpty {
                    cs.addSecretaryMessage(role: "system", content: "📋 \(output)")
                }
            }
        }
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[SEARCH:(.+?)\\]") { query in
            Task {
                let result = await ActionExecutor.searchFiles(query)
                if let output = result.output, !output.isEmpty {
                    cs.addSecretaryMessage(role: "system", content: "🔍 \(output)")
                }
            }
        }

        // 리마인더
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[TIMER:(.+?)\\]") { content in
            let parts = content.split(separator: "|", maxSplits: 1)
            if parts.count == 2 {
                ActionExecutor.addReminder(timeStr: String(parts[0]), message: String(parts[1]), petManager: petManager)
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
