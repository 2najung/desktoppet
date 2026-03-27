# DesktopPet

macOS 데스크톱 위에 살아있는 AI 감자 비서 펫

<p align="center">
  <img src="Images/default.jpeg" width="120" />
  <img src="Images/happy.jpeg" width="120" />
  <img src="Images/angry.jpeg" width="120" />
  <img src="Images/sleeping.jpeg" width="120" />
  <img src="Images/cook.jpeg" width="120" />
</p>

## 주요 기능

### 펫 시스템
- 13가지 기분 상태 (행복, 배고픔, 졸림, 슬픔, 화남, 잠, 목욕, 요리, 식사, 배부름, 더러움, 집중, 기본)
- 배고픔 / 기분 / 에너지 / 청결 / 친밀도 스탯
- 레벨 & 경험치 시스템 (레벨업 시 빵빠레 이펙트)
- 펫이 화면 위를 걸어다님 (기분에 따라 속도 변화)
- 커스텀 이미지 지원 + 내장 감자 캐릭터

### AI 비서
- **비서 모드** — Groq API (llama-3.3-70b) 기반 AI 채팅
- **펫 모드** — Ollama (로컬 AI) 기반 귀여운 펫 대화
- **시스템 제어** — 자연어로 맥 제어:
  - `"유튜브 열어"` → 브라우저에서 열기
  - `"사파리 실행"` → 앱 실행
  - `"다운로드 폴더 열어"` → Finder 열기
  - `"노래 틀어"` → AppleScript 실행
  - `"디스크 용량 확인"` → 터미널 명령
  - `"보고서 찾아"` → Spotlight 파일 검색
  - `"최신 뉴스 검색"` → 웹 검색
- **리마인더** — `"5분 뒤에 알려줘"`, `"3시에 회의"` → 시간 맞춰 알림
- **기억력** — `"내 생일 3월 15일 기억해"` → 저장 & 나중에 기억
- **캘린더 연동** — macOS 캘린더 읽기 + 일정 추가
- **클립보드 감시** — 텍스트 복사 시 번역/요약 제안

### 글로벌 단축키
| 단축키 | 동작 |
|--------|------|
| `Cmd+Shift+Space` | 빠른 명령 (Spotlight 스타일) |
| `Cmd+Shift+P` | 펫 보이기/숨기기 |
| `Esc` | 빠른 명령 닫기 |

### 생산성
- **포모도로 타이머** — 집중/휴식 사이클, 세션 카운트
- **할 일 관리** — 추가/완료/삭제, 비서가 자연어로 관리
- **D-Day 카운트** — 펫 머리 위에 D-Day 배지 표시
- **시간대 반응** — 출근(9시)/점심(12시)/퇴근(6시) 맞춤 알림
- **배터리 경고** — 20% 이하 시 알림

### 날씨 이펙트
실시간 날씨 연동 (Open-Meteo API, 무료)
| 날씨 | 이펙트 |
|------|--------|
| 맑음 | 노란 태양 + 금색 반짝이 |
| 흐림 | 회청색 구름 blur |
| 비 | 비구름 + 파란 빗줄기 |
| 눈 | 눈구름 + 하늘색 눈꽃 |
| 천둥 | 비 + 노란 번개 + 플래시 |
| 안개 | blur 안개 레이어 |
| 바람 | 바람 줄 + 나뭇잎 날림 |

### 드래그 앤 드롭
파일을 펫 위에 끌어다 놓으면:
- **텍스트/코드 파일** → AI가 자동 요약
- **PDF** → 텍스트 추출 후 요약
- **이미지/영상/음악** → 기본 앱으로 열기
- **URL** → 브라우저에서 열기

### 모바일 웹앱 (GitHub Pages)
- **https://2najung.github.io/desktoppet/**
- Firebase 실시간 동기화 (할 일, D-Day, 캘린더, 리마인더)
- 라이트/다크 모드
- 펫 스탯 & 액션 (밥주기, 놀기 등)
- AI 채팅 (Groq API)
- PWA 지원 — 홈 화면에 추가하면 앱처럼 사용

### 웹 서버 (같은 WiFi)
- `http://[맥IP]:8420` 에서 접속
- 모바일 최적화 UI
- 실시간 펫 상태 동기화

## 기술 스택

| 구분 | 기술 |
|------|------|
| 앱 | Swift 5.9, SwiftUI, Swift Package Manager |
| AI | Groq API (llama-3.3-70b), Ollama (gemma2) |
| 날씨 | Open-Meteo API (무료) |
| 동기화 | Firebase Realtime Database |
| 웹앱 | GitHub Pages, Firebase JS SDK |
| 캘린더 | EventKit |
| 서버 | NWListener (Network.framework) |

## 설치 및 실행

### 요구사항
- macOS 13 이상
- Swift 5.9+
- Groq API 키 (무료: [console.groq.com](https://console.groq.com))

### 빌드
```bash
cd DesktopPet
swift build
```

### 실행
```bash
.build/debug/DesktopPet
```

### .app 번들로 실행
```bash
# Desktop에 .app 생성 (최초 1회)
mkdir -p ~/Desktop/DesktopPet.app/Contents/MacOS
ln -sf $(pwd)/.build/arm64-apple-macosx/debug/DesktopPet ~/Desktop/DesktopPet.app/Contents/MacOS/DesktopPet
cat > ~/Desktop/DesktopPet.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>DesktopPet</string>
    <key>CFBundleIdentifier</key><string>com.desktoppet.app</string>
    <key>CFBundleName</key><string>DesktopPet</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# 실행
open ~/Desktop/DesktopPet.app
```

### 설정
1. 앱 실행 후 펫 클릭 → 설정(⚙️) → Groq API 키 입력
2. 접근성 권한: 시스템 설정 → 개인정보 → 접근성 → DesktopPet 허용
3. 캘린더 권한: 첫 실행 시 팝업에서 허용

## 프로젝트 구조

```
DesktopPet/
├── Package.swift
├── Sources/
│   ├── DesktopPetApp.swift      # 앱 엔트리
│   ├── AppDelegate.swift         # 윈도우, 단축키, 걷기
│   ├── PetManager.swift          # 펫 상태, 시간반응, 클립보드
│   ├── PetState.swift            # 기분 enum
│   ├── PetView.swift             # 펫 UI, 드래그앤드롭
│   ├── InteractionView.swift     # 메인 패널 UI
│   ├── ChatView.swift            # AI 채팅, 액션 태그 처리
│   ├── ChatStore.swift           # 대화 저장소
│   ├── TodoStore.swift           # 할 일 저장소
│   ├── TodoView.swift            # 할 일 UI
│   ├── DDayStore.swift           # D-Day 저장소
│   ├── DDayView.swift            # D-Day UI
│   ├── StatsView.swift           # 스탯 바
│   ├── SettingsView.swift        # 설정 UI
│   ├── PomodoroManager.swift     # 포모도로 타이머
│   ├── WeatherService.swift      # 날씨 API
│   ├── WeatherEffectView.swift   # 날씨 이펙트 (SF Symbols)
│   ├── CalendarService.swift     # macOS 캘린더 연동
│   ├── ActionExecutor.swift      # 시스템 액션 실행
│   ├── GroqService.swift         # Groq API 클라이언트
│   ├── OllamaService.swift       # Ollama 클라이언트
│   ├── WebServer.swift           # 웹 서버 (NWListener)
│   ├── QuickCommandView.swift    # 빠른 명령 UI
│   ├── FirebaseSync.swift        # Firebase 실시간 동기화
│   └── PotatoPetView.swift       # 내장 감자 캐릭터 (SwiftUI)
├── Images/                       # 기분별 커스텀 이미지
├── docs/
│   ├── index.html                # GitHub Pages 웹앱
│   └── img/                      # 웹용 투명 PNG 이미지
└── README.md
```

## 무료 API

| 서비스 | 용도 | 비용 |
|--------|------|------|
| Groq | AI 채팅 | 무료 |
| Open-Meteo | 날씨 | 무료 |
| Firebase | 동기화 | 무료 (1GB) |
| GitHub Pages | 웹앱 호스팅 | 무료 |

## 라이선스

MIT
