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
        guard !text.isEmpty, !isLoading else {
            print("QuickCommand: 빈 텍스트 또는 로딩 중")
            return
        }

        print("QuickCommand: 전송 시작 - \(text)")
        print("QuickCommand: API키 있음? \(groq.hasAPIKey)")
        isLoading = true
        resultText = nil
        petManager.isSecretaryMode = true
        chatStore.addSecretaryMessage(role: "user", content: text)
        inputText = ""

        Task {
            do {
                groq.loadHistory(from: chatStore.secretaryMessages)
                print("QuickCommand: Groq 호출 시작")
                let reply = try await groq.chatStream(message: text, systemPrompt: buildPrompt())
                print("QuickCommand: 응답 받음 - \(reply.prefix(50))")
                let cleanReply = processActions(reply)
                groq.updateLastReply(cleanReply)
                let displayText = cleanReply.isEmpty ? "✅ 완료!" : cleanReply
                chatStore.addSecretaryMessage(role: "assistant", content: displayText)
                resultText = displayText
                isLoading = false
            } catch {
                resultText = "⚠️ \(error.localizedDescription)"
                isLoading = false
                print("QuickCommand 에러: \(error)")
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

        리마인더 (반드시 이 형식으로!):
        "~뒤에 알려줘", "~시에 알려줘" → [TIMER:시간|메시지]
        예: [TIMER:1m|알림], [TIMER:5m|물 마시기], [TIMER:15:00|회의]
        절대 다른 형식 쓰지 마.

        !!! 매우 중요 !!!
        - 사용자가 직접 요청한 경우에만 태그를 써.
        - 일반 대화에는 절대 태그 붙이지 마.
        - 이전 액션 반복 금지. 위험 명령 금지.
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
