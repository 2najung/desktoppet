import SwiftUI

enum InteractionMode {
    case stats, chat, todo, dday, settings
}

struct InteractionView: View {
    @ObservedObject var petManager: PetManager
    @ObservedObject var chatStore: ChatStore
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var pomodoroManager: PomodoroManager
    @ObservedObject var ddayStore: DDayStore
    var onResize: ((CGFloat) -> Void)? = nil
    @State private var mode: InteractionMode = .stats

    var moodGradient: LinearGradient {
        switch petManager.displayMood {
        case .happy:   return LinearGradient(colors: [.yellow.opacity(0.3), .orange.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .normal:  return LinearGradient(colors: [.green.opacity(0.2), .mint.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .hungry:  return LinearGradient(colors: [.orange.opacity(0.25), .red.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .tired:   return LinearGradient(colors: [.blue.opacity(0.2), .indigo.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sad:     return LinearGradient(colors: [.purple.opacity(0.2), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sleeping:return LinearGradient(colors: [.indigo.opacity(0.25), .black.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dirty:   return LinearGradient(colors: [.brown.opacity(0.2), .gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bathing: return LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cook:    return LinearGradient(colors: [.orange.opacity(0.3), .yellow.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .eat:     return LinearGradient(colors: [.orange.opacity(0.25), .pink.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .full:    return LinearGradient(colors: [.pink.opacity(0.2), .orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .angry:   return LinearGradient(colors: [.red.opacity(0.3), .orange.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .work:    return LinearGradient(colors: [.orange.opacity(0.25), .yellow.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .stats:
                statsView
            case .chat:
                ChatView(petManager: petManager, chatStore: chatStore, todoStore: todoStore, onBack: { mode = .stats })
            case .todo:
                TodoView(todoStore: todoStore, petManager: petManager, onBack: { mode = .stats })
            case .dday:
                DDayView(ddayStore: ddayStore, onBack: { mode = .stats })
            case .settings:
                SettingsView(petManager: petManager, onBack: { mode = .stats })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(NSColor.windowBackgroundColor)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: mode) { newMode in
            onResize?(newMode == .stats ? 440 : 460)
        }
    }

    var statsView: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: 6) {
                HStack(alignment: .center) {
                    Text(petManager.displayMood.emoji)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(petManager.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text(petManager.displayMood.label)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Lv.\(petManager.level)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)))

                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.2)).frame(width: 50, height: 4)
                            Capsule().fill(Color.purple.opacity(0.8))
                                .frame(width: 50 * CGFloat(petManager.experience / petManager.expForNextLevel), height: 4)
                        }
                    }

                    Button(action: {
                        withAnimation { petManager.isSecretaryMode.toggle() }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10))
                            Text(petManager.isSecretaryMode ? "ON" : "OFF")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(petManager.isSecretaryMode ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(petManager.isSecretaryMode ? Color.blue : Color.gray.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: { mode = .settings }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(moodGradient)

            Divider()

            StatsView(petManager: petManager)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            // 액션 버튼
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ActionButton(icon: "🍚", label: "밥주기", color: .orange, action: petManager.feed)
                    ActionButton(icon: "🎾", label: "놀기", color: .green, action: petManager.play)
                    ActionButton(icon: "✋", label: "쓰다듬기", color: .pink, action: petManager.pet)
                }
                HStack(spacing: 6) {
                    ActionButton(icon: "🛁", label: "목욕", color: .cyan, action: petManager.bathe)
                    ActionButton(icon: "🏃", label: "산책", color: .mint, action: petManager.walk)
                    if petManager.isSleeping {
                        ActionButton(icon: "⏰", label: "깨우기", color: .yellow, action: petManager.wake)
                    } else {
                        ActionButton(icon: "💤", label: "재우기", color: .indigo, action: petManager.sleep)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // 포모도로 카드
            PomodoroCard(manager: pomodoroManager)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            // 하단 버튼
            HStack(spacing: 6) {
                Button(action: { mode = .chat }) {
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left.fill").font(.system(size: 10))
                        Text("대화").font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button(action: { mode = .todo }) {
                    HStack(spacing: 3) {
                        Image(systemName: "checklist").font(.system(size: 10))
                        Text("할 일").font(.system(size: 11, weight: .semibold))
                        if todoStore.pendingCount > 0 {
                            Text("\(todoStore.pendingCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.white.opacity(0.3)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(action: { mode = .dday }) {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar.badge.clock").font(.system(size: 10))
                        Text("D-Day").font(.system(size: 11, weight: .semibold))
                        if let n = ddayStore.nearest, n.dDay >= 0 && n.dDay <= 3 {
                            Text("D-\(n.dDay)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.white.opacity(0.3)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - PomodoroCard

struct PomodoroCard: View {
    @ObservedObject var manager: PomodoroManager
    @State private var showSettings = false

    var phaseColor: Color {
        switch manager.phase {
        case .idle: return .primary
        case .focusing: return .orange
        case .breaking: return .mint
        case .paused: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("집중 모드", systemImage: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if manager.sessionsCompleted > 0 {
                    Text("오늘 \(manager.sessionsCompleted)회 완료")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Button(action: { withAnimation { showSettings.toggle() } }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                        .foregroundColor(showSettings ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(manager.timeString)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundColor(phaseColor)

                Spacer()

                // 상태 뱃지
                if manager.phase != .idle {
                    let badgeText: String = {
                        switch manager.phase {
                        case .focusing: return "🔥 집중 중"
                        case .breaking: return "😌 휴식 중"
                        case .paused: return "⏸ 일시정지"
                        default: return ""
                        }
                    }()
                    Text(badgeText)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(phaseColor.opacity(0.15)))
                }

                // 버튼
                HStack(spacing: 6) {
                    if manager.phase == .idle {
                        Button(action: { manager.start() }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    } else if manager.phase == .paused {
                        Button(action: { manager.resume() }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button(action: { manager.reset() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: { manager.pause() }) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.bordered)

                        Button(action: { manager.reset() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            // 진행 바
            if manager.phase != .idle {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.15))
                        Capsule()
                            .fill(phaseColor.opacity(0.7))
                            .frame(width: geo.size.width * manager.progress)
                            .animation(.linear(duration: 1), value: manager.progress)
                    }
                }
                .frame(height: 5)
            }

            // 시간 설정
            if showSettings {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Text("집중")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Stepper("", value: $manager.focusMinutes, in: 1...120)
                            .labelsHidden()
                            .disabled(manager.phase != .idle)
                        Text("\(manager.focusMinutes)분")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 32)
                    }
                    HStack(spacing: 6) {
                        Text("휴식")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Stepper("", value: $manager.breakMinutes, in: 1...60)
                            .labelsHidden()
                            .disabled(manager.phase != .idle)
                        Text("\(manager.breakMinutes)분")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 32)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - ActionButton

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isPressed = false }
        }) {
            VStack(spacing: 3) {
                Text(icon)
                    .font(.system(size: 20))
                    .scaleEffect(isPressed ? 1.3 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPressed)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(isPressed ? 0.2 : 0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
