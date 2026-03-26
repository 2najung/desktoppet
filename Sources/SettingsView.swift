import SwiftUI

struct SettingsView: View {
    @ObservedObject var petManager: PetManager
    @State private var groqKey: String = UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
    var onBack: () -> Void

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

                Text("설정")
                    .font(.system(size: 13, weight: .bold, design: .rounded))

                Spacer()

                Color.clear.frame(width: 40, height: 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.05))

            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    // 이름 설정
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("펫 이름", systemImage: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("이름을 입력하세요", text: $petManager.name)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                                .onSubmit { petManager.save() }
                        }
                    }

                    // 비서 모드 (Gemini API)
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("비서 모드 (Groq API)", systemImage: "brain.head.profile")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Text("대화창에서 토글로 비서 모드 전환 가능\nAPI 키 발급: console.groq.com")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            SecureField("Groq API 키 입력", text: $groqKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .onSubmit {
                                    UserDefaults.standard.set(groqKey, forKey: "groqAPIKey")
                                }

                            Button(action: {
                                UserDefaults.standard.set(groqKey, forKey: "groqAPIKey")
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text("키 저장")
                                }
                                .font(.system(size: 11))
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                    }

                    // 캐릭터 설정
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("캐릭터", systemImage: "theatermask.and.paintbrush")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Toggle(isOn: $petManager.useBuiltInCharacter) {
                                HStack(spacing: 6) {
                                    Text("🥔")
                                    Text("내장 감자 캐릭터 사용")
                                        .font(.system(size: 12))
                                }
                            }
                            .toggleStyle(.switch)
                            .onChange(of: petManager.useBuiltInCharacter) { val in
                                UserDefaults.standard.set(val, forKey: "useBuiltInCharacter")
                            }

                            if !petManager.useBuiltInCharacter {
                                Divider()

                                Text("Images 폴더에 기분별 이미지를 넣으세요\ndefault / happy / normal / hungry\ntired / sad / sleeping / dirty")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)

                                Button(action: {
                                    let path = PetManager.imagesDirectory
                                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                                }) {
                                    HStack {
                                        Image(systemName: "folder")
                                        Text("Images 폴더 열기")
                                    }
                                    .font(.system(size: 11))
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    // 스탯 초기화
                    SettingsCard {
                        Button(action: {
                            petManager.hunger = 80
                            petManager.happiness = 80
                            petManager.energy = 80
                            petManager.cleanliness = 80
                            petManager.isSleeping = false
                            petManager.save()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("스탯 초기화")
                            }
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    // 종료
                    SettingsCard {
                        Button(action: {
                            petManager.save()
                            NSApp.terminate(nil)
                        }) {
                            HStack {
                                Image(systemName: "power")
                                Text("앱 종료")
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}
