import EventKit
import Foundation

struct CalEvent: Codable {
    let title: String
    let startTime: String  // HH:mm
    let endTime: String
    let isAllDay: Bool

    var displayText: String {
        if isAllDay { return "  \(title) (종일)" }
        return "  \(startTime) \(title)"
    }
}

class CalendarService: ObservableObject {
    @Published var todayEvents: [CalEvent] = []
    @Published var tomorrowEvents: [CalEvent] = []
    @Published var hasAccess = false

    private let store = EKEventStore()
    private var timer: Timer?

    init() {
        requestAccess()
        // 5분마다 갱신
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted { self?.fetchEvents() }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted { self?.fetchEvents() }
                }
            }
        }
    }

    func fetchEvents() {
        guard hasAccess else { return }
        let cal = Calendar.current
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"

        // 오늘
        let todayStart = cal.startOfDay(for: Date())
        let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart)!
        let todayPred = store.predicateForEvents(withStart: todayStart, end: todayEnd, calendars: nil)
        let todayEK = store.events(matching: todayPred).sorted { $0.startDate < $1.startDate }

        // 내일
        let tomorrowEnd = cal.date(byAdding: .day, value: 1, to: todayEnd)!
        let tomorrowPred = store.predicateForEvents(withStart: todayEnd, end: tomorrowEnd, calendars: nil)
        let tomorrowEK = store.events(matching: tomorrowPred).sorted { $0.startDate < $1.startDate }

        DispatchQueue.main.async {
            self.todayEvents = todayEK.map { ev in
                CalEvent(
                    title: ev.title ?? "일정",
                    startTime: tf.string(from: ev.startDate),
                    endTime: tf.string(from: ev.endDate),
                    isAllDay: ev.isAllDay
                )
            }
            self.tomorrowEvents = tomorrowEK.map { ev in
                CalEvent(
                    title: ev.title ?? "일정",
                    startTime: tf.string(from: ev.startDate),
                    endTime: tf.string(from: ev.endDate),
                    isAllDay: ev.isAllDay
                )
            }
        }
    }

    // 일정 추가
    func addEvent(title: String, startDate: Date, endDate: Date?) {
        guard hasAccess else { return }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600)
        event.calendar = store.defaultCalendarForNewEvents
        try? store.save(event, span: .thisEvent)
        fetchEvents()
    }

    // 오늘 요약 텍스트
    var todaySummary: String {
        if todayEvents.isEmpty { return "오늘 일정 없음" }
        return "오늘 일정 \(todayEvents.count)개:\n" + todayEvents.map { $0.displayText }.joined(separator: "\n")
    }
}
