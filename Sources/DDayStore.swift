import Foundation

struct DDayItem: Codable, Identifiable {
    let id: String
    var title: String
    var date: Date
    var emoji: String

    init(title: String, date: Date, emoji: String = "📌") {
        self.id = UUID().uuidString
        self.title = title
        self.date = date
        self.emoji = emoji
    }

    var dDay: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var dDayText: String {
        let d = dDay
        if d > 0 { return "D-\(d)" }
        if d == 0 { return "D-DAY!" }
        return "D+\(abs(d))"
    }

    var displayText: String {
        "\(emoji) \(title) \(dDayText)"
    }
}

class DDayStore: ObservableObject {
    @Published var items: [DDayItem] = []

    init() { load() }

    func add(title: String, date: Date, emoji: String = "📌") {
        items.append(DDayItem(title: title, date: date, emoji: emoji))
        items.sort { $0.date < $1.date }
        save()
    }

    func delete(id: String) {
        items.removeAll { $0.id == id }
        save()
    }

    // 가장 가까운 D-Day (미래 기준)
    var nearest: DDayItem? {
        items.filter { $0.dDay >= 0 }.sorted { $0.dDay < $1.dDay }.first
            ?? items.sorted { abs($0.dDay) < abs($1.dDay) }.first
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "ddayItems")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "ddayItems"),
           let saved = try? JSONDecoder().decode([DDayItem].self, from: data) {
            items = saved
        }
    }
}
