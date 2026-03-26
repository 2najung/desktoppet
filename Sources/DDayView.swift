import SwiftUI

struct DDayView: View {
    @ObservedObject var ddayStore: DDayStore
    @State private var newTitle = ""
    @State private var newDate = Date()
    @State private var newEmoji = "📌"
    var onBack: () -> Void

    let emojis = ["📌", "🎯", "🎉", "💼", "✈️", "💕", "🎂", "📝", "⏰", "🔥"]

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                        Text("뒤로")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("D-Day")
                    .font(.system(size: 13, weight: .bold, design: .rounded))

                Spacer()

                Text(ddayStore.items.isEmpty ? "" : "\(ddayStore.items.count)개")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // 추가 영역
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    // 이모지 선택
                    Menu {
                        ForEach(emojis, id: \.self) { e in
                            Button(e) { newEmoji = e }
                        }
                    } label: {
                        Text(newEmoji)
                            .font(.system(size: 18))
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(8)
                    }

                    TextField("D-Day 이름", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onSubmit { addDDay() }
                }

                HStack(spacing: 8) {
                    DatePicker("", selection: $newDate, displayedComponents: .date)
                        .labelsHidden()
                        .font(.system(size: 12))

                    Spacer()

                    Button(action: addDDay) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12))
                            Text("추가")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // 목록
            if ddayStore.items.isEmpty {
                VStack(spacing: 8) {
                    Text("📅")
                        .font(.system(size: 36))
                    Text("D-Day가 없어요!")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(ddayStore.items) { item in
                            DDayRow(item: item, onDelete: { ddayStore.delete(id: item.id) })
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    func addDDay() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        ddayStore.add(title: title, date: newDate, emoji: newEmoji)
        newTitle = ""
    }
}

struct DDayRow: View {
    let item: DDayItem
    let onDelete: () -> Void

    var urgencyColor: Color {
        if item.dDay == 0 { return .red }
        if item.dDay > 0 && item.dDay <= 3 { return .orange }
        if item.dDay > 0 && item.dDay <= 7 { return .yellow }
        if item.dDay < 0 { return .gray }
        return .blue
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(item.emoji)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(item.dDay < 0 ? .secondary : .primary)

                Text(dateString(item.date))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(item.dDayText)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(urgencyColor))

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(item.dDay == 0
                    ? Color.red.opacity(0.08)
                    : (item.dDay > 0 && item.dDay <= 3
                        ? Color.orange.opacity(0.06)
                        : Color.gray.opacity(0.04)))
        )
    }

    func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.M.d (E)"
        return f.string(from: date)
    }
}
