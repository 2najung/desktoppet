import Foundation
import AppKit

enum PomodoroPhase {
    case idle, focusing, breaking, paused
}

class PomodoroManager: ObservableObject {
    @Published var phase: PomodoroPhase = .idle
    @Published var timeRemaining: Int = 25 * 60
    @Published var sessionsCompleted: Int = 0

    @Published var focusMinutes: Int {
        didSet {
            UserDefaults.standard.set(focusMinutes, forKey: "pomodoroFocusMinutes")
            if phase == .idle { timeRemaining = focusMinutes * 60 }
        }
    }
    @Published var breakMinutes: Int {
        didSet {
            UserDefaults.standard.set(breakMinutes, forKey: "pomodoroBreakMinutes")
        }
    }

    var onFocusComplete: (() -> Void)?
    var onBreakComplete: (() -> Void)?
    var onFocusStart: (() -> Void)?
    var onFocusStop: (() -> Void)?

    // pause 전 phase를 기억 (resume용)
    private var phaseBeforePause: PomodoroPhase = .idle
    private var timer: Timer?

    init() {
        let savedFocus = UserDefaults.standard.integer(forKey: "pomodoroFocusMinutes")
        let savedBreak = UserDefaults.standard.integer(forKey: "pomodoroBreakMinutes")
        focusMinutes = savedFocus > 0 ? savedFocus : 25
        breakMinutes = savedBreak > 0 ? savedBreak : 5
        timeRemaining = (savedFocus > 0 ? savedFocus : 25) * 60
        loadSessions()
    }

    var timeString: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    var progress: Double {
        let activePhase = phase == .paused ? phaseBeforePause : phase
        let total = activePhase == .focusing ? focusMinutes * 60 : breakMinutes * 60
        guard total > 0 else { return 0 }
        return 1.0 - Double(timeRemaining) / Double(total)
    }

    func start() {
        phase = .focusing
        timeRemaining = focusMinutes * 60
        onFocusStart?()
        startTick()
    }

    func pause() {
        guard phase == .focusing || phase == .breaking else { return }
        phaseBeforePause = phase
        timer?.invalidate()
        timer = nil
        phase = .paused
        onFocusStop?()
    }

    func resume() {
        guard phase == .paused else { return }
        phase = phaseBeforePause
        if phase == .focusing { onFocusStart?() }
        startTick()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        phase = .idle
        timeRemaining = focusMinutes * 60
        onFocusStop?()
    }

    private func startTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.tick() }
        }
    }

    private func tick() {
        guard timeRemaining > 0 else {
            if phase == .focusing {
                sessionsCompleted += 1
                saveSessions()
                sendNotification(title: "집중 완료! 🎉", body: "수고했어! 잠깐 쉬어가자~")
                onFocusComplete?()
                phase = .breaking
                timeRemaining = breakMinutes * 60
                startTick()
            } else {
                sendNotification(title: "휴식 끝! ⏰", body: "다시 집중 시작할까?")
                onBreakComplete?()
                reset()
            }
            return
        }
        timeRemaining -= 1
    }

    // MARK: - 세션 카운트 저장 (날짜별)

    private func saveSessions() {
        let today = dateString(from: Date())
        UserDefaults.standard.set(sessionsCompleted, forKey: "pomodoroSessions")
        UserDefaults.standard.set(today, forKey: "pomodoroSessionsDate")
    }

    private func loadSessions() {
        let today = dateString(from: Date())
        let savedDate = UserDefaults.standard.string(forKey: "pomodoroSessionsDate") ?? ""
        if savedDate == today {
            sessionsCompleted = UserDefaults.standard.integer(forKey: "pomodoroSessions")
        } else {
            sessionsCompleted = 0
        }
    }

    private func dateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - 알림 (시스템 사운드로 대체)

    func requestNotificationPermission() {
        // swift build 앱은 UNUserNotificationCenter 사용 불가, no-op
    }

    private func sendNotification(title: String, body: String) {
        NSSound.beep()
    }
}
