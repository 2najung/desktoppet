import SwiftUI

class PetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var floatingWindow: PetWindow!
    var interactionPanel: PetWindow!
    var quickCommandWindow: PetWindow!
    let petManager = PetManager()
    let chatStore = ChatStore()
    let todoStore = TodoStore()
    let pomodoroManager = PomodoroManager()
    let ddayStore = DDayStore()
    var statusItem: NSStatusItem?
    let webServer = PetWebServer()
    let firebaseSync = FirebaseSync()
    private var walkTimer: Timer?
    private var walkCountdown: Double = 5
    private var walkPauseUntil: Date = .distantPast
    private var isAutoMoving = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupFloatingWindow()
        setupInteractionPanel()
        setupQuickCommandWindow()
        setupMenuBar()
        setupGlobalHotkeys()
        setupPomodoroCallbacks()
        pomodoroManager.requestNotificationPermission()
        startWebServer()
        startWalking()
        startFirebaseSync()
    }

    func startFirebaseSync() {
        firebaseSync.petManager = petManager
        firebaseSync.todoStore = todoStore
        firebaseSync.ddayStore = ddayStore
        firebaseSync.startSync()
    }

    func startWebServer() {
        webServer.petManager = petManager
        webServer.todoStore = todoStore
        webServer.pomodoroManager = pomodoroManager
        webServer.chatStore = chatStore
        webServer.ddayStore = ddayStore
        webServer.start()
    }

    func setupFloatingWindow() {
        let contentView = PetView(petManager: petManager, chatStore: chatStore, ddayStore: ddayStore, onTap: { [weak self] in
            self?.toggleInteractionPanel()
        })

        floatingWindow = PetWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        floatingWindow.isOpaque = false
        floatingWindow.backgroundColor = .clear
        floatingWindow.level = .floating
        floatingWindow.hasShadow = false
        floatingWindow.isMovableByWindowBackground = true
        floatingWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        floatingWindow.contentView = NSHostingView(rootView: contentView)
        floatingWindow.delegate = self

        // 저장된 위치 복원, 없으면 우측 상단
        if let saved = UserDefaults.standard.array(forKey: "petWindowOrigin") as? [CGFloat], saved.count == 2 {
            floatingWindow.setFrameOrigin(NSPoint(x: saved[0], y: saved[1]))
        } else if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            floatingWindow.setFrameOrigin(NSPoint(x: screenRect.maxX - 300, y: screenRect.maxY - 500))
        }

        floatingWindow.makeKeyAndOrderFront(nil)
    }

    func setupPomodoroCallbacks() {
        pomodoroManager.onFocusStart = { [weak self] in
            self?.petManager.actionMood = .work
        }
        pomodoroManager.onFocusStop = { [weak self] in
            if self?.petManager.actionMood == .work {
                self?.petManager.actionMood = nil
            }
        }
        pomodoroManager.onFocusComplete = { [weak self] in
            self?.petManager.completedPomodoro()
        }
        pomodoroManager.onBreakComplete = { [weak self] in
            self?.petManager.showAction("😌 휴식 끝!")
        }
    }

    func setupInteractionPanel() {
        let contentView = InteractionView(
            petManager: petManager,
            chatStore: chatStore,
            todoStore: todoStore,
            pomodoroManager: pomodoroManager,
            ddayStore: ddayStore,
            onResize: { [weak self] height in self?.resizeInteractionPanel(to: height) }
        )

        interactionPanel = PetWindow(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 440),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        interactionPanel.isOpaque = false
        interactionPanel.backgroundColor = .clear
        interactionPanel.level = .floating
        interactionPanel.hasShadow = true
        interactionPanel.isMovableByWindowBackground = true
        interactionPanel.collectionBehavior = [.canJoinAllSpaces]
        interactionPanel.contentView = NSHostingView(rootView: contentView)
        // 처음엔 숨김
    }

    func toggleInteractionPanel() {
        if interactionPanel.isVisible {
            interactionPanel.orderOut(nil)
        } else {
            // 펫 창 기준으로 위치 설정 (펫 캐릭터 아래)
            let petFrame = floatingWindow.frame
            let panelWidth: CGFloat = 330
            let panelHeight = interactionPanel.frame.height
            let x = petFrame.maxX - panelWidth
            let y = petFrame.maxY - 130 - panelHeight
            interactionPanel.setFrameOrigin(NSPoint(x: x, y: y))
            interactionPanel.makeKeyAndOrderFront(nil)
        }
    }

    func resizeInteractionPanel(to height: CGFloat) {
        var frame = interactionPanel.frame
        let delta = frame.size.height - height
        frame.origin.y += delta  // 상단 위치 고정
        frame.size.height = height
        interactionPanel.setFrame(frame, display: true, animate: true)
    }

    // MARK: - 빠른 명령 (Quick Command)

    func setupQuickCommandWindow() {
        let contentView = QuickCommandView(
            chatStore: chatStore,
            petManager: petManager,
            todoStore: todoStore,
            onDismiss: { [weak self] in
                self?.quickCommandWindow.orderOut(nil)
            },
            onResize: { [weak self] height in
                guard let self, let window = self.quickCommandWindow else { return }
                var frame = window.frame
                let delta = frame.size.height - height
                frame.origin.y += delta
                frame.size.height = height
                window.setFrame(frame, display: true, animate: true)
            }
        )

        quickCommandWindow = PetWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 52),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        quickCommandWindow.isOpaque = false
        quickCommandWindow.backgroundColor = .clear
        quickCommandWindow.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        quickCommandWindow.hasShadow = false
        quickCommandWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        quickCommandWindow.contentView = NSHostingView(rootView: contentView)

        // 포커스 잃어도 바로 닫지 않음 (Escape로만 닫기)
    }

    func toggleQuickCommand() {
        if quickCommandWindow.isVisible {
            quickCommandWindow.orderOut(nil)
        } else {
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - 250
                let y = screenFrame.midY + 100
                quickCommandWindow.setFrameOrigin(NSPoint(x: x, y: y))
            }
            quickCommandWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .showQuickCommand, object: nil)
        }
    }

    // MARK: - 글로벌 단축키

    func setupGlobalHotkeys() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkey(event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleHotkey(event) == true { return nil }
            return event
        }
    }

    @discardableResult
    func handleHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+Shift+Space → 빠른 명령
        if flags == [.command, .shift] && event.keyCode == 49 {
            DispatchQueue.main.async { self.toggleQuickCommand() }
            return true
        }

        // Cmd+Shift+P → 펫 토글
        if flags == [.command, .shift] && event.keyCode == 35 {
            DispatchQueue.main.async { self.togglePet() }
            return true
        }

        // Escape → 빠른 명령 닫기
        if event.keyCode == 53 && quickCommandWindow.isVisible {
            DispatchQueue.main.async { self.quickCommandWindow.orderOut(nil) }
            return true
        }

        return false
    }

    @objc func toggleQuickCommandAction() {
        toggleQuickCommand()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "🐱"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "펫 보이기/숨기기 (⌘⇧P)", action: #selector(togglePet), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "빠른 명령 (⌘⇧Space)", action: #selector(toggleQuickCommandAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func togglePet() {
        if floatingWindow.isVisible {
            floatingWindow.orderOut(nil)
            interactionPanel.orderOut(nil)
        } else {
            floatingWindow.makeKeyAndOrderFront(nil)
        }
    }

    @objc func quitApp() {
        petManager.save()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        petManager.save()
    }

    // MARK: - 펫 걷기

    func startWalking() {
        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.walkTick() }
        }
    }

    func walkTick() {
        let pm = petManager

        // 잠자는 중이거나, 패널 열려있거나, 일시정지 중이면 멈춤
        guard !pm.isSleeping,
              !interactionPanel.isVisible,
              !quickCommandWindow.isVisible,
              Date() > walkPauseUntil else {
            if pm.walkState != "idle" { pm.walkState = "idle" }
            return
        }

        walkCountdown -= 0.05

        // 상태 전환
        if walkCountdown <= 0 {
            switch pm.walkState {
            case "idle":
                let rand = Double.random(in: 0...1)
                if rand < 0.65 {
                    pm.walkState = "walking"
                    if Double.random(in: 0...1) < 0.35 {
                        pm.walkDirection *= -1
                    }
                    walkCountdown = Double.random(in: 3...8)
                } else {
                    pm.walkState = "sitting"
                    walkCountdown = Double.random(in: 4...7)
                }
            case "walking":
                // 가끔 방향 전환
                if Double.random(in: 0...1) < 0.2 {
                    pm.walkDirection *= -1
                    walkCountdown = Double.random(in: 2...5)
                } else {
                    pm.walkState = "idle"
                    walkCountdown = Double.random(in: 3...10)
                }
            default:
                pm.walkState = "idle"
                walkCountdown = Double.random(in: 3...8)
            }
        }

        // 걷기 이동
        if pm.walkState == "walking" {
            guard let screen = NSScreen.main else { return }
            var origin = floatingWindow.frame.origin
            let speed: CGFloat = pm.mood == .tired ? 0.5 : (pm.mood == .happy ? 1.8 : 1.2)
            origin.x += speed * pm.walkDirection

            let screenFrame = screen.visibleFrame
            let windowWidth = floatingWindow.frame.width

            if origin.x < screenFrame.minX {
                origin.x = screenFrame.minX
                pm.walkDirection = 1
            } else if origin.x + windowWidth > screenFrame.maxX {
                origin.x = screenFrame.maxX - windowWidth
                pm.walkDirection = -1
            }

            isAutoMoving = true
            floatingWindow.setFrameOrigin(origin)
            isAutoMoving = false
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === floatingWindow else { return }
        let origin = window.frame.origin
        UserDefaults.standard.set([origin.x, origin.y], forKey: "petWindowOrigin")
        // 유저가 직접 드래그한 경우만 멈춤
        if !isAutoMoving {
            walkPauseUntil = Date().addingTimeInterval(8)
            petManager.walkState = "idle"
        }
    }
}
