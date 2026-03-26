import Foundation

class FirebaseSync {
    private let baseURL = "https://desktoppet-ba9ae-default-rtdb.firebaseio.com"
    private var pushTimer: Timer?
    private var pullTimer: Timer?

    weak var petManager: PetManager?
    weak var todoStore: TodoStore?
    weak var ddayStore: DDayStore?

    func startSync() {
        // 1초마다 상태 푸시
        pushTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.pushAll()
        }
        // 0.5초마다 웹 명령 체크
        pullTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pullCommands()
        }
        // 초기 푸시
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.pushAll()
        }
    }

    // MARK: - Push (Mac → Firebase)

    func pushAll() {
        pushPetState()
        pushTodos()
        pushDDays()
        pushMemories()
        pushCalendar()
        pullReminders()
    }

    private func pushPetState() {
        guard let pm = petManager else { return }
        let state: [String: Any] = [
            "name": pm.name,
            "level": pm.level,
            "exp": Int(pm.experience),
            "expNext": Int(pm.expForNextLevel),
            "hunger": Int(pm.hunger),
            "happiness": Int(pm.happiness),
            "energy": Int(pm.energy),
            "cleanliness": Int(pm.cleanliness),
            "bond": Int(pm.bond),
            "mood": pm.displayMood.rawValue,
            "emoji": pm.displayMood.emoji,
            "label": pm.displayMood.label,
            "sleeping": pm.isSleeping,
            "weather": pm.weatherService.description,
            "lastUpdate": ISO8601DateFormatter().string(from: Date())
        ]
        putJSON(path: "pet", data: state)
    }

    private func pushTodos() {
        guard let ts = todoStore else { return }
        let items = ts.items.map { item -> [String: Any] in
            ["id": item.id, "title": item.title, "isDone": item.isDone]
        }
        putJSON(path: "todos", data: items)
    }

    private func pushDDays() {
        guard let ds = ddayStore else { return }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let items = ds.items.map { item -> [String: Any] in
            ["id": item.id, "title": item.title, "date": f.string(from: item.date), "emoji": item.emoji]
        }
        putJSON(path: "ddays", data: items)
    }

    private func pushMemories() {
        let memories = ActionExecutor.loadMemories()
        if !memories.isEmpty {
            putJSON(path: "memories", data: memories)
        }
    }

    // MARK: - Pull (Firebase → Mac) - 웹에서 추가한 명령 처리

    private func pullCommands() {
        guard let url = URL(string: "\(baseURL)/commands.json") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let commands = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }
            if commands.isEmpty { return }

            DispatchQueue.main.async {
                for (key, cmd) in commands {
                    self.executeCommand(cmd)
                    self.deleteJSON(path: "commands/\(key)")
                }
                // 명령 처리 후 즉시 상태 푸시
                self.pushAll()
            }
        }.resume()
    }

    private func executeCommand(_ cmd: [String: Any]) {
        guard let type = cmd["type"] as? String else { return }

        switch type {
        case "addTodo":
            if let title = cmd["title"] as? String {
                todoStore?.add(title: title)
            }
        case "toggleTodo":
            if let id = cmd["id"] as? String {
                todoStore?.toggle(id: id)
            }
        case "deleteTodo":
            if let id = cmd["id"] as? String {
                todoStore?.delete(id: id)
            }
        case "addDDay":
            if let title = cmd["title"] as? String,
               let dateStr = cmd["date"] as? String,
               let emoji = cmd["emoji"] as? String {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                if let date = f.date(from: dateStr) {
                    ddayStore?.add(title: title, date: date, emoji: emoji)
                }
            }
        case "deleteDDay":
            if let id = cmd["id"] as? String {
                ddayStore?.delete(id: id)
            }
        case "feed": petManager?.feed()
        case "play": petManager?.play()
        case "pet": petManager?.pet()
        case "bathe": petManager?.bathe()
        case "walk": petManager?.walk()
        case "sleep": petManager?.sleep()
        case "wake": petManager?.wake()
        default: break
        }
    }

    // MARK: - 캘린더 동기화

    private func pushCalendar() {
        guard let pm = petManager else { return }
        let today = pm.calendarService.todayEvents.map { e -> [String: Any] in
            ["title": e.title, "startTime": e.startTime, "endTime": e.endTime, "isAllDay": e.isAllDay]
        }
        let tomorrow = pm.calendarService.tomorrowEvents.map { e -> [String: Any] in
            ["title": e.title, "startTime": e.startTime, "endTime": e.endTime, "isAllDay": e.isAllDay]
        }
        putJSON(path: "calendar", data: ["today": today, "tomorrow": tomorrow])
    }

    // MARK: - 리마인더 동기화

    private func pullReminders() {
        guard let url = URL(string: "\(baseURL)/reminders.json") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data else { return }
            // null 체크
            if let str = String(data: data, encoding: .utf8), str == "null" {
                DispatchQueue.main.async { self.petManager?.reminders = [] }
                return
            }
            guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            var reminders: [[String: String]] = []
            for (_, value) in dict {
                if let r = value as? [String: String] {
                    reminders.append(r)
                }
            }
            DispatchQueue.main.async {
                self.petManager?.reminders = reminders
            }
        }.resume()
    }

    // MARK: - HTTP Helpers

    private func putJSON(path: String, data: Any) {
        guard let url = URL(string: "\(baseURL)/\(path).json"),
              let body = try? JSONSerialization.data(withJSONObject: data) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request).resume()
    }

    private func deleteJSON(path: String) {
        guard let url = URL(string: "\(baseURL)/\(path).json") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request).resume()
    }
}
