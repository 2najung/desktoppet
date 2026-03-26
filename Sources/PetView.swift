import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct PetView: View {
    @ObservedObject var petManager: PetManager
    @ObservedObject var chatStore: ChatStore
    @ObservedObject var ddayStore: DDayStore
    var onTap: () -> Void
    @State private var bounce = false
    @State private var speechBubble: String? = nil
    @State private var speechTimer: Timer? = nil
    @State private var isDropTarget = false
    @State private var showConfetti = false
    @State private var prevLevel = 0
    @StateObject private var groq = GroqService()

    private let randomMessages: [PetMood: [String]] = [
        .happy: ["오늘 기분 짱이야!", "놀자놀자~! 🎉", "히히 좋아좋아~"],
        .normal: ["뭐해~?", "심심해~", "같이 놀래? 😺"],
        .hungry: ["꼬르륵...", "밥...줘... 🍚", "배고파앙..."],
        .tired: ["하아암~ 졸려...", "눈이 감겨... 😴", "쉬고싶다..."],
        .sad: ["나 잊은거 아니지...?", "외로워... 😢", "놀아줘..."],
        .sleeping: ["zzZ...", "쿨쿨... 💤", "음냐음냐..."],
        .dirty: ["몸이 근질근질...", "씻고싶다... 🫧", "더러워..."],
        .bathing: ["아~ 시원해~!", "뽀득뽀득 🫧", "깨끗해지는 중~"],
        .cook: ["맛있겠다~!", "뭐 해먹지~ 🍳", "요리 중~!"],
        .eat: ["냠냠냠~!", "맛있다 🍴", "한입만 더~!"],
        .full: ["배불러~!", "으흐흐 😋", "맛있었다~!"],
        .angry: ["흥!! 😤", "건드리지마!!", "화났어!!!"],
        .work: ["집중 중이야...!", "방해하지마~ 💻", "열심히 하는 중!"],
    ]

    var petEmoji: String {
        switch petManager.displayMood {
        case .happy: return "😆"
        case .normal: return "🐱"
        case .hungry: return "😿"
        case .tired: return "😪"
        case .sad: return "🥺"
        case .sleeping: return "😴"
        case .dirty: return "🫥"
        case .bathing: return "🛁"
        case .cook: return "🍳"
        case .eat: return "🍴"
        case .full: return "😋"
        case .angry: return "😤"
        case .work: return "💻"
        }
    }

    var body: some View {
        ZStack {
            // 날씨 이펙트
            WeatherEffectView(condition: petManager.weatherService.condition)

            // 드롭 하이라이트
            if isDropTarget {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.blue.opacity(0.7), lineWidth: 3)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.blue.opacity(0.1)))
                    .overlay(
                        Text("여기에 놓아줘!")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                    )
            }

            VStack(spacing: 6) {
            // D-Day 배지 (펫 머리 위)
            if !ddayStore.items.isEmpty {
                VStack(spacing: 3) {
                    ForEach(ddayStore.items.prefix(3)) { item in
                        Text(item.displayText)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(item.dDay == 0 ? .white : (item.dDay <= 3 ? .white : .primary))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    item.dDay == 0 ? Color.red :
                                    (item.dDay <= 3 ? Color.orange :
                                    Color.gray.opacity(0.15))
                                )
                            )
                    }
                }
                .padding(.bottom, 2)
            }

            // 펫 캐릭터
            petCharacter
                .onTapGesture { onTap() }

            // 기분 표시
            Text(petManager.displayMood.emoji + " " + petManager.displayMood.label)
                .font(.system(size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .cornerRadius(8)

            // 날씨 표시
            if !petManager.weatherService.description.isEmpty {
                Text(petManager.weatherService.description)
                    .font(.system(size: 9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
            }

            // 클립보드 제안
            if let suggestion = petManager.clipboardSuggestion {
                Button(action: handleClipboardAction) {
                    Text(suggestion)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)))
                        .shadow(color: .purple.opacity(0.3), radius: 4)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }

            // 시간 알림
            if let timeMsg = petManager.timeMessage {
                Text(timeMsg)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange.opacity(0.9)))
                    .shadow(color: .orange.opacity(0.3), radius: 5)
                    .transition(.opacity.combined(with: .scale))
            }

            // 말풍선
            if let speech = speechBubble {
                Text(speech)
                    .font(.system(size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.1), radius: 3)
                    .transition(.opacity.combined(with: .scale))
            }

            // 액션 피드백
            if let action = petManager.lastAction {
                Text(action)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .transition(.opacity.combined(with: .scale))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 10)
        } // ZStack
        .onDrop(of: [.fileURL, .url, .plainText], isTargeted: $isDropTarget) { providers in
            handleDrop(providers)
            return true
        }
        .animation(.easeInOut(duration: 0.3), value: isDropTarget)
        .animation(.easeInOut(duration: 0.3), value: petManager.lastAction != nil)
        .animation(.easeInOut(duration: 0.3), value: speechBubble != nil)
        .overlay {
            if showConfetti {
                ConfettiOverlay()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            bounce = true
            prevLevel = petManager.level
            startRandomSpeech()
        }
        .onChange(of: petManager.level) { newLevel in
            if newLevel > prevLevel && prevLevel > 0 {
                withAnimation { showConfetti = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation { showConfetti = false }
                }
            }
            prevLevel = newLevel
        }
        .onDisappear {
            speechTimer?.invalidate()
            speechTimer = nil
        }
    }

    var currentImage: NSImage? {
        if petManager.useBuiltInCharacter { return nil }
        if petManager.isSecretaryMode, let img = petManager.loadAssistantImage() {
            return img
        }
        return petManager.loadImage(for: petManager.displayMood)
    }

    var isWalking: Bool { petManager.walkState == "walking" }
    var isSitting: Bool { petManager.walkState == "sitting" }

    @ViewBuilder
    var petCharacter: some View {
        if let nsImage = currentImage {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .scaleEffect(x: petManager.walkDirection >= 0 ? 1 : -1, y: 1)
                .rotationEffect(.degrees(isWalking ? (petManager.walkDirection > 0 ? 3 : -3) : 0))
                .offset(y: isSitting ? 6 : (bounce ? -4 : 4))
                .animation(
                    isWalking
                        ? .easeInOut(duration: 0.3).repeatForever(autoreverses: true)
                        : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: bounce
                )
                .animation(.easeInOut(duration: 0.3), value: petManager.walkDirection)
                .animation(.easeInOut(duration: 0.5), value: petManager.walkState)
        } else {
            PotatoPetView(mood: petManager.displayMood, size: 100)
                .scaleEffect(x: petManager.walkDirection >= 0 ? 1 : -1, y: 1)
                .rotationEffect(.degrees(isWalking ? (petManager.walkDirection > 0 ? 3 : -3) : 0))
                .offset(y: isSitting ? 6 : (bounce ? -4 : 4))
                .animation(
                    isWalking
                        ? .easeInOut(duration: 0.3).repeatForever(autoreverses: true)
                        : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: bounce
                )
                .animation(.easeInOut(duration: 0.3), value: petManager.walkDirection)
                .animation(.easeInOut(duration: 0.5), value: petManager.walkState)
        }
    }

    // MARK: - 클립보드 액션

    func handleClipboardAction() {
        guard let text = petManager.clipboardText else { return }
        let type = petManager.clipboardType
        petManager.clipboardSuggestion = nil
        petManager.isSecretaryMode = true

        let prompt: String
        switch type {
        case "url":
            if let url = URL(string: text) {
                NSWorkspace.shared.open(url)
                petManager.showAction("🌐 열었어!")
            }
            return
        case "translate":
            prompt = "이 텍스트를 한국어로 번역해줘:\n\(String(text.prefix(2000)))"
        case "summarize":
            prompt = "이 텍스트를 3줄로 요약해줘:\n\(String(text.prefix(3000)))"
        default:
            prompt = "이 텍스트에 대해 도움을 줘:\n\(String(text.prefix(2000)))"
        }

        chatStore.addSecretaryMessage(role: "user", content: prompt)
        petManager.showAction("🧠 처리 중...")

        let cs = chatStore
        let g = groq
        let pm = petManager
        Task {
            do {
                g.loadHistory(from: cs.secretaryMessages)
                let reply = try await g.chatStream(message: prompt, systemPrompt: "한국어로 간결하게 답해. 반말로.")
                g.updateLastReply(reply)
                cs.addSecretaryMessage(role: "assistant", content: reply)
                pm.showTimeMessage(type == "translate" ? "🌏 번역 완료! 채팅에서 봐~" : "📄 요약 완료! 채팅에서 봐~")
            } catch {
                pm.showAction("⚠️ 실패...")
            }
        }
    }

    // MARK: - 드래그 앤 드롭

    func handleDrop(_ providers: [NSItemProvider]) {
        let pm = petManager
        let cs = chatStore
        let g = groq

        for provider in providers {
            // 파일
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        Self.processFile(url, pm: pm, cs: cs, groq: g)
                    }
                }
                return
            }
            // URL
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(url)
                        pm.showAction("🌐 열었어!")
                    }
                }
                return
            }
            // 텍스트
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let text = String(data: data, encoding: .utf8) else { return }
                    DispatchQueue.main.async {
                        if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                            NSWorkspace.shared.open(url)
                            pm.showAction("🌐 열었어!")
                        } else {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                            pm.showAction("📋 복사했어!")
                        }
                    }
                }
                return
            }
        }
    }

    static func processFile(_ url: URL, pm: PetManager, cs: ChatStore, groq: GroqService) {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

        if isDir {
            NSWorkspace.shared.open(url)
            pm.showAction("📁 폴더 열었어!")
            return
        }

        let textExts = Set(["txt", "md", "swift", "py", "js", "ts", "json", "xml", "html", "css",
                            "yaml", "yml", "csv", "log", "sh", "zsh", "c", "cpp", "h", "java", "go", "rs", "rb"])
        let imageExts = Set(["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff"])
        let audioExts = Set(["mp3", "wav", "aac", "m4a", "flac", "ogg"])
        let videoExts = Set(["mp4", "mov", "avi", "mkv", "wmv", "webm"])

        if textExts.contains(ext) {
            // 텍스트 파일 → AI 요약
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                if groq.hasAPIKey {
                    summarizeFile(content, name: name, pm: pm, cs: cs, groq: groq)
                } else {
                    NSWorkspace.shared.open(url)
                    pm.showAction("📄 \(name) 열었어!")
                }
            } else {
                NSWorkspace.shared.open(url)
                pm.showAction("📄 열었어!")
            }
        } else if imageExts.contains(ext) {
            NSWorkspace.shared.open(url)
            pm.showAction("🖼 이미지다! 귀엽다~")
        } else if ext == "pdf" {
            // PDF → 텍스트 추출 후 AI 요약
            if groq.hasAPIKey, let text = Self.extractPDFText(url), !text.isEmpty {
                summarizeFile(text, name: name, pm: pm, cs: cs, groq: groq)
            } else {
                NSWorkspace.shared.open(url)
                pm.showAction("📑 PDF 열었어!")
            }
        } else if audioExts.contains(ext) {
            NSWorkspace.shared.open(url)
            pm.showAction("🎵 음악이다~!")
        } else if videoExts.contains(ext) {
            NSWorkspace.shared.open(url)
            pm.showAction("🎬 영상이다!")
        } else {
            NSWorkspace.shared.open(url)
            pm.showAction("📎 \(name) 열었어!")
        }
    }

    static func extractPDFText(_ url: URL) -> String? {
        guard let pdf = PDFDocument(url: url) else { return nil }
        var text = ""
        let maxPages = min(pdf.pageCount, 20)
        for i in 0..<maxPages {
            if let page = pdf.page(at: i), let pageText = page.string {
                text += pageText + "\n"
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    static func summarizeFile(_ content: String, name: String, pm: PetManager, cs: ChatStore, groq: GroqService) {
        pm.showAction("📄 읽는 중...")
        pm.isSecretaryMode = true
        cs.addSecretaryMessage(role: "user", content: "[\(name) 파일 드롭됨]")

        let truncated = String(content.prefix(3000))
        Task {
            do {
                let prompt = "사용자가 파일을 드롭했어. 내용을 간결하게 요약해줘. 파일명: \(name). 한국어 반말로, 핵심만 3~5줄."
                groq.loadHistory(from: [])
                let reply = try await groq.chatStream(message: truncated, systemPrompt: prompt)
                groq.updateLastReply(reply)
                await MainActor.run {
                    cs.addSecretaryMessage(role: "assistant", content: reply)
                    pm.showTimeMessage("📄 \(name) 요약 완료! 채팅에서 봐~")
                }
            } catch {
                await MainActor.run { pm.showAction("⚠️ 요약 실패...") }
            }
        }
    }

    func startRandomSpeech() {
        speechTimer?.invalidate()
        speechTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { _ in
            DispatchQueue.main.async {
                let messages = randomMessages[petManager.displayMood] ?? ["..."]
                withAnimation { speechBubble = messages.randomElement() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { speechBubble = nil }
                }
            }
        }
    }
}
