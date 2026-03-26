import Foundation
import Network
import AppKit

class PetWebServer {
    private var listener: NWListener?
    private let port: UInt16
    private var imageCache: [String: (Data, String)] = [:] // name → (data, mime)
    private let ollama = OllamaService()
    private let groq = GroqService()
    private var isChatting = false
    weak var petManager: PetManager?
    weak var todoStore: TodoStore?
    weak var pomodoroManager: PomodoroManager?
    weak var chatStore: ChatStore?
    weak var ddayStore: DDayStore?

    init(port: UInt16 = 8420) {
        self.port = port
    }

    func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener?.newConnectionHandler = { [weak self] conn in
                self?.handleConnection(conn)
            }
            listener?.start(queue: .main)
            print("🐱 펫 웹서버 시작: http://\(getLocalIP()):\(port)")
        } catch {
            print("웹서버 시작 실패: \(error)")
        }
    }

    private func handleConnection(_ conn: NWConnection) {
        conn.start(queue: .main)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                conn.cancel()
                return
            }
            let firstLine = request.components(separatedBy: "\r\n").first ?? ""
            let parts = firstLine.components(separatedBy: " ")
            guard parts.count >= 2 else { conn.cancel(); return }
            let fullPath = parts[1]
            let path = fullPath.components(separatedBy: "?").first ?? fullPath
            let query = fullPath.contains("?") ? String(fullPath.split(separator: "?", maxSplits: 1).last ?? "") : ""

            // 이미지 요청
            if path.hasPrefix("/img/") {
                self.sendImage(conn: conn, path: path)
                return
            }

            // 채팅 (비동기) — 별도 처리
            if path == "/api/chat" {
                self.handleChat(conn: conn, query: query)
                return
            }

            // 텍스트 응답
            let body: String
            let contentType: String
            if path.hasPrefix("/api/") {
                body = self.handleAPI(path, query: query)
                contentType = "application/json; charset=utf-8"
            } else if path == "/chat" {
                body = self.renderChatPage()
                contentType = "text/html; charset=utf-8"
            } else {
                body = self.renderPage()
                contentType = "text/html; charset=utf-8"
            }

            let header = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
            var responseData = Data(header.utf8)
            responseData.append(Data(body.utf8))
            conn.send(content: responseData, completion: .contentProcessed { _ in conn.cancel() })
        }
    }

    // MARK: - 이미지 서빙

    private func loadImage(name: String) -> (Data, String)? {
        if let cached = imageCache[name] { return cached }
        let dir = PetManager.imagesDirectory
        for ext in ["png", "jpg", "jpeg", "gif", "webp"] {
            let filePath = "\(dir)/\(name).\(ext)"
            guard let nsImage = NSImage(contentsOfFile: filePath) else { continue }

            // 흰 배경 제거 → PNG 변환
            let processed = removeWhiteBackground(from: nsImage)
            if let tiff = processed.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                imageCache[name] = (pngData, "image/png")
                return (pngData, "image/png")
            }
        }
        return nil
    }

    private func removeWhiteBackground(from image: NSImage) -> NSImage {
        let size = image.size
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return image }
        let w = bitmap.pixelsWide, h = bitmap.pixelsHigh
        guard let newBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 4 * w, bitsPerPixel: 32
        ) else { return image }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newBitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()

        guard let px = newBitmap.bitmapData else { return image }
        for y in 0..<h {
            for x in 0..<w {
                let off = (y * w + x) * 4
                let r = Int(px[off]), g = Int(px[off+1]), b = Int(px[off+2])
                let maxDiff = max(abs(r-g), abs(g-b), abs(r-b))
                let brightness = (r + g + b) / 3
                if maxDiff < 5 && brightness > 120 {
                    px[off+3] = 0
                }
            }
        }
        let result = NSImage(size: size)
        result.addRepresentation(newBitmap)
        return result
    }

    private func sendImage(conn: NWConnection, path: String) {
        let name = String(path.dropFirst(5))

        let result = loadImage(name: name) ?? loadImage(name: "default")

        guard let (data, mime) = result else {
            let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            conn.send(content: Data(notFound.utf8), completion: .contentProcessed { _ in conn.cancel() })
            return
        }

        let header = "HTTP/1.1 200 OK\r\nContent-Type: \(mime)\r\nContent-Length: \(data.count)\r\nCache-Control: max-age=60\r\nConnection: close\r\n\r\n"
        var responseData = Data(header.utf8)
        responseData.append(data)
        conn.send(content: responseData, completion: .contentProcessed { _ in conn.cancel() })
    }

    // MARK: - API

    private func handleAPI(_ path: String, query: String = "") -> String {
        guard let pm = petManager else { return "{\"error\":\"no pet\"}" }

        DispatchQueue.main.async {
            switch path {
            case "/api/feed": pm.feed()
            case "/api/play": pm.play()
            case "/api/pet": pm.pet()
            case "/api/bathe": pm.bathe()
            case "/api/walk": pm.walk()
            case "/api/sleep": pm.sleep()
            case "/api/wake": pm.wake()
            case "/api/toggleMode": pm.isSecretaryMode.toggle()
            default: break
            }
        }

        if path == "/api/rename" {
            let params = parseQuery(query)
            if let newName = params["name"], !newName.isEmpty {
                DispatchQueue.main.async { pm.name = newName; pm.save() }
            }
            return "{\"ok\":true}"
        }

        // 할 일 추가: /api/todo/add?title=내용
        if path == "/api/todo/add" {
            let params = parseQuery(query)
            if let title = params["title"], !title.isEmpty, let ts = todoStore {
                ts.add(title: title)
            }
            return "{\"ok\":true}"
        }

        // 할 일 완료 토글: /api/todo/toggle?id=아이디
        if path == "/api/todo/toggle" {
            let params = parseQuery(query)
            if let id = params["id"], let ts = todoStore {
                ts.toggle(id: id)
                if let item = ts.items.first(where: { $0.id == id }), item.isDone {
                    petManager?.completedTodo()
                }
            }
            return "{\"ok\":true}"
        }

        // 할 일 삭제: /api/todo/delete?id=아이디
        if path == "/api/todo/delete" {
            let params = parseQuery(query)
            if let id = params["id"], let ts = todoStore {
                ts.delete(id: id)
            }
            return "{\"ok\":true}"
        }

        // 할 일 목록 (id 포함)
        if path == "/api/todos" {
            guard let ts = todoStore else { return "{\"items\":[]}" }
            let arr = ts.items.map { item -> String in
                let t = item.title.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                return "{\"id\":\"\(item.id)\",\"title\":\"\(t)\",\"done\":\(item.isDone)}"
            }.joined(separator: ",")
            return "{\"items\":[\(arr)]}"
        }

        // D-Day 목록
        if path == "/api/ddays" {
            guard let ds = ddayStore else { return "{\"items\":[]}" }
            let arr = ds.items.map { item -> String in
                let t = item.title.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                return "{\"id\":\"\(item.id)\",\"title\":\"\(t)\",\"emoji\":\"\(item.emoji)\",\"dday\":\(item.dDay),\"ddayText\":\"\(item.dDayText)\",\"display\":\"\(item.displayText.replacingOccurrences(of: "\"", with: ""))\"}"
            }.joined(separator: ",")
            return "{\"items\":[\(arr)]}"
        }

        // D-Day 추가: /api/dday/add?title=이름&date=2026-04-01&emoji=📌
        if path == "/api/dday/add" {
            let params = parseQuery(query)
            if let title = params["title"], !title.isEmpty,
               let dateStr = params["date"], let ds = ddayStore {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                if let date = f.date(from: dateStr) {
                    let emoji = params["emoji"] ?? "📌"
                    ds.add(title: title, date: date, emoji: emoji)
                }
            }
            return "{\"ok\":true}"
        }

        // D-Day 삭제
        if path == "/api/dday/delete" {
            let params = parseQuery(query)
            if let id = params["id"], let ds = ddayStore {
                ds.delete(id: id)
            }
            return "{\"ok\":true}"
        }

        if path == "/api/status" {
            return statusJSON()
        }
        if path == "/api/messages" {
            return messagesJSON()
        }

        return "{\"ok\":true}"
    }

    // MARK: - 채팅

    private func parseQuery(_ query: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in query.components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                result[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
            }
        }
        return result
    }

    private func handleChat(conn: NWConnection, query: String) {
        let params = parseQuery(query)
        guard let msg = params["msg"], !msg.isEmpty,
              let pm = petManager, let cs = chatStore else {
            let body = "{\"error\":\"no message\"}"
            let header = "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
            conn.send(content: Data((header + body).utf8), completion: .contentProcessed { _ in conn.cancel() })
            return
        }

        let isSecretary = pm.isSecretaryMode

        // 유저 메시지 저장
        if isSecretary {
            cs.addSecretaryMessage(role: "user", content: msg)
        } else {
            cs.addPetMessage(role: "user", content: msg)
        }

        // 비동기로 AI 응답 받기
        isChatting = true
        Task {
            do {
                let reply: String
                if isSecretary {
                    groq.loadHistory(from: cs.secretaryMessages)
                    reply = try await groq.chatStream(message: msg, systemPrompt: self.secretaryPrompt())
                    let cleanReply = self.processActions(reply)
                    self.groq.updateLastReply(cleanReply)
                    cs.addSecretaryMessage(role: "assistant", content: cleanReply)
                } else {
                    ollama.loadHistory(from: cs.petMessages)
                    reply = try await ollama.chat(message: msg, mood: pm.mood, petName: pm.name)
                    cs.addPetMessage(role: "assistant", content: reply)
                }
                await MainActor.run { self.isChatting = false }
            } catch {
                let errMsg = "오류: \(error.localizedDescription)"
                if isSecretary { cs.addSecretaryMessage(role: "system", content: errMsg) }
                else { cs.addPetMessage(role: "system", content: errMsg) }
                await MainActor.run { self.isChatting = false }
            }
        }

        // 즉시 응답 (AI 답변은 폴링으로 확인)
        let body = "{\"ok\":true,\"chatting\":true}"
        let header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
        conn.send(content: Data((header + body).utf8), completion: .contentProcessed { _ in conn.cancel() })
    }

    private func messagesJSON() -> String {
        guard let pm = petManager, let cs = chatStore else { return "{\"messages\":[],\"chatting\":false}" }
        let msgs = pm.isSecretaryMode ? cs.secretaryMessages : cs.petMessages
        let last20 = msgs.suffix(20)
        let jsonArr = last20.map { msg -> String in
            let content = msg.content.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            return "{\"role\":\"\(msg.role)\",\"content\":\"\(content)\"}"
        }.joined(separator: ",")
        return "{\"messages\":[\(jsonArr)],\"chatting\":\(isChatting),\"secretary\":\(pm.isSecretaryMode)}"
    }

    private func secretaryPrompt() -> String {
        guard let pm = petManager else { return "" }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyy년 M월 d일 (E) HH:mm"
        let now = dateFormatter.string(from: Date())

        let pendingTodos = todoStore?.items.filter { !$0.isDone }.map { "- \($0.title)" }.joined(separator: "\n") ?? ""
        let todoContext = pendingTodos.isEmpty ? "현재 할 일 없음" : "현재 할 일 목록:\n\(pendingTodos)"

        return """
        너는 '\(pm.name)'이라는 이름의 똑똑한 AI 비서야.
        사용자의 질문에 정확하고 도움이 되는 답변을 해.
        항상 한국어로 대답해. 반말로 친근하게 답해줘.
        현재 시간: \(now)

        \(todoContext)

        === 액션 태그 ===
        자연스러운 답변 뒤에 태그를 붙여. 태그는 자동 실행되고 화면에서 제거돼.
        사용자가 요청할 때만 태그를 써.

        할 일: [TODO:내용] 추가, [DONE:내용] 완료, [DELETE:내용] 삭제
        시스템: [OPEN:URL] 웹열기, [APP:이름] 앱실행, [FINDER:경로] 폴더열기
        고급: [SCRIPT:코드] AppleScript, [SHELL:명령어] 터미널, [SEARCH:검색어] 파일검색

        !!! 매우 중요 !!!
        - 사용자가 "열어", "실행해", "찾아" 등 직접 요청한 경우에만 태그를 써.
        - 일반 대화(인사, 질문, 잡담)에는 절대 태그 붙이지 마.
        - 이전 대화에서 했던 액션 반복 금지.
        - 위험 명령(rm, sudo) 금지.
        """
    }

    private func processActions(_ reply: String) -> String {
        var cleaned = reply
        let ts = todoStore
        let pm = petManager
        let cs = chatStore

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[TODO:(.+?)\\]") { title in
            guard let ts = ts else { return }
            if !ts.items.contains(where: { $0.title == title && !$0.isDone }) {
                ts.add(title: title)
            }
        }

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[DONE:(.+?)\\]") { title in
            guard let ts = ts, let pm = pm else { return }
            if let item = ts.items.first(where: { $0.title == title && !$0.isDone }) {
                ts.toggle(id: item.id)
                pm.completedTodo()
            }
        }

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[DELETE:(.+?)\\]") { title in
            guard let ts = ts else { return }
            if let item = ts.items.first(where: { $0.title == title }) {
                ts.delete(id: item.id)
            }
        }

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[OPEN:(.+?)\\]") { url in
            ActionExecutor.openURL(url)
        }

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[APP:(.+?)\\]") { app in
            ActionExecutor.openApp(app)
        }

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[FINDER:(.+?)\\]") { path in
            ActionExecutor.openFinder(path)
        }

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[SCRIPT:(.+?)\\]") { script in
            ActionExecutor.runAppleScript(script)
        }

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[SHELL:(.+?)\\]") { command in
            Task {
                let result = await ActionExecutor.runShell(command)
                if let output = result.output, !output.isEmpty {
                    await MainActor.run { cs?.addSecretaryMessage(role: "system", content: "📋 실행 결과:\n\(output)") }
                }
            }
        }

        cleaned = ActionExecutor.extractAndRemoveTags(cleaned, pattern: "\\[SEARCH:(.+?)\\]") { query in
            Task {
                let result = await ActionExecutor.searchFiles(query)
                if let output = result.output, !output.isEmpty {
                    await MainActor.run { cs?.addSecretaryMessage(role: "system", content: "🔍 검색 결과:\n\(output)") }
                }
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func statusJSON() -> String {
        guard let pm = petManager else { return "{}" }
        let todos = todoStore?.items.filter { !$0.isDone }.map { "\"\($0.title.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: ",") ?? ""
        let pomoPhase: String = {
            guard let pomo = pomodoroManager else { return "idle" }
            switch pomo.phase {
            case .idle: return "idle"
            case .focusing: return "focusing"
            case .breaking: return "breaking"
            case .paused: return "paused"
            }
        }()
        let pomoTime = pomodoroManager?.timeString ?? "00:00"
        let secretary = pm.isSecretaryMode

        let weather = pm.weatherService.description.replacingOccurrences(of: "\"", with: "")
        let timeMsg = (pm.timeMessage ?? "").replacingOccurrences(of: "\"", with: "")
        let ddays = ddayStore?.items.prefix(3).map { "\"\($0.displayText.replacingOccurrences(of: "\"", with: ""))\"" }.joined(separator: ",") ?? ""

        return """
        {"name":"\(pm.name)","mood":"\(pm.displayMood.rawValue)","emoji":"\(pm.displayMood.emoji)","label":"\(pm.displayMood.label)","hunger":\(Int(pm.hunger)),"happiness":\(Int(pm.happiness)),"energy":\(Int(pm.energy)),"cleanliness":\(Int(pm.cleanliness)),"bond":\(Int(pm.bond)),"level":\(pm.level),"exp":\(Int(pm.experience)),"expNext":\(Int(pm.expForNextLevel)),"sleeping":\(pm.isSleeping),"secretary":\(secretary),"pomodoro":"\(pomoPhase)","pomoTime":"\(pomoTime)","todos":[\(todos)],"action":"\(pm.lastAction?.replacingOccurrences(of: "\"", with: "") ?? "")","weather":"\(weather)","timeMsg":"\(timeMsg)","ddays":[\(ddays)]}
        """
    }

    // MARK: - HTML

    private func renderPage() -> String {
        let petName = petManager?.name ?? "펫"
        return """
        <!DOCTYPE html>
        <html lang="ko" data-theme="light">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no, viewport-fit=cover">
        <meta name="apple-mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-status-bar-style" content="default">
        <meta name="apple-mobile-web-app-title" content="\(petName)">
        <link rel="apple-touch-icon" href="/img/default">
        <meta name="theme-color" content="#f5f0eb" id="themeColor">
        <title>\(petName)</title>
        <style>
        *{margin:0;padding:0;box-sizing:border-box}
        [data-theme="light"]{--bg:#f5f0eb;--card:#fff;--card-border:rgba(0,0,0,0.06);--card-shadow:0 2px 12px rgba(0,0,0,0.06);--text:#2d2d2d;--sub:#8b8b8b;--accent:#6c5ce7;--pet-bg:linear-gradient(160deg,#fff5ee,#ffecd2);--track:rgba(0,0,0,0.06);--speech-bg:rgba(255,255,255,0.95);--speech-text:#333}
        [data-theme="dark"]{--bg:#0f0f1a;--card:rgba(255,255,255,0.05);--card-border:rgba(255,255,255,0.08);--card-shadow:none;--text:#f0f0f0;--sub:#8892b0;--accent:#6c5ce7;--pet-bg:linear-gradient(160deg,rgba(108,92,231,0.15),rgba(0,206,209,0.08));--track:rgba(255,255,255,0.06);--speech-bg:rgba(30,30,50,0.9);--speech-text:#eee}
        body{font-family:-apple-system,BlinkMacSystemFont,'Pretendard',sans-serif;background:var(--bg);color:var(--text);min-height:100vh;min-height:100dvh;padding:env(safe-area-inset-top,12px) 12px calc(env(safe-area-inset-bottom,12px) + 20px);overscroll-behavior:none;-webkit-user-select:none;user-select:none;transition:background 0.3s,color 0.3s}
        .card{background:var(--card);border:1px solid var(--card-border);border-radius:20px;padding:16px;margin-bottom:10px;box-shadow:var(--card-shadow);transition:all 0.3s}

        .pet-card{text-align:center;padding:28px 16px 16px;position:relative;background:var(--pet-bg);overflow:hidden}
        .pet-img-wrap{display:inline-block;cursor:pointer;-webkit-tap-highlight-color:transparent;transition:transform 0.15s}
        .pet-img-wrap:active{transform:scale(0.88) rotate(-3deg)}
        .pet-img{width:150px;height:150px;object-fit:contain;animation:float 3s ease-in-out infinite;filter:drop-shadow(0 6px 16px rgba(0,0,0,0.12))}
        @keyframes float{0%,100%{transform:translateY(0) rotate(0deg)}25%{transform:translateY(-8px) rotate(1deg)}75%{transform:translateY(-4px) rotate(-1deg)}}
        .pet-name{font-size:18px;font-weight:800;margin-top:14px;letter-spacing:-0.3px}
        .pet-mood{display:inline-block;font-size:12px;color:var(--sub);margin-top:6px;padding:4px 12px;background:var(--track);border-radius:20px}
        .pet-action{font-size:13px;font-weight:700;color:#e17055;min-height:20px;margin-top:8px}
        .pet-weather{font-size:11px;color:var(--sub);margin-top:4px}
        .pet-time-msg{display:none;font-size:12px;font-weight:600;color:#fff;margin-top:8px;padding:6px 14px;background:linear-gradient(135deg,#e67e22,#d35400);border-radius:20px;animation:pulse 2s ease-in-out infinite}
        .pet-time-msg.show{display:inline-block}
        @keyframes pulse{0%,100%{opacity:1}50%{opacity:0.8}}
        .speech{display:none;background:var(--speech-bg);color:var(--speech-text);font-size:13px;padding:10px 16px;border-radius:16px;position:absolute;top:12px;left:50%;transform:translateX(-50%);box-shadow:0 4px 24px rgba(0,0,0,0.15);max-width:200px;z-index:10}
        .speech.show{display:block;animation:pop 0.3s cubic-bezier(0.175,0.885,0.32,1.275)}
        @keyframes pop{from{opacity:0;transform:translateX(-50%) scale(0.8)}to{opacity:1;transform:translateX(-50%) scale(1)}}

        .info-row{display:flex;align-items:center;gap:12px}
        .level-badge{background:linear-gradient(135deg,#6c5ce7,#a29bfe);color:#fff;padding:6px 14px;border-radius:20px;font-size:13px;font-weight:800;flex-shrink:0}
        .exp-wrap{flex:1}
        .exp-label{font-size:10px;color:var(--sub);margin-bottom:4px}
        .exp-track{height:6px;background:var(--track);border-radius:3px;overflow:hidden}
        .exp-fill{height:100%;background:linear-gradient(90deg,#6c5ce7,#a29bfe);border-radius:3px;transition:width 0.6s}

        .stats{display:grid;gap:8px}
        .stat{display:flex;align-items:center;gap:8px}
        .stat-emoji{font-size:16px;width:22px;text-align:center}
        .stat-name{width:38px;font-size:11px;color:var(--sub)}
        .stat-track{flex:1;height:6px;background:var(--track);border-radius:3px;overflow:hidden}
        .stat-bar{height:100%;border-radius:3px;transition:width 0.6s}
        .stat-num{width:26px;text-align:right;font-size:11px;font-weight:700;font-variant-numeric:tabular-nums}

        .actions{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
        .act{background:var(--track);border:1px solid var(--card-border);border-radius:16px;padding:14px 0;text-align:center;cursor:pointer;transition:all 0.12s;-webkit-tap-highlight-color:transparent}
        .act:active{transform:scale(0.88);opacity:0.7}
        .act-icon{font-size:28px;display:block}
        .act-label{font-size:10px;color:var(--sub);margin-top:4px}

        .btn-row{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin-top:2px}
        .nav-btn{display:flex;align-items:center;justify-content:center;gap:4px;padding:13px 0;border-radius:16px;font-size:13px;font-weight:700;text-decoration:none;color:#fff;transition:all 0.12s;-webkit-tap-highlight-color:transparent;border:none;cursor:pointer}
        .nav-btn:active{transform:scale(0.95)}
        .btn-chat{background:linear-gradient(135deg,#6c5ce7,#a29bfe)}
        .btn-todo{background:linear-gradient(135deg,#00b894,#55efc4);color:#1a1a2e}
        .btn-secretary{background:linear-gradient(135deg,#0984e3,#74b9ff)}
        .btn-secretary.on{background:linear-gradient(135deg,#d63031,#ff7675)}

        .pomo-card{text-align:center;padding:20px 16px}
        .pomo-time{font-size:40px;font-weight:800;font-family:'SF Mono',ui-monospace,monospace;letter-spacing:3px;color:var(--accent)}
        .pomo-label{font-size:11px;color:var(--sub);margin-top:4px}

        .todo-card{display:none}
        .todo-card.show{display:block}
        .todo-list{list-style:none}
        .todo-list li{padding:10px 0;border-bottom:1px solid var(--card-border);font-size:13px;display:flex;align-items:center;gap:8px}
        .todo-list li:last-child{border:none}
        .todo-dot{width:6px;height:6px;border-radius:50%;background:#00b894;flex-shrink:0}
        .sec-title{font-size:10px;color:var(--sub);font-weight:700;text-transform:uppercase;letter-spacing:1.5px;margin-bottom:10px}

        .settings-card{display:none}
        .settings-card.show{display:block}
        .setting-row{display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid var(--card-border)}
        .setting-row:last-child{border:none}
        .setting-label{font-size:13px}
        .setting-sub{font-size:10px;color:var(--sub)}
        .theme-toggle{width:50px;height:28px;border-radius:14px;border:none;background:var(--track);position:relative;cursor:pointer;transition:background 0.3s;-webkit-tap-highlight-color:transparent}
        .theme-toggle::after{content:'';position:absolute;top:3px;left:3px;width:22px;height:22px;border-radius:50%;background:#fff;box-shadow:0 1px 4px rgba(0,0,0,0.15);transition:transform 0.3s}
        .theme-toggle.on{background:#6c5ce7}
        .theme-toggle.on::after{transform:translateX(22px)}
        .name-input{background:var(--track);border:1px solid var(--card-border);border-radius:10px;padding:8px 12px;font-size:13px;color:var(--text);width:120px;outline:none}
        .name-input:focus{border-color:var(--accent)}
        </style>
        </head>
        <body>

        <!-- 펫 영역 -->
        <div class="card pet-card">
          <div id="speech" class="speech"></div>
          <div class="pet-img-wrap" onclick="tapPet()">
            <img id="petImg" class="pet-img" src="/img/default" onerror="this.style.display='none';document.getElementById('petEmoji').style.display='block'" />
            <div id="petEmoji" style="display:none;font-size:100px;line-height:1">🥔</div>
          </div>
          <div id="ddayBadges" style="display:flex;gap:4px;justify-content:center;flex-wrap:wrap;margin-bottom:4px"></div>
          <div class="pet-name" id="name">\(petName)</div>
          <div class="pet-mood" id="mood"></div>
          <div class="pet-weather" id="weather"></div>
          <div class="pet-action" id="action"></div>
          <div class="pet-time-msg" id="timeMsg"></div>
        </div>

        <!-- 레벨 -->
        <div class="card">
          <div class="info-row">
            <div class="level-badge" id="level">Lv.1</div>
            <div class="exp-wrap">
              <div class="exp-label">경험치</div>
              <div class="exp-track"><div class="exp-fill" id="exp" style="width:0%"></div></div>
            </div>
          </div>
        </div>

        <!-- 스탯 -->
        <div class="card">
          <div class="stats">
            <div class="stat"><span class="stat-emoji">🍚</span><span class="stat-name">배고픔</span><div class="stat-track"><div class="stat-bar" id="bar-hunger" style="width:0%;background:linear-gradient(90deg,#fdcb6e,#e17055)"></div></div><span class="stat-num" id="val-hunger">0</span></div>
            <div class="stat"><span class="stat-emoji">💗</span><span class="stat-name">기분</span><div class="stat-track"><div class="stat-bar" id="bar-happiness" style="width:0%;background:linear-gradient(90deg,#fd79a8,#e84393)"></div></div><span class="stat-num" id="val-happiness">0</span></div>
            <div class="stat"><span class="stat-emoji">⚡</span><span class="stat-name">에너지</span><div class="stat-track"><div class="stat-bar" id="bar-energy" style="width:0%;background:linear-gradient(90deg,#ffeaa7,#fdcb6e)"></div></div><span class="stat-num" id="val-energy">0</span></div>
            <div class="stat"><span class="stat-emoji">🫧</span><span class="stat-name">청결</span><div class="stat-track"><div class="stat-bar" id="bar-cleanliness" style="width:0%;background:linear-gradient(90deg,#81ecec,#00cec9)"></div></div><span class="stat-num" id="val-cleanliness">0</span></div>
            <div class="stat"><span class="stat-emoji">❤️</span><span class="stat-name">친밀도</span><div class="stat-track"><div class="stat-bar" id="bar-bond" style="width:0%;background:linear-gradient(90deg,#ff7675,#d63031)"></div></div><span class="stat-num" id="val-bond">0</span></div>
          </div>
        </div>

        <!-- 액션 -->
        <div class="card">
          <div class="actions">
            <div class="act" onclick="act('feed')"><span class="act-icon">🍚</span><span class="act-label">밥주기</span></div>
            <div class="act" onclick="act('play')"><span class="act-icon">🎾</span><span class="act-label">놀기</span></div>
            <div class="act" onclick="act('pet')"><span class="act-icon">✋</span><span class="act-label">쓰다듬기</span></div>
            <div class="act" onclick="act('bathe')"><span class="act-icon">🛁</span><span class="act-label">목욕</span></div>
            <div class="act" onclick="act('walk')"><span class="act-icon">🏃</span><span class="act-label">산책</span></div>
            <div class="act" id="sleepBtn" onclick="act('sleep')"><span class="act-icon">💤</span><span class="act-label">재우기</span></div>
          </div>
        </div>

        <!-- 네비게이션 -->
        <div class="btn-row">
          <a href="/chat" class="nav-btn btn-chat">💬 대화</a>
          <button class="nav-btn btn-todo" onclick="toggleTodo()">📋 할 일</button>
          <button class="nav-btn btn-secretary" id="secBtn" onclick="toggleSecretary()">🧠 비서</button>
        </div>
        <div class="btn-row" style="margin-top:6px">
          <button class="nav-btn" style="background:linear-gradient(135deg,#e17055,#fdcb6e)" onclick="toggleDDay()">📅 D-Day</button>
          <button class="nav-btn" style="background:linear-gradient(135deg,#636e72,#b2bec3);color:#fff" onclick="toggleSettings()">⚙️ 설정</button>
        </div>

        <div style="height:12px"></div>

        <!-- 포모도로 -->
        <div class="card pomo-card">
          <div class="sec-title">집중 모드</div>
          <div class="pomo-time" id="pomoTime">25:00</div>
          <div class="pomo-label" id="pomoPhase"></div>
        </div>

        <!-- D-Day -->
        <div class="card todo-card" id="ddaySection">
          <div class="sec-title">D-Day</div>
          <div style="display:flex;gap:6px;margin-bottom:10px;flex-wrap:wrap;align-items:center">
            <select id="ddayEmoji" style="background:var(--track);border:1px solid var(--card-border);border-radius:8px;padding:6px;font-size:16px;color:var(--text)">
              <option>📌</option><option>🎯</option><option>🎉</option><option>💼</option><option>✈️</option><option>💕</option><option>🎂</option><option>📝</option><option>⏰</option><option>🔥</option>
            </select>
            <input id="ddayTitle" type="text" placeholder="D-Day 이름" style="flex:1;min-width:80px;background:var(--track);border:1px solid var(--card-border);border-radius:10px;padding:7px 12px;font-size:13px;color:var(--text);outline:none" />
            <input id="ddayDate" type="date" style="background:var(--track);border:1px solid var(--card-border);border-radius:10px;padding:7px 10px;font-size:12px;color:var(--text);outline:none" />
            <button onclick="addDDay()" style="background:var(--accent);color:#fff;border:none;border-radius:10px;padding:7px 12px;font-size:12px;font-weight:600;cursor:pointer;white-space:nowrap">추가</button>
          </div>
          <ul class="todo-list" id="ddayList"></ul>
        </div>

        <!-- 할 일 -->
        <div class="card todo-card" id="todoSection">
          <div class="sec-title">할 일</div>
          <div style="display:flex;gap:8px;margin-bottom:10px">
            <input id="todoInput" type="text" placeholder="새 할 일 추가..." style="flex:1;background:var(--track);border:1px solid var(--card-border);border-radius:12px;padding:8px 14px;font-size:13px;color:var(--text);outline:none" />
            <button onclick="addTodo()" style="background:var(--accent);color:#fff;border:none;border-radius:12px;padding:8px 14px;font-size:13px;font-weight:600;cursor:pointer">추가</button>
          </div>
          <ul class="todo-list" id="todos"></ul>
        </div>

        <!-- 설정 -->
        <div class="card settings-card" id="settingsSection">
          <div class="sec-title">설정</div>
          <div class="setting-row">
            <div><div class="setting-label">펫 이름</div></div>
            <input class="name-input" id="nameInput" placeholder="이름" onchange="renamePet()" />
          </div>
          <div class="setting-row">
            <div><div class="setting-label">다크 모드</div><div class="setting-sub">테마 전환</div></div>
            <button class="theme-toggle" id="themeBtn" onclick="toggleTheme()"></button>
          </div>
        </div>


        <script>
        let currentMood='default',loadedImgKey='',isSecretary=false;
        let prevLevel=0,currentWeather='';

        // 날씨 이펙트
        function updateWeatherFx(cond){
          if(cond===currentWeather)return;
          currentWeather=cond;
          let old=document.getElementById('weatherCanvas');
          if(old)old.remove();
          if(!cond||cond==='')return;
          const cvs=document.createElement('canvas');
          cvs.id='weatherCanvas';
          cvs.style.cssText='position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:1';
          const pet=document.querySelector('.pet-card');
          pet.style.position='relative';
          pet.appendChild(cvs);
          const resize=()=>{cvs.width=pet.offsetWidth;cvs.height=pet.offsetHeight};
          resize();
          const ctx=cvs.getContext('2d');
          let raf,start=Date.now();
          function frame(){
            const dt=(Date.now()-start)/1000;
            ctx.clearRect(0,0,cvs.width,cvs.height);
            if(cond==='rain'||cond==='drizzle'||cond==='thunder'){
              const n=cond==='drizzle'?15:35;
              for(let i=0;i<n;i++){
                const x=(i*8.7+3)%(cvs.width);
                const sp=cond==='drizzle'?100:180;
                const v=sp+(i*3)%40;
                const y=((dt*v)+i*37)%(cvs.height+30)-15;
                ctx.strokeStyle='rgba(100,180,255,0.35)';
                ctx.lineWidth=1.5;
                ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x-1,y+(cond==='drizzle'?8:12));ctx.stroke();
              }
              if(cond==='thunder'){
                const cycle=dt%4.5;
                if(cycle<0.08||(cycle>0.15&&cycle<0.2)){
                  ctx.fillStyle='rgba(255,255,255,0.4)';
                  ctx.fillRect(0,0,cvs.width,cvs.height);
                }
              }
            }else if(cond==='snow'){
              for(let i=0;i<25;i++){
                const bx=(i*12.3+5)%cvs.width;
                const drift=Math.sin(dt*0.7+i*0.6)*20;
                const x=bx+drift;
                const v=25+(i*2.3)%15;
                const y=((dt*v)+i*43)%(cvs.height+20)-10;
                const r=2+(i%4);
                ctx.fillStyle='rgba(255,255,255,0.7)';
                ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill();
              }
            }else if(cond==='clear'){
              for(let i=0;i<12;i++){
                const x=(i*23.7+10)%cvs.width;
                const y=(i*37.3+15)%(cvs.height*0.5);
                const phase=(dt*0.4+i*0.55)%3;
                const op=phase<1.5?Math.sin(phase/1.5*Math.PI)*0.45:0;
                const r=phase<1.5?Math.sin(phase/1.5*Math.PI)*3.5+0.5:0;
                if(op>0.01){
                  ctx.fillStyle=`rgba(255,215,50,${op})`;
                  ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill();
                }
              }
            }else if(cond==='cloudy'){
              for(let i=0;i<5;i++){
                const bx=i*70;
                const x=(bx+dt*(6+i*1.5))%(cvs.width+80)-40;
                const y=15+i*22;
                ctx.fillStyle='rgba(150,150,150,0.12)';
                ctx.beginPath();ctx.ellipse(x+25,y+10,25+i*4,9+i*2,0,0,Math.PI*2);ctx.fill();
              }
            }else if(cond==='fog'){
              const op=0.1+Math.sin(dt*0.25)*0.04;
              ctx.fillStyle=`rgba(255,255,255,${op})`;
              ctx.fillRect(0,0,cvs.width,cvs.height);
            }else if(cond==='wind'){
              const emojis=['🍃'];
              ctx.font='14px serif';
              for(let i=0;i<8;i++){
                const v=55+i*12;
                const x=((dt*v)+i*45)%(cvs.width+40)-20;
                const by=(i*52+20)%(cvs.height*0.7);
                const y=by+Math.sin(dt*1.8+i)*18;
                ctx.fillText(emojis[0],x,y);
              }
            }
            raf=requestAnimationFrame(frame);
          }
          frame();
        }

        // 빵빠레
        function confetti(){
          const cvs=document.createElement('canvas');
          cvs.style.cssText='position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:9999';
          cvs.width=window.innerWidth;cvs.height=window.innerHeight;
          document.body.appendChild(cvs);
          const ctx=cvs.getContext('2d');
          const cols=['#ff6b6b','#ffd93d','#6bcf7f','#4ecdc4','#a29bfe','#fd79a8','#fdcb6e','#55efc4','#ff7675'];
          const ps=[];
          for(let i=0;i<60;i++){
            ps.push({x:cvs.width/2+(Math.random()-0.5)*80,y:cvs.height*0.4,
              vx:(Math.random()-0.5)*14,vy:-10-Math.random()*10,
              w:5+Math.random()*5,h:3+Math.random()*3,
              c:cols[i%cols.length],rot:Math.random()*360,rv:(Math.random()-0.5)*15});
          }
          let start=Date.now();
          // 레벨업 텍스트 표시
          const txt=document.createElement('div');
          txt.textContent='🎉 LEVEL UP! 🎉';
          txt.style.cssText='position:fixed;top:30%;left:50%;transform:translate(-50%,-50%);font-size:28px;font-weight:900;color:#fdcb6e;text-shadow:0 2px 12px rgba(0,0,0,0.3);z-index:10000;animation:pop 0.4s cubic-bezier(0.175,0.885,0.32,1.275)';
          document.body.appendChild(txt);
          if(navigator.vibrate)navigator.vibrate([50,50,100]);
          function frame(){
            const dt=(Date.now()-start)/1000;
            if(dt>3.5){cvs.remove();txt.remove();return;}
            ctx.clearRect(0,0,cvs.width,cvs.height);
            ps.forEach(p=>{
              p.x+=p.vx;p.vy+=0.35;p.y+=p.vy;p.rot+=p.rv;
              ctx.save();ctx.translate(p.x,p.y);ctx.rotate(p.rot*Math.PI/180);
              ctx.globalAlpha=Math.max(0,1-dt/3);
              ctx.fillStyle=p.c;ctx.fillRect(-p.w/2,-p.h/2,p.w,p.h);
              ctx.restore();
            });
            requestAnimationFrame(frame);
          }
          frame();
          setTimeout(()=>{txt.style.opacity='0';txt.style.transition='opacity 0.5s'},2000);
        }
        const S={happy:["오늘 기분 짱이야!","놀자놀자~!","히히 좋아좋아~"],normal:["뭐해~?","심심해~","같이 놀래?"],hungry:["꼬르륵...","밥...줘...","배고파앙..."],tired:["하아암~ 졸려...","눈이 감겨..."],sad:["나 잊은거 아니지...?","외로워..."],sleeping:["zzZ...","쿨쿨..."],angry:["흥!!","건드리지마!!"],work:["집중 중이야...!","방해하지마~"]};

        // 테마
        const savedTheme=localStorage.getItem('theme')||'light';
        document.documentElement.setAttribute('data-theme',savedTheme);
        if(savedTheme==='dark')document.getElementById('themeBtn')?.classList.add('on');

        function toggleTheme(){
          const html=document.documentElement;
          const curr=html.getAttribute('data-theme');
          const next=curr==='dark'?'light':'dark';
          html.setAttribute('data-theme',next);
          localStorage.setItem('theme',next);
          document.getElementById('themeBtn').classList.toggle('on');
          document.getElementById('themeColor').content=next==='dark'?'#0f0f1a':'#f5f0eb';
        }
        function toggleTodo(){document.getElementById('todoSection').classList.toggle('show')}
        function toggleSettings(){document.getElementById('settingsSection').classList.toggle('show')}
        function toggleSecretary(){
          fetch('/api/toggleMode').then(()=>{loadedImgKey='';setTimeout(update,200)});
        }
        function renamePet(){
          const v=document.getElementById('nameInput').value.trim();
          if(v)fetch('/api/rename?name='+encodeURIComponent(v)).then(()=>setTimeout(update,200));
        }
        function tapPet(){
          const el=document.getElementById('speech');
          const m=S[currentMood]||S.normal;
          el.textContent=m[Math.floor(Math.random()*m.length)];
          el.classList.add('show');
          setTimeout(()=>el.classList.remove('show'),2500);
          fetch('/api/pet').then(()=>setTimeout(update,200));
          if(navigator.vibrate)navigator.vibrate(30);
        }
        function update(){
          fetch('/api/status').then(r=>r.json()).then(d=>{
            currentMood=d.mood;isSecretary=d.secretary;
            const img=document.getElementById('petImg'),em=document.getElementById('petEmoji');
            const k=d.secretary?'assistant':d.mood;
            if(k!==loadedImgKey){loadedImgKey=k;img.src='/img/'+k+'?t='+Date.now();img.style.display='block';em.style.display='none';img.onerror=function(){this.style.display='none';em.style.display='block';em.textContent=d.emoji;loadedImgKey=''};}
            document.getElementById('name').textContent=d.name;
            document.getElementById('mood').textContent=d.emoji+' '+d.label;
            document.getElementById('level').textContent='Lv.'+d.level;
            document.getElementById('exp').style.width=(d.expNext>0?d.exp/d.expNext*100:0)+'%';
            document.getElementById('action').textContent=d.action||'';
            if(d.weather){document.getElementById('weather').textContent=d.weather;
              const wc=d.weather.includes('맑음')?'clear':d.weather.includes('비')?'rain':d.weather.includes('이슬비')?'drizzle':d.weather.includes('눈')?'snow':d.weather.includes('천둥')?'thunder':d.weather.includes('흐림')?'cloudy':d.weather.includes('안개')?'fog':d.weather.includes('바람')?'wind':'';
              updateWeatherFx(wc);
            }
            // 레벨업 감지
            const lv=d.level;
            if(prevLevel>0&&lv>prevLevel)confetti();
            prevLevel=lv;
            const tm=document.getElementById('timeMsg');
            if(d.timeMsg){tm.textContent=d.timeMsg;tm.classList.add('show');}else{tm.classList.remove('show');}
            ['hunger','happiness','energy','cleanliness','bond'].forEach(k=>{
              document.getElementById('bar-'+k).style.width=d[k]+'%';
              document.getElementById('val-'+k).textContent=d[k];
            });
            const sb=document.getElementById('sleepBtn');
            if(d.sleeping){sb.innerHTML='<span class="act-icon">⏰</span><span class="act-label">깨우기</span>';sb.onclick=()=>act('wake');}
            else{sb.innerHTML='<span class="act-icon">💤</span><span class="act-label">재우기</span>';sb.onclick=()=>act('sleep');}
            const sec=document.getElementById('secBtn');
            if(d.secretary){sec.textContent='🧠 비서 ON';sec.classList.add('on');}
            else{sec.textContent='🧠 비서';sec.classList.remove('on');}
            document.getElementById('pomoTime').textContent=d.pomoTime;
            const pp=d.pomodoro;
            document.getElementById('pomoPhase').textContent=pp==='focusing'?'🔥 집중 중':pp==='breaking'?'😌 휴식 중':pp==='paused'?'⏸ 일시정지':'';
            if(!document.getElementById('nameInput').value)document.getElementById('nameInput').value=d.name;
            // D-Day 배지
            const db=document.getElementById('ddayBadges');
            if(d.ddays&&d.ddays.length>0){
              db.innerHTML=d.ddays.map(t=>{
                const isUrgent=t.includes('D-DAY')||t.includes('D-1')||t.includes('D-2')||t.includes('D-3');
                return `<span style="font-size:9px;font-weight:700;padding:3px 8px;border-radius:10px;background:${isUrgent?'#e17055':'rgba(255,255,255,0.15)'};color:${isUrgent?'#fff':'var(--sub)'}">${t}</span>`;
              }).join('');
            } else { db.innerHTML=''; }
          }).catch(()=>{});
        }
        function act(a){
          const L={feed:'🍚 밥 줬어!',play:'🎾 놀아줬어!',pet:'✋ 쓰다듬었어!',bathe:'🛁 목욕시켰어!',walk:'🏃 산책!',sleep:'💤 재웠어!',wake:'⏰ 깨웠어!'};
          document.getElementById('action').textContent=L[a]||'✨';
          if(navigator.vibrate)navigator.vibrate(20);
          fetch('/api/'+a).then(()=>setTimeout(update,200));
        }
        function toggleDDay(){document.getElementById('ddaySection').classList.toggle('show')}
        function addDDay(){
          const title=document.getElementById('ddayTitle').value.trim();
          const date=document.getElementById('ddayDate').value;
          const emoji=document.getElementById('ddayEmoji').value;
          if(!title||!date)return;
          document.getElementById('ddayTitle').value='';
          fetch('/api/dday/add?title='+encodeURIComponent(title)+'&date='+date+'&emoji='+encodeURIComponent(emoji)).then(()=>loadDDays());
          if(navigator.vibrate)navigator.vibrate(15);
        }
        function deleteDDayItem(id){
          fetch('/api/dday/delete?id='+encodeURIComponent(id)).then(()=>loadDDays());
        }
        function loadDDays(){
          fetch('/api/ddays').then(r=>r.json()).then(d=>{
            const el=document.getElementById('ddayList');
            if(!d.items||d.items.length===0){el.innerHTML='<li style="color:var(--sub)">D-Day 없음 📅</li>';return;}
            el.innerHTML=d.items.map(i=>{
              const urgent=i.dday===0;
              const soon=i.dday>0&&i.dday<=3;
              const color=urgent?'#e17055':(soon?'#e17055':'var(--accent)');
              const bg=urgent?'#e17055':(soon?'#fdcb6e':color);
              return `<li><span style="font-size:16px">${i.emoji}</span><span style="flex:1">${i.title}</span><span style="font-size:11px;font-weight:800;color:#fff;padding:2px 8px;border-radius:8px;background:${bg}">${i.ddayText}</span><span style="cursor:pointer;color:var(--sub);font-size:11px;margin-left:6px" onclick="deleteDDayItem('${i.id}')">✕</span></li>`;
            }).join('');
          }).catch(()=>{});
        }
        function addTodo(){
          const inp=document.getElementById('todoInput');
          const v=inp.value.trim();
          if(!v)return;
          inp.value='';
          fetch('/api/todo/add?title='+encodeURIComponent(v)).then(()=>loadTodos());
          if(navigator.vibrate)navigator.vibrate(15);
        }
        document.getElementById('todoInput')?.addEventListener('keydown',e=>{
          if(e.key==='Enter'&&!e.isComposing)addTodo();
        });
        function toggleTodoItem(id){
          fetch('/api/todo/toggle?id='+encodeURIComponent(id)).then(()=>loadTodos());
          if(navigator.vibrate)navigator.vibrate(15);
        }
        function deleteTodoItem(id){
          fetch('/api/todo/delete?id='+encodeURIComponent(id)).then(()=>loadTodos());
        }
        function loadTodos(){
          fetch('/api/todos').then(r=>r.json()).then(d=>{
            const tl=document.getElementById('todos');
            if(!d.items||d.items.length===0){tl.innerHTML='<li style="color:var(--sub)">할 일 없음 😊</li>';return;}
            const pending=d.items.filter(i=>!i.done);
            const done=d.items.filter(i=>i.done);
            let html='';
            pending.forEach(i=>{
              html+=`<li><span class="todo-dot"></span><span style="flex:1;cursor:pointer" onclick="toggleTodoItem('${i.id}')">${i.title}</span><span style="cursor:pointer;color:var(--sub);font-size:11px" onclick="deleteTodoItem('${i.id}')">✕</span></li>`;
            });
            if(done.length>0){
              html+='<li style="color:var(--sub);font-size:10px;border:none;padding:6px 0 2px">완료됨</li>';
              done.forEach(i=>{
                html+=`<li style="opacity:0.5"><span style="color:#00b894">✓</span><span style="flex:1;text-decoration:line-through;cursor:pointer" onclick="toggleTodoItem('${i.id}')">${i.title}</span><span style="cursor:pointer;color:var(--sub);font-size:11px" onclick="deleteTodoItem('${i.id}')">✕</span></li>`;
              });
            }
            tl.innerHTML=html;
          }).catch(()=>{});
        }
        update();setInterval(update,2000);
        loadTodos();setInterval(loadTodos,5000);
        loadDDays();setInterval(loadDDays,10000);
        </script>
        </body>
        </html>
        """
    }

    private func renderChatPage() -> String {
        let petName = petManager?.name ?? "펫"
        return """
        <!DOCTYPE html>
        <html lang="ko" data-theme="light">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no, viewport-fit=cover">
        <meta name="apple-mobile-web-app-capable" content="yes">
        <title>\(petName) - 대화</title>
        <style>
        *{margin:0;padding:0;box-sizing:border-box}
        [data-theme="light"]{--bg:#f5f0eb;--header:#fff;--header-border:rgba(0,0,0,0.06);--text:#2d2d2d;--sub:#999;--input-bg:#f0ebe5;--input-border:rgba(0,0,0,0.08);--user-bubble:linear-gradient(135deg,#6c5ce7,#a29bfe);--user-text:#fff;--bot-bubble:#fff;--bot-text:#2d2d2d;--bot-shadow:0 1px 4px rgba(0,0,0,0.06);--sys-bg:#fff8e1;--sys-text:#f57c00;--accent:#6c5ce7;--mode-bg:rgba(108,92,231,0.1);--mode-active:linear-gradient(135deg,#6c5ce7,#a29bfe);--send-bg:linear-gradient(135deg,#6c5ce7,#a29bfe)}
        [data-theme="dark"]{--bg:#0f0f1a;--header:rgba(255,255,255,0.05);--header-border:rgba(255,255,255,0.08);--text:#f0f0f0;--sub:#666;--input-bg:rgba(255,255,255,0.06);--input-border:rgba(255,255,255,0.1);--user-bubble:linear-gradient(135deg,#6c5ce7,#a29bfe);--user-text:#fff;--bot-bubble:rgba(255,255,255,0.08);--bot-text:#eee;--bot-shadow:none;--sys-bg:rgba(245,124,0,0.15);--sys-text:#ffb74d;--accent:#a29bfe;--mode-bg:rgba(162,155,254,0.15);--mode-active:linear-gradient(135deg,#6c5ce7,#a29bfe);--send-bg:linear-gradient(135deg,#6c5ce7,#a29bfe)}
        body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:var(--bg);color:var(--text);height:100vh;height:100dvh;display:flex;flex-direction:column;transition:all 0.3s}

        .header{display:flex;align-items:center;padding:calc(env(safe-area-inset-top,12px) + 8px) 16px 12px;background:var(--header);border-bottom:1px solid var(--header-border);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);gap:10px}
        .back{color:var(--accent);text-decoration:none;font-size:22px;font-weight:300;line-height:1}
        .header-center{flex:1;text-align:center}
        .header-name{font-size:15px;font-weight:700}
        .header-sub{font-size:10px;color:var(--sub)}
        .pet-avatar{width:32px;height:32px;border-radius:50%;object-fit:cover;background:var(--input-bg)}
        .mode-btn{font-size:11px;font-weight:600;padding:5px 10px;border-radius:12px;border:none;cursor:pointer;-webkit-tap-highlight-color:transparent;transition:all 0.2s;background:var(--mode-bg);color:var(--accent)}
        .mode-btn.on{background:var(--mode-active);color:#fff}

        .msgs{flex:1;overflow-y:auto;padding:16px 12px;display:flex;flex-direction:column;gap:10px;-webkit-overflow-scrolling:touch}
        .msg-row{display:flex;gap:8px;max-width:85%}
        .msg-row.user{align-self:flex-end;flex-direction:row-reverse}
        .msg-row.system{align-self:center;max-width:90%}
        .msg-avatar{width:28px;height:28px;border-radius:50%;object-fit:cover;flex-shrink:0;margin-top:2px;background:var(--input-bg)}
        .msg-content{display:flex;flex-direction:column;gap:2px}
        .msg-sender{font-size:10px;color:var(--sub);font-weight:500}
        .msg-row.user .msg-sender{text-align:right}
        .msg-bubble{padding:10px 14px;border-radius:16px;font-size:13px;line-height:1.6;word-break:break-word;white-space:pre-wrap}
        .msg-row.user .msg-bubble{background:var(--user-bubble);color:var(--user-text);border-bottom-right-radius:4px}
        .msg-row.assistant .msg-bubble{background:var(--bot-bubble);color:var(--bot-text);border-bottom-left-radius:4px;box-shadow:var(--bot-shadow)}
        .msg-row.system .msg-bubble{background:var(--sys-bg);color:var(--sys-text);font-size:11px;text-align:center;border-radius:10px}
        .typing{align-self:flex-start;color:var(--sub);font-size:12px;padding:4px 12px;display:flex;align-items:center;gap:6px}
        .typing-dots{display:flex;gap:3px}
        .typing-dots span{width:6px;height:6px;border-radius:50%;background:var(--sub);animation:dotPulse 1.4s ease-in-out infinite}
        .typing-dots span:nth-child(2){animation-delay:0.2s}
        .typing-dots span:nth-child(3){animation-delay:0.4s}
        @keyframes dotPulse{0%,100%{opacity:0.3;transform:scale(0.8)}50%{opacity:1;transform:scale(1)}}

        .input-wrap{display:flex;align-items:center;gap:8px;padding:10px 12px calc(env(safe-area-inset-bottom,10px) + 2px);background:var(--header);border-top:1px solid var(--header-border);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px)}
        .input-wrap input{flex:1;background:var(--input-bg);border:1px solid var(--input-border);border-radius:22px;padding:10px 18px;color:var(--text);font-size:14px;outline:none;transition:border 0.2s}
        .input-wrap input::placeholder{color:var(--sub)}
        .input-wrap input:focus{border-color:var(--accent)}
        .send-btn{width:38px;height:38px;border-radius:50%;border:none;background:var(--send-bg);color:#fff;font-size:16px;cursor:pointer;-webkit-tap-highlight-color:transparent;display:flex;align-items:center;justify-content:center;transition:all 0.15s;flex-shrink:0}
        .send-btn:active{transform:scale(0.9)}
        .send-btn:disabled{opacity:0.3}
        .send-btn svg{width:18px;height:18px;fill:currentColor}
        </style>
        </head>
        <body>
        <div class="header">
          <a href="/" class="back">‹</a>
          <img class="pet-avatar" id="avatar" src="/img/default" onerror="this.style.display='none'" />
          <div class="header-center">
            <div class="header-name" id="chatTitle">\(petName)</div>
            <div class="header-sub" id="chatSub">대화 중</div>
          </div>
          <button class="mode-btn" id="modeBtn" onclick="toggleMode()">🧠 비서</button>
        </div>
        <div class="msgs" id="msgs"></div>
        <div class="input-wrap">
          <input id="input" type="text" placeholder="메시지 입력..." autocomplete="off" />
          <button class="send-btn" id="sendBtn" onclick="send()"><svg viewBox="0 0 24 24"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg></button>
        </div>
        <script>
        // 테마 동기화
        const t=localStorage.getItem('theme')||'light';
        document.documentElement.setAttribute('data-theme',t);

        let polling=null,lastCount=0;

        function toggleMode(){
          fetch('/api/toggleMode').then(()=>{lastCount=0;setTimeout(loadMessages,150)});
        }

        function loadMessages(){
          fetch('/api/messages').then(r=>r.json()).then(d=>{
            const box=document.getElementById('msgs');
            const btn=document.getElementById('modeBtn');
            const title=document.getElementById('chatTitle');
            const sub=document.getElementById('chatSub');
            const avatar=document.getElementById('avatar');
            if(d.secretary){
              btn.classList.add('on');btn.textContent='🧠 ON';
              title.textContent='비서 모드';sub.textContent='AI 비서';
              avatar.src='/img/assistant?t='+Date.now();
            } else {
              btn.classList.remove('on');btn.textContent='🧠 비서';
              title.textContent='\(petName)';sub.textContent='대화 중';
              avatar.src='/img/default';
            }

            if(d.messages.length!==lastCount){
              lastCount=d.messages.length;
              box.innerHTML='';
              d.messages.forEach(m=>{
                const row=document.createElement('div');
                row.className='msg-row '+m.role;
                if(m.role==='system'){
                  row.innerHTML='<div class="msg-content"><div class="msg-bubble">'+esc(m.content)+'</div></div>';
                } else if(m.role==='user'){
                  row.innerHTML='<div class="msg-content"><div class="msg-sender">나</div><div class="msg-bubble">'+esc(m.content)+'</div></div>';
                } else {
                  const name=d.secretary?'비서':'\(petName)';
                  row.innerHTML='<img class="msg-avatar" src="/img/'+(d.secretary?'assistant':'default')+'" onerror="this.style.display=\\'none\\'"/><div class="msg-content"><div class="msg-sender">'+name+'</div><div class="msg-bubble">'+esc(m.content)+'</div></div>';
                }
                box.appendChild(row);
              });
              if(d.chatting){
                const t=document.createElement('div');
                t.className='typing';
                t.innerHTML='<div class="typing-dots"><span></span><span></span><span></span></div> 생각 중...';
                box.appendChild(t);
              }
              box.scrollTop=box.scrollHeight;
            } else if(d.chatting){
              if(!box.querySelector('.typing')){
                const t=document.createElement('div');
                t.className='typing';
                t.innerHTML='<div class="typing-dots"><span></span><span></span><span></span></div> 생각 중...';
                box.appendChild(t);
                box.scrollTop=box.scrollHeight;
              }
            } else {
              const t=box.querySelector('.typing');
              if(t)t.remove();
            }
            document.getElementById('sendBtn').disabled=d.chatting;
          }).catch(()=>{});
        }

        function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\\n/g,'<br>')}

        function send(){
          const input=document.getElementById('input');
          const msg=input.value.trim();
          if(!msg)return;
          input.value='';
          const box=document.getElementById('msgs');
          const row=document.createElement('div');
          row.className='msg-row user';
          row.innerHTML='<div class="msg-content"><div class="msg-sender">나</div><div class="msg-bubble">'+esc(msg)+'</div></div>';
          box.appendChild(row);
          box.scrollTop=box.scrollHeight;
          document.getElementById('sendBtn').disabled=true;
          if(navigator.vibrate)navigator.vibrate(15);

          fetch('/api/chat?msg='+encodeURIComponent(msg)).then(()=>{
            if(polling)clearInterval(polling);
            polling=setInterval(loadMessages,500);
            setTimeout(()=>{if(polling)clearInterval(polling);polling=setInterval(loadMessages,1500)},15000);
          });
        }

        document.getElementById('input').addEventListener('keydown',e=>{
          if(e.key==='Enter'&&!e.isComposing)send();
        });
        loadMessages();
        polling=setInterval(loadMessages,1500);
        </script>
        </body>
        </html>
        """
    }

    func getLocalIP() -> String {
        var address = "localhost"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return address }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let sa = ptr.pointee.ifa_addr.pointee
            guard sa.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            guard name == "en0" || name == "en1" else { continue }
            var addr = ptr.pointee.ifa_addr.pointee
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(&addr, socklen_t(sa.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            address = String(cString: hostname)
            break
        }
        return address
    }
}
