import SwiftUI

struct ChatView: View {
    @ObservedObject var petManager: PetManager
    @ObservedObject var chatStore: ChatStore
    @ObservedObject var todoStore: TodoStore
    @StateObject private var ollama = OllamaService()
    @StateObject private var groq = GroqService()
    @State private var inputText = ""
    var onBack: () -> Void

    var isLoading: Bool {
        ollama.isLoading || groq.isLoading
    }

    var messages: [SavedMessage] {
        petManager.isSecretaryMode ? chatStore.secretaryMessages : chatStore.petMessages
    }

    var chatAvatar: NSImage? {
        if petManager.isSecretaryMode {
            return petManager.loadAssistantImage()
        }
        return petManager.loadImage(for: petManager.displayMood)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                // 아바타
                Group {
                    if let img = chatAvatar {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Text(petManager.displayMood.emoji)
                            .font(.system(size: 14))
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .background(Circle().fill(Color.gray.opacity(0.1)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(petManager.isSecretaryMode ? "비서 모드" : petManager.name)
                        .font(.system(size: 12, weight: .bold))
                    Text(petManager.isSecretaryMode ? "AI 비서" : petManager.displayMood.label)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            // 메시지 목록
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg,
                                      petName: petManager.isSecretaryMode ? "비서" : petManager.name,
                                      avatar: msg.role == "assistant" ? chatAvatar : nil)
                                .id(msg.id)
                        }

                        if petManager.isSecretaryMode && groq.isLoading && !groq.streamingContent.isEmpty {
                            ChatBubble(
                                message: SavedMessage(role: "assistant", content: groq.streamingContent),
                                petName: "비서",
                                avatar: chatAvatar
                            )
                            .id("streaming")
                        }

                        if isLoading && (petManager.isSecretaryMode ? groq.streamingContent.isEmpty : true) {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(Color.secondary.opacity(0.4))
                                        .frame(width: 6, height: 6)
                                        .scaleEffect(isLoading ? 1 : 0.5)
                                        .animation(
                                            .easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(i) * 0.2),
                                            value: isLoading
                                        )
                                }
                                Text("생각 중...")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .id("loading")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: groq.streamingContent) { _ in
                    withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                }
            }
            .frame(maxHeight: .infinity)

            // 입력창
            HStack(spacing: 8) {
                TextField(petManager.isSecretaryMode ? "질문하세요..." : "메시지 입력...",
                         text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(
                                (inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                                ? Color.gray.opacity(0.3)
                                : Color.accentColor
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            // 이전 대화 맥락 복원
            groq.loadHistory(from: chatStore.secretaryMessages)
            ollama.loadHistory(from: chatStore.petMessages)

            if !petManager.isSecretaryMode && chatStore.petMessages.isEmpty {
                chatStore.addPetMessage(role: "assistant", content: greetingForMood())
            }
            if petManager.isSecretaryMode && chatStore.secretaryMessages.isEmpty {
                if groq.hasAPIKey {
                    chatStore.addSecretaryMessage(role: "assistant", content: "비서 모드 ON! 무엇을 도와드릴까요? 🤓")
                } else {
                    chatStore.addSecretaryMessage(role: "system",
                        content: "⚠️ Groq API 키가 필요해요.\n설정에서 입력해주세요.\n\n키 발급: console.groq.com")
                }
            }
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if petManager.isSecretaryMode {
            chatStore.addSecretaryMessage(role: "user", content: text)
        } else {
            chatStore.addPetMessage(role: "user", content: text)
        }
        inputText = ""

        Task {
            do {
                if petManager.isSecretaryMode {
                    let reply = try await groq.chatStream(message: text, systemPrompt: secretaryPrompt())
                    let cleanReply = processActions(reply)
                    groq.updateLastReply(cleanReply)
                    let displayText = cleanReply.isEmpty ? "✅ 완료!" : cleanReply
                    chatStore.addSecretaryMessage(role: "assistant", content: displayText)
                } else {
                    let reply = try await ollama.chat(
                        message: text,
                        mood: petManager.mood,
                        petName: petManager.name
                    )
                    chatStore.addPetMessage(role: "assistant", content: reply)
                }
            } catch {
                let errorMsg = "⚠️ \(error.localizedDescription)"
                if petManager.isSecretaryMode {
                    chatStore.addSecretaryMessage(role: "system", content: errorMsg)
                } else {
                    chatStore.addPetMessage(role: "system", content: errorMsg)
                }
            }
        }
    }

    func processActions(_ reply: String) -> String {
        var cleaned = reply
        let chatStoreRef = chatStore

        // 할 일 추가
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[TODO:(.+?)\\]") { title in
            let alreadyExists = todoStore.items.contains { $0.title == title && !$0.isDone }
            if !alreadyExists { todoStore.add(title: title) }
        }

        // 할 일 완료
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[DONE:(.+?)\\]") { title in
            if let item = todoStore.items.first(where: { $0.title == title && !$0.isDone }) {
                todoStore.toggle(id: item.id)
                petManager.completedTodo()
            }
        }

        // 할 일 삭제
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[DELETE:(.+?)\\]") { title in
            if let item = todoStore.items.first(where: { $0.title == title }) {
                todoStore.delete(id: item.id)
            }
        }

        // 웹사이트 열기
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[OPEN:(.+?)\\]") { url in
            ActionExecutor.openURL(url)
        }

        // 앱 실행
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[APP:(.+?)\\]") { app in
            ActionExecutor.openApp(app)
        }

        // Finder 열기
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[FINDER:(.+?)\\]") { path in
            ActionExecutor.openFinder(path)
        }

        // AppleScript 실행
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[SCRIPT:(.+?)\\]") { script in
            let result = ActionExecutor.runAppleScript(script)
            if !result.success, let error = result.output {
                chatStoreRef.addSecretaryMessage(role: "system", content: "⚠️ \(error)")
            }
        }

        // 쉘 명령 실행
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[SHELL:(.+?)\\]") { command in
            Task {
                let result = await ActionExecutor.runShell(command)
                if let output = result.output, !output.isEmpty {
                    chatStoreRef.addSecretaryMessage(role: "system", content: "📋 실행 결과:\n\(output)")
                }
            }
        }

        // 파일 검색
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[SEARCH:(.+?)\\]") { query in
            Task {
                let result = await ActionExecutor.searchFiles(query)
                if let output = result.output, !output.isEmpty {
                    chatStoreRef.addSecretaryMessage(role: "system", content: "🔍 검색 결과:\n\(output)")
                }
            }
        }

        // 웹 검색
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[WEBSEARCH:(.+?)\\]") { query in
            Task {
                let result = await ActionExecutor.webSearch(query)
                if let output = result.output, !output.isEmpty {
                    chatStoreRef.addSecretaryMessage(role: "system", content: "🌐 웹 검색 결과:\n\(output)")
                }
            }
        }

        // 기억하기
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[REMEMBER:(.+?)\\]") { value in
            ActionExecutor.saveMemory(value)
        }

        // 기억 떠올리기
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[RECALL:(.+?)\\]") { keyword in
            if let found = ActionExecutor.recallMemory(keyword) {
                chatStoreRef.addSecretaryMessage(role: "system", content: "💾 기억:\n\(found)")
            } else {
                chatStoreRef.addSecretaryMessage(role: "system", content: "💾 '\(keyword)' 관련 기억이 없어요")
            }
        }

        // 기억 삭제
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[FORGET:(.+?)\\]") { keyword in
            ActionExecutor.deleteMemory(keyword)
        }

        // 리마인더: [TIMER:5m|메시지] 또는 [TIMER:15:00|메시지]
        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[TIMER:(.+?)\\]") { content in
            let parts = content.split(separator: "|", maxSplits: 1)
            if parts.count == 2 {
                ActionExecutor.addReminder(timeStr: String(parts[0]), message: String(parts[1]), petManager: petManager)
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func secretaryPrompt() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyy년 M월 d일 (E) HH:mm"
        let now = dateFormatter.string(from: Date())

        let pendingTodos = todoStore.items.filter { !$0.isDone }.map { "- \($0.title)" }.joined(separator: "\n")
        let todoContext = pendingTodos.isEmpty ? "현재 할 일 없음" : "현재 할 일 목록:\n\(pendingTodos)"
        let memories = ActionExecutor.loadMemories()
        let memoryContext = memories.isEmpty ? "저장된 기억 없음" : "저장된 기억:\n\(memories.suffix(10).map { "- \($0)" }.joined(separator: "\n"))"

        return """
        너는 '\(petManager.name)'이라는 이름의 똑똑한 AI 비서야.
        사용자의 질문에 정확하고 도움이 되는 답변을 해.
        항상 한국어로 대답해. 반말로 친근하게 답해줘.

        현재 시간: \(now)

        \(todoContext)

        역할:
        - 일정 관리, 할 일 정리, 앱/웹 열기, 시스템 제어
        - 정보 검색, 요약, 글쓰기, 번역, 코딩 도움
        - 파일 찾기, 터미널 명령 실행

        === 액션 태그 ===
        자연스러운 답변 뒤에 태그를 붙여. 태그는 시스템이 자동 실행하고 화면에서 제거돼.
        사용자가 요청할 때만 태그를 써.

        할 일 관리:
        [TODO:내용] → 할 일 추가 (이미 목록에 있으면 쓰지 마)
        [DONE:내용] → 완료 처리 (목록과 정확히 같은 내용)
        [DELETE:내용] → 삭제

        시스템 제어:
        [OPEN:URL] → 웹사이트 열기
        [APP:이름] → 앱 실행
        [FINDER:경로] → Finder 열기
        [SCRIPT:코드] → AppleScript 실행
        [SHELL:명령어] → 터미널 명령
        [SEARCH:검색어] → 파일 검색

        검색/지식:
        [WEBSEARCH:검색어] → 웹 검색 (모르는 것, 최신 정보 질문에 사용)

        기억:
        [REMEMBER:내용] → 기억 저장
        [RECALL:키워드] → 기억 찾기
        [FORGET:키워드] → 기억 삭제

        리마인더 (반드시 이 형식으로!):
        "~뒤에 알려줘", "~시에 알려줘" 요청 시 반드시 [TIMER:] 태그 사용
        [TIMER:1m|알림 내용] → 1분 후
        [TIMER:5m|물 마시기] → 5분 후
        [TIMER:30m|회의 준비] → 30분 후
        [TIMER:1h|점심] → 1시간 후
        [TIMER:15:00|회의 시작] → 15시 정각
        [TIMER:9:30|출근] → 9시 30분
        절대 다른 형식 쓰지 마. 반드시 [TIMER:시간|메시지] 형식으로.

        \(memoryContext)

        !!! 매우 중요 !!!
        - 사용자가 직접 요청한 경우에만 태그를 써.
        - 일반 대화(인사, 질문, 잡담)에는 절대 태그 붙이지 마.
        - 이전 대화 액션 반복 금지.
        - 위험 명령(rm, sudo) 금지.
        - 답변은 간결하게.
        """
    }

    func greetingForMood() -> String {
        switch petManager.mood {
        case .happy: return "안녕!! 오늘 기분 완전 좋아! 뭐 할까? 😆"
        case .normal: return "어 왔어? 반가워~ 뭐 얘기할래? 🐱"
        case .hungry: return "으... 배고파... 밥 먼저 주면 안될까... 🍚"
        case .tired: return "하아암... 졸린데... 그래도 반가워 😪"
        case .sad: return "왔구나... 나 좀 외로웠어... 😢"
        case .sleeping: return "음냐... 잠깐만... 쿨쿨... 💤"
        case .dirty: return "으... 몸이 근질근질해... 목욕시켜줘... 🫧"
        case .bathing: return "아~ 시원하다! 뽀득뽀득~ 🛁"
        case .cook: return "지금 요리하는 중~! 🍳"
        case .eat: return "냠냠~ 맛있어~! 🍴"
        case .full: return "으~ 배불러... 행복해... 😋"
        case .angry: return "흥!! 말 걸지마!! 😤"
        case .work: return "지금 집중 중이야...! 나중에 얘기하자 💻"
        }
    }
}

struct ChatBubble: View {
    let message: SavedMessage
    let petName: String
    var avatar: NSImage? = nil

    var isUser: Bool { message.role == "user" }
    var isSystem: Bool { message.role == "system" }

    var body: some View {
        if isSystem {
            HStack {
                Spacer()
                Text(message.content)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                Spacer()
            }
        } else {
            HStack(alignment: .top, spacing: 6) {
                if isUser { Spacer(minLength: 50) }

                if !isUser {
                    // 펫 아바타
                    Group {
                        if let img = avatar {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Circle().fill(Color.gray.opacity(0.15))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                }

                VStack(alignment: isUser ? .trailing : .leading, spacing: 2) {
                    Text(isUser ? "나" : petName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(message.content)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(isUser
                            ? AnyShapeStyle(LinearGradient(colors: [.purple.opacity(0.25), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color(NSColor.controlBackgroundColor))
                        )
                        .cornerRadius(12)
                        .cornerRadius(isUser ? 12 : 12)
                }

                if !isUser { Spacer(minLength: 50) }
            }
        }
    }
}
