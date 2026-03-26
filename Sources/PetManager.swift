import Foundation
import AppKit

class PetManager: ObservableObject {
    @Published var name: String = "나의 펫"
    @Published var hunger: Double = 80
    @Published var happiness: Double = 80
    @Published var energy: Double = 80
    @Published var cleanliness: Double = 80
    @Published var bond: Double = 10
    @Published var experience: Double = 0
    @Published var level: Int = 1
    @Published var isSleeping: Bool = false
    @Published var lastAction: String? = nil
    @Published var actionMood: PetMood? = nil
    @Published var isSecretaryMode: Bool = false
    @Published var useBuiltInCharacter: Bool = UserDefaults.standard.bool(forKey: "useBuiltInCharacter")
    @Published var timeMessage: String? = nil
    @Published var walkState: String = "idle"  // idle, walking, sitting
    @Published var walkDirection: CGFloat = 1  // 1=오른쪽, -1=왼쪽
    @Published var reminders: [[String: String]] = []  // [{id, message, time}]
    @Published var clipboardSuggestion: String? = nil
    @Published var clipboardText: String? = nil
    @Published var clipboardType: String = ""  // translate, summarize, url
    private var lastPBCount: Int = NSPasteboard.general.changeCount
    let weatherService = WeatherService()

    private var lastUpdateTime: Date = Date()
    private var timer: Timer?
    private var imageCache: [String: NSImage] = [:]
    private var feedWorkItems: [DispatchWorkItem] = []
    private var triggeredEvents: Set<String> = []
    private var lastEventDate: String = ""
    private var batteryCounter = 0

    static let imagesDirectory: String = {
        // 실행 파일 기준으로 프로젝트 루트 탐색 (.build/arch/config/DesktopPet → 4단계 위)
        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
            .resolvingSymlinksInPath()
        var projectRoot = execURL
        for _ in 0..<4 { projectRoot = projectRoot.deletingLastPathComponent() }
        let candidate = projectRoot.appendingPathComponent("Images").path
        if FileManager.default.fileExists(atPath: candidate) { return candidate }
        // 폴백: 홈 기준 고정 경로
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Desktop/project/DesktopPet/Images"
    }()

    var mood: PetMood {
        if isSleeping { return .sleeping }
        if cleanliness < 25 { return .dirty }
        if hunger < 30 { return .hungry }
        if energy < 30 { return .tired }
        if happiness < 20 { return .angry }
        if happiness < 35 { return .sad }
        if happiness > 70 && hunger > 50 && energy > 50 { return .happy }
        return .normal
    }

    var displayMood: PetMood {
        actionMood ?? mood
    }

    var expForNextLevel: Double {
        Double(level * 100)
    }

    init() {
        load()
        applyOfflineDecay()
        startTimer()
        startClipboardMonitor()
    }

    private func startClipboardMonitor() {
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.checkClipboard() }
        }
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastPBCount else { return }
        lastPBCount = pb.changeCount
        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count > 5 else { return }

        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        clipboardText = t

        // URL 감지
        if let url = URL(string: t), url.scheme?.hasPrefix("http") == true {
            clipboardType = "url"
            clipboardSuggestion = "🔗 링크 복사됨! 열어줄까?"
        }
        // 영어 감지 (한글 없고 영문 있음)
        else if t.range(of: "[a-zA-Z]{4,}", options: .regularExpression) != nil &&
                t.range(of: "[가-힣]", options: .regularExpression) == nil {
            clipboardType = "translate"
            clipboardSuggestion = "🌏 영어 감지! 번역해줄까?"
        }
        // 긴 텍스트
        else if t.count > 200 {
            clipboardType = "summarize"
            clipboardSuggestion = "📄 긴 글 복사됨! 요약해줄까?"
        }
        // 짧은 텍스트
        else if t.count > 20 {
            clipboardType = "translate"
            clipboardSuggestion = "📋 복사됨! 번역/검색해줄까?"
        }
        else {
            clipboardSuggestion = nil
            return
        }

        // 8초 후 자동 숨김
        let suggestion = clipboardSuggestion
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            if self?.clipboardSuggestion == suggestion {
                self?.clipboardSuggestion = nil
            }
        }
    }

    private func applyOfflineDecay() {
        let elapsed = Date().timeIntervalSince(lastUpdateTime)
        let minutes = elapsed / 60.0
        let decay = min(minutes / 5.0, 40.0)
        if decay > 1 {
            hunger = max(0, hunger - decay)
            happiness = max(0, happiness - decay * 0.5)
            energy = max(0, energy - decay * 0.3)
            cleanliness = max(0, cleanliness - decay * 0.4)
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
    }

    private func tick() {
        // 리마인더는 항상 체크 (자는 중에도)
        checkReminders()

        if isSleeping {
            energy = min(100, energy + 3)
            if energy >= 100 {
                isSleeping = false
            }
            return
        }
        hunger = max(0, hunger - 0.5)
        happiness = max(0, happiness - 0.3)
        energy = max(0, energy - 0.2)
        cleanliness = max(0, cleanliness - 0.2)
        lastUpdateTime = Date()
        checkTimeEvents()
    }

    private func checkReminders() {
        let now = Date()
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter()
        var fired: [String] = []

        for reminder in reminders {
            guard let id = reminder["id"],
                  let timeStr = reminder["time"],
                  let msg = reminder["message"] else { continue }
            let targetDate = f.date(from: timeStr) ?? f2.date(from: timeStr)
            guard let target = targetDate else { continue }
            if now >= target {
                showTimeMessage("⏰ \(msg)")
                NSSound.beep()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSSound.beep() }
                fired.append(id)
            }
        }

        if !fired.isEmpty {
            reminders.removeAll { r in fired.contains(r["id"] ?? "") }
            // Firebase에서도 삭제
            for id in fired {
                let url = URL(string: "https://desktoppet-ba9ae-default-rtdb.firebaseio.com/reminders/\(id).json")!
                var req = URLRequest(url: url)
                req.httpMethod = "DELETE"
                URLSession.shared.dataTask(with: req).resume()
            }
        }
    }

    func completedPomodoro() {
        gainExp(20)
        gainBond(2)
        happiness = min(100, happiness + 10)
        showAction("🔥 집중 완료! 대단해!")
        save()
    }

    func completedTodo() {
        gainExp(3)
        happiness = min(100, happiness + 5)
        showAction("✅ 잘했어!")
        save()
    }

    private func gainExp(_ amount: Double) {
        experience += amount
        while experience >= expForNextLevel {
            experience -= expForNextLevel
            level += 1
            showAction("🎉 레벨 \(level) 달성!")
        }
    }

    private func gainBond(_ amount: Double) {
        bond = min(100, bond + amount)
    }

    // MARK: - 행동

    func feed() {
        guard !isSleeping else { return }
        // 이전 애니메이션 시퀀스 취소
        feedWorkItems.forEach { $0.cancel() }
        feedWorkItems.removeAll()

        hunger = min(100, hunger + 25)
        happiness = min(100, happiness + 5)
        gainExp(5)
        gainBond(1)
        showAction("🍳 요리 중~!")
        actionMood = .cook

        let eat = DispatchWorkItem { [weak self] in
            self?.showAction("🍴 냠냠냠~!")
            self?.actionMood = .eat
        }
        let full = DispatchWorkItem { [weak self] in
            self?.showAction("😋 배불러~!")
            self?.actionMood = .full
        }
        let done = DispatchWorkItem { [weak self] in
            self?.actionMood = nil
        }
        feedWorkItems = [eat, full, done]
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: eat)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: full)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: done)
        save()
    }

    func play() {
        guard !isSleeping else { return }
        happiness = min(100, happiness + 20)
        energy = max(0, energy - 10)
        hunger = max(0, hunger - 5)
        gainExp(8)
        gainBond(2)
        showAction("🎾 신난다!")
        save()
    }

    func pet() {
        guard !isSleeping else { return }
        happiness = min(100, happiness + 10)
        gainExp(3)
        gainBond(3)
        showAction("😊 좋아좋아~")
        save()
    }

    func bathe() {
        guard !isSleeping else { return }
        cleanliness = min(100, cleanliness + 30)
        happiness = min(100, happiness + 5)
        gainExp(5)
        gainBond(1)
        showAction("🛁 뽀득뽀득!")
        showActionMood(.bathing, duration: 3.0)
        save()
    }

    func walk() {
        guard !isSleeping else { return }
        happiness = min(100, happiness + 15)
        energy = max(0, energy - 15)
        hunger = max(0, hunger - 10)
        cleanliness = max(0, cleanliness - 5)
        gainExp(12)
        gainBond(3)
        showAction("🏃 산책 좋아!")
        save()
    }

    func sleep() {
        isSleeping = true
        showAction("💤 잘자...")
        save()
    }

    func wake() {
        isSleeping = false
        gainExp(2)
        // 깨우면 잠깐 화남
        showAction("😤 왜 깨워...!")
        showActionMood(.angry, duration: 2.0)
        happiness = max(0, happiness - 5)
        save()
    }

    func showAction(_ text: String) {
        lastAction = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.lastAction = nil
        }
    }

    private func showActionMood(_ mood: PetMood, duration: Double) {
        actionMood = mood
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            if self?.actionMood == mood {
                self?.actionMood = nil
            }
        }
    }

    // MARK: - 시간 반응

    func showTimeMessage(_ text: String) {
        timeMessage = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            if self?.timeMessage == text { self?.timeMessage = nil }
        }
    }

    private func checkTimeEvents() {
        let cal = Calendar.current
        let now = Date()
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)

        // 날짜 바뀌면 이벤트 리셋
        let todayStr = cal.startOfDay(for: now).description
        if todayStr != lastEventDate {
            triggeredEvents.removeAll()
            lastEventDate = todayStr
        }

        let w = weatherService.condition
        let temp = weatherService.temperature

        // 아침 인사
        event("morning", h, m, 7, 0, 7, 30, [
            "좋은 아침! 오늘도 화이팅~ ☀️",
            "일어났어? 좋은 하루 보내! 🌅",
            "으앙~ 아침이다... 같이 힘내자!",
        ])

        // 출근 준비 (날씨 연동)
        var workMsgs = ["출근 시간이야! 준비해~ 🏃", "슬슬 나갈 준비하자!"]
        if w == .rain || w == .drizzle || w == .thunder { workMsgs.append("비 온다! 우산 꼭 챙겨!! ☂️") }
        if w == .snow { workMsgs.append("눈 온다! 미끄러우니 조심해! ❄️") }
        if temp < 5 { workMsgs.append("오늘 \(Int(temp))도... 따뜻하게 입어! 🧣") }
        if temp > 30 { workMsgs.append("오늘 \(Int(temp))도... 더워! 물 챙겨! 💧") }
        event("workSoon", h, m, 8, 45, 9, 0, workMsgs)

        // 지각 경고
        event("workLate", h, m, 9, 15, 9, 25, [
            "지각하겠다!! 빨리빨리!! 🚨",
            "9시 반이야!! 뛰어!!!",
        ])

        // 오전 중간
        event("midMorning", h, m, 10, 30, 10, 40, [
            "물 마셨어? 수분 보충해~ 💧",
            "열심히 하고 있지? 스트레칭도 해!",
            "잠깐 눈 좀 쉬어~ 👀",
        ])

        // 점심
        event("lunch", h, m, 11, 55, 12, 5, [
            "점심시간이다!! 밥 먹자!! 🍚",
            "배고파... 뭐 먹을 거야?! 🤤",
            "밥!! 밥!! 밥!! 🍱",
        ])

        // 점심 후
        event("afterLunch", h, m, 13, 0, 13, 10, [
            "식곤증 조심~! 졸리면 스트레칭해! 🥱",
            "커피 한 잔 어때? ☕️",
            "배부르다... 으응...",
        ])

        // 오후
        event("afternoon", h, m, 15, 0, 15, 10, [
            "오후도 파이팅! 간식 먹을까? 🍪",
            "조금만 더 힘내! 💪",
        ])

        // 퇴근 임박
        event("preQuit", h, m, 17, 45, 17, 55, [
            "퇴근 15분 전! 마무리하자~ 🎉",
            "거의 다 왔어!! 조금만!!",
        ])

        // 퇴근
        event("quitTime", h, m, 18, 0, 18, 10, [
            "퇴근이다!! 수고했어!! 🎊",
            "오늘도 고생했어! 푹 쉬어~ 🏠",
            "자유다!!! 🕊️",
        ])

        // 저녁
        event("evening", h, m, 20, 0, 20, 10, [
            "오늘 하루 수고했어~ 좀 쉬어! 🛋",
            "저녁은 먹었어? 굶지 마~",
        ])

        // 취침 권유
        event("bedTime", h, m, 22, 30, 22, 40, [
            "슬슬 잘 시간이야~ 내일도 힘내자! 🌙",
            "오늘 하루 잘 보냈어! 잘 자~ 💤",
        ])

        // 야간
        event("lateNight", h, m, 0, 0, 0, 10, [
            "아직도 안 자?! 빨리 자!! 😠",
            "새벽이야... 몸에 안 좋아! 자!!! 🛌",
        ])

        // 배터리 체크 (5분마다)
        batteryCounter += 1
        if batteryCounter >= 10 {
            batteryCounter = 0
            checkBattery()
        }
    }

    private func event(_ id: String, _ h: Int, _ m: Int, _ sh: Int, _ sm: Int, _ eh: Int, _ em: Int, _ msgs: [String]) {
        guard !triggeredEvents.contains(id) else { return }
        let now = h * 60 + m
        let start = sh * 60 + sm
        let end = eh * 60 + em
        if now >= start && now <= end {
            triggeredEvents.insert(id)
            showTimeMessage(msgs.randomElement() ?? "")
        }
    }

    private func checkBattery() {
        guard !triggeredEvents.contains("battery_low") else { return }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return }
        process.waitUntilExit()
        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8),
              let range = output.range(of: "\\d+%", options: .regularExpression),
              let level = Int(output[range].dropLast()) else { return }
        if level <= 20 {
            triggeredEvents.insert("battery_low")
            showTimeMessage("배터리 \(level)%!! 충전해!! 🔋🪫")
        }
    }

    // MARK: - 저장/불러오기

    func save() {
        lastUpdateTime = Date()
        let data = PetSaveData(
            name: name, hunger: hunger, happiness: happiness,
            energy: energy, cleanliness: cleanliness, bond: bond,
            experience: experience, level: level,
            isSleeping: isSleeping, lastUpdateTime: lastUpdateTime
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "desktopPetSaveData")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "desktopPetSaveData"),
              let saved = try? JSONDecoder().decode(PetSaveData.self, from: data) else { return }
        name = saved.name
        hunger = saved.hunger
        happiness = saved.happiness
        energy = saved.energy
        cleanliness = saved.cleanliness
        bond = saved.bond
        experience = saved.experience
        level = saved.level
        isSleeping = saved.isSleeping
        lastUpdateTime = saved.lastUpdateTime
    }

    // MARK: - 이미지 로딩

    private var assistantImages: [NSImage] = []
    private var assistantLoaded = false

    func loadAssistantImage() -> NSImage? {
        if !assistantLoaded {
            assistantLoaded = true
            let dir = Self.imagesDirectory
            // assistant, assistant1, assistant2, ... 순서로 로드
            for name in ["assistant", "assistant1", "assistant2", "assistant3", "assistant4", "assistant5"] {
                for ext in ["png", "jpg", "jpeg", "gif", "svg", "webp"] {
                    let path = "\(dir)/\(name).\(ext)"
                    if let image = NSImage(contentsOfFile: path) {
                        assistantImages.append(removeCheckerBackground(from: image))
                        break
                    }
                }
            }
        }
        return assistantImages.randomElement()
    }

    func loadImage(for mood: PetMood) -> NSImage? {
        // 캐시 확인
        if let cached = imageCache[mood.rawValue] {
            return cached
        }

        let dir = Self.imagesDirectory
        for ext in ["png", "jpg", "jpeg", "gif", "svg", "webp"] {
            let path = "\(dir)/\(mood.rawValue).\(ext)"
            if let image = NSImage(contentsOfFile: path) {
                let processed = removeCheckerBackground(from: image)
                imageCache[mood.rawValue] = processed
                return processed
            }
        }
        // 기본 이미지
        if let cached = imageCache["default"] {
            return cached
        }
        for ext in ["png", "jpg", "jpeg", "gif", "svg", "webp"] {
            let path = "\(dir)/default.\(ext)"
            if let image = NSImage(contentsOfFile: path) {
                let processed = removeCheckerBackground(from: image)
                imageCache["default"] = processed
                return processed
            }
        }
        return nil
    }

    // 체크무늬 배경 + 흰 배경 제거
    private func removeCheckerBackground(from image: NSImage) -> NSImage {
        let size = image.size
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return image }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        guard let newBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4 * width,
            bitsPerPixel: 32
        ) else { return image }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newBitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        guard let pixelData = newBitmap.bitmapData else { return image }

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Int(pixelData[offset])
                let g = Int(pixelData[offset + 1])
                let b = Int(pixelData[offset + 2])

                // 회색 계열 판별: R ≈ G ≈ B
                let maxDiff = max(abs(r - g), abs(g - b), abs(r - b))
                let brightness = (r + g + b) / 3

                // 체크무늬 배경 (회색: 132,192 등) + 흰 배경 제거
                // R≈G≈B (거의 무채색) 이면서 밝기 120 이상 → 배경으로 판단
                if maxDiff < 5 && brightness > 120 {
                    pixelData[offset + 3] = 0  // 투명
                }
            }
        }

        let newImage = NSImage(size: size)
        newImage.addRepresentation(newBitmap)
        return newImage
    }
}
