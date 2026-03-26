import SwiftUI

struct PotatoPetView: View {
    let mood: PetMood
    let size: CGFloat

    // 색상 팔레트
    let bodyLight = Color(red: 0.88, green: 0.78, blue: 0.58)
    let bodyDark  = Color(red: 0.76, green: 0.63, blue: 0.42)
    let outline   = Color(red: 0.36, green: 0.24, blue: 0.18)
    let eyeColor  = Color(red: 0.25, green: 0.17, blue: 0.12)
    let blush     = Color(red: 0.92, green: 0.55, blue: 0.5)
    let leafGreen = Color(red: 0.42, green: 0.6, blue: 0.28)
    let leafLight = Color(red: 0.5, green: 0.7, blue: 0.35)

    var body: some View {
        ZStack {
            // 그림자
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: size * 0.55, height: size * 0.08)
                .offset(y: size * 0.46)

            // 다리
            legsView

            // 몸통
            bodyView

            // 팔
            armsView

            // 점(주근깨)
            spotsView

            // 볼터치
            cheeksView

            // 새싹
            sproutView
                .offset(y: -size * 0.38)

            // 눈썹
            eyebrowsView

            // 눈
            eyesView

            // 입
            mouthView

            // 악세서리
            accessoryView
        }
        .frame(width: size, height: size)
    }

    // MARK: - 몸통

    var bodyView: some View {
        ZStack {
            // 아웃라인
            PotatoShape()
                .fill(outline)
                .frame(width: size * 0.64, height: size * 0.72)
                .offset(y: size * 0.01)

            // 메인 바디
            PotatoShape()
                .fill(
                    LinearGradient(
                        colors: [bodyLight, bodyDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.6, height: size * 0.68)

            // 하이라이트
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.15
                    )
                )
                .frame(width: size * 0.25, height: size * 0.2)
                .offset(x: -size * 0.08, y: -size * 0.12)
        }
    }

    // MARK: - 새싹

    var sproutView: some View {
        ZStack {
            // 줄기
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.38, green: 0.52, blue: 0.25))
                .frame(width: size * 0.025, height: size * 0.1)
                .offset(y: size * 0.02)

            // 왼쪽 잎
            LeafShape()
                .fill(leafGreen)
                .frame(width: size * 0.12, height: size * 0.08)
                .rotationEffect(.degrees(-40))
                .offset(x: -size * 0.06, y: -size * 0.01)

            // 오른쪽 잎
            LeafShape()
                .fill(leafLight)
                .frame(width: size * 0.13, height: size * 0.085)
                .rotationEffect(.degrees(35))
                .scaleEffect(x: -1, y: 1)
                .offset(x: size * 0.06, y: -size * 0.015)

            // 가운데 잎
            LeafShape()
                .fill(Color(red: 0.45, green: 0.62, blue: 0.3))
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(y: -size * 0.05)
        }
    }

    // MARK: - 점(주근깨)

    var spotsView: some View {
        ZStack {
            Circle().fill(bodyDark.opacity(0.35))
                .frame(width: size * 0.025, height: size * 0.025)
                .offset(x: size * 0.15, y: -size * 0.05)
            Circle().fill(bodyDark.opacity(0.3))
                .frame(width: size * 0.02, height: size * 0.02)
                .offset(x: -size * 0.18, y: size * 0.02)
            Circle().fill(bodyDark.opacity(0.25))
                .frame(width: size * 0.018, height: size * 0.018)
                .offset(x: size * 0.08, y: size * 0.15)
            Circle().fill(bodyDark.opacity(0.3))
                .frame(width: size * 0.022, height: size * 0.022)
                .offset(x: -size * 0.12, y: size * 0.18)
            Circle().fill(bodyDark.opacity(0.2))
                .frame(width: size * 0.02, height: size * 0.02)
                .offset(x: size * 0.18, y: size * 0.12)
        }
    }

    // MARK: - 볼터치

    var cheeksView: some View {
        HStack(spacing: size * 0.22) {
            Ellipse()
                .fill(blush.opacity(mood == .angry ? 0.6 : 0.45))
                .frame(width: size * 0.1, height: size * 0.065)
                .blur(radius: 1.5)
            Ellipse()
                .fill(blush.opacity(mood == .angry ? 0.6 : 0.45))
                .frame(width: size * 0.1, height: size * 0.065)
                .blur(radius: 1.5)
        }
        .offset(y: size * 0.06)
    }

    // MARK: - 다리

    var legsView: some View {
        HStack(spacing: size * 0.12) {
            // 왼발
            ZStack {
                Ellipse().fill(outline)
                    .frame(width: size * 0.115, height: size * 0.13)
                Ellipse().fill(bodyDark)
                    .frame(width: size * 0.095, height: size * 0.11)
            }
            .offset(y: size * 0.37)
            // 오른발
            ZStack {
                Ellipse().fill(outline)
                    .frame(width: size * 0.115, height: size * 0.13)
                Ellipse().fill(bodyDark)
                    .frame(width: size * 0.095, height: size * 0.11)
            }
            .offset(y: size * 0.37)
        }
    }

    // MARK: - 팔

    var armsView: some View {
        let leftAngle: Double
        let rightAngle: Double

        switch mood {
        case .happy:  leftAngle = -45; rightAngle = 45
        case .angry:  leftAngle = -20; rightAngle = 20
        case .sad:    leftAngle = -5;  rightAngle = 5
        default:      leftAngle = -15; rightAngle = 15
        }

        return ZStack {
            // 왼팔
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(outline)
                    .frame(width: size * 0.085, height: size * 0.17)
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(bodyDark)
                    .frame(width: size * 0.065, height: size * 0.15)
            }
            .rotationEffect(.degrees(leftAngle), anchor: .top)
            .offset(x: -size * 0.3, y: size * 0.04)

            // 오른팔
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(outline)
                    .frame(width: size * 0.085, height: size * 0.17)
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(bodyDark)
                    .frame(width: size * 0.065, height: size * 0.15)
            }
            .rotationEffect(.degrees(rightAngle), anchor: .top)
            .offset(x: size * 0.3, y: size * 0.04)
        }
    }

    // MARK: - 눈썹

    @ViewBuilder
    var eyebrowsView: some View {
        switch mood {
        case .angry:
            HStack(spacing: size * 0.12) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(outline)
                    .frame(width: size * 0.09, height: size * 0.02)
                    .rotationEffect(.degrees(18))
                RoundedRectangle(cornerRadius: 1)
                    .fill(outline)
                    .frame(width: size * 0.09, height: size * 0.02)
                    .rotationEffect(.degrees(-18))
            }
            .offset(y: -size * 0.12)
        case .sad:
            HStack(spacing: size * 0.12) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(outline)
                    .frame(width: size * 0.07, height: size * 0.015)
                    .rotationEffect(.degrees(-12))
                RoundedRectangle(cornerRadius: 1)
                    .fill(outline)
                    .frame(width: size * 0.07, height: size * 0.015)
                    .rotationEffect(.degrees(12))
            }
            .offset(y: -size * 0.11)
        default:
            HStack(spacing: size * 0.14) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(outline.opacity(0.6))
                    .frame(width: size * 0.06, height: size * 0.013)
                RoundedRectangle(cornerRadius: 1)
                    .fill(outline.opacity(0.6))
                    .frame(width: size * 0.06, height: size * 0.013)
            }
            .offset(y: -size * 0.1)
        }
    }

    // MARK: - 눈

    @ViewBuilder
    var eyesView: some View {
        switch mood {
        case .happy, .full, .cook:
            // 웃는 눈 (∩ 모양)
            HStack(spacing: size * 0.12) {
                SmileEye(size: size)
                SmileEye(size: size)
            }
            .offset(y: -size * 0.04)

        case .sleeping:
            // 감은 눈
            HStack(spacing: size * 0.14) {
                ClosedEyeLine(size: size)
                ClosedEyeLine(size: size)
            }
            .offset(y: -size * 0.03)

        case .sad:
            // 눈물 눈
            HStack(spacing: size * 0.1) {
                BigEye(size: size, highlight: true)
                    .overlay(
                        TearDrop(size: size)
                            .offset(x: -size * 0.02, y: size * 0.065)
                    )
                BigEye(size: size, highlight: true)
                    .overlay(
                        TearDrop(size: size)
                            .offset(x: size * 0.02, y: size * 0.065)
                    )
            }
            .offset(y: -size * 0.04)

        case .angry:
            // 화난 눈
            HStack(spacing: size * 0.12) {
                SmallAngryEye(size: size)
                SmallAngryEye(size: size)
            }
            .offset(y: -size * 0.04)

        case .tired:
            // 반 감은 눈
            HStack(spacing: size * 0.14) {
                HalfEye(size: size)
                HalfEye(size: size)
            }
            .offset(y: -size * 0.03)

        case .hungry:
            // 반짝 큰 눈
            HStack(spacing: size * 0.1) {
                BigEye(size: size, highlight: true, sparkle: true)
                BigEye(size: size, highlight: true, sparkle: true)
            }
            .offset(y: -size * 0.04)

        case .work:
            // 안경 + 눈
            HStack(spacing: size * 0.04) {
                GlassEye(size: size)
                GlassEye(size: size)
            }
            .offset(y: -size * 0.04)

        default:
            // 기본 눈
            HStack(spacing: size * 0.1) {
                BigEye(size: size, highlight: true)
                BigEye(size: size, highlight: true)
            }
            .offset(y: -size * 0.04)
        }
    }

    // MARK: - 입

    @ViewBuilder
    var mouthView: some View {
        Group {
            switch mood {
            case .happy:
                PotatoMouth(type: .wide)
                    .fill(outline)
                    .frame(width: size * 0.14, height: size * 0.08)
            case .sad:
                PotatoMouth(type: .frown)
                    .stroke(outline, lineWidth: 2)
                    .frame(width: size * 0.1, height: size * 0.05)
            case .angry:
                PotatoMouth(type: .angry)
                    .stroke(outline, lineWidth: 2.5)
                    .frame(width: size * 0.12, height: size * 0.04)
            case .hungry, .eat:
                Ellipse()
                    .fill(outline)
                    .frame(width: size * 0.08, height: size * 0.1)
                    .overlay(
                        Ellipse()
                            .fill(Color(red: 0.7, green: 0.3, blue: 0.3))
                            .frame(width: size * 0.05, height: size * 0.06)
                            .offset(y: size * 0.01)
                    )
            case .sleeping:
                Ellipse()
                    .fill(outline)
                    .frame(width: size * 0.04, height: size * 0.045)
            case .full, .cook:
                PotatoMouth(type: .smile)
                    .stroke(outline, lineWidth: 2)
                    .frame(width: size * 0.1, height: size * 0.045)
            case .tired:
                PotatoMouth(type: .smile)
                    .stroke(outline, lineWidth: 1.5)
                    .frame(width: size * 0.06, height: size * 0.03)
            default:
                PotatoMouth(type: .smile)
                    .stroke(outline, lineWidth: 2)
                    .frame(width: size * 0.08, height: size * 0.04)
            }
        }
        .offset(y: size * 0.1)
    }

    // MARK: - 악세서리

    @ViewBuilder
    var accessoryView: some View {
        switch mood {
        case .sleeping:
            Text("💤").font(.system(size: size * 0.16))
                .offset(x: size * 0.3, y: -size * 0.3)
            // 수면모자
            SleepCap(size: size)
                .offset(y: -size * 0.35)
        case .cook:
            ChefHat(size: size)
                .offset(y: -size * 0.42)
        case .eat:
            Text("🍴").font(.system(size: size * 0.14))
                .offset(x: size * 0.32, y: size * 0.02)
        case .bathing:
            // 거품들
            BubbleGroup(size: size)
        case .work:
            Text("💻").font(.system(size: size * 0.14))
                .offset(y: size * 0.28)
        case .angry:
            Text("🔥").font(.system(size: size * 0.13))
                .offset(x: -size * 0.28, y: -size * 0.32)
            Text("🔥").font(.system(size: size * 0.13))
                .offset(x: size * 0.28, y: -size * 0.32)
            // 화남 표시
            AngryMark(size: size)
                .offset(x: size * 0.18, y: -size * 0.18)
        case .happy:
            Text("✨").font(.system(size: size * 0.11))
                .offset(x: -size * 0.3, y: -size * 0.25)
            Text("💕").font(.system(size: size * 0.1))
                .offset(x: size * 0.32, y: -size * 0.2)
        case .hungry:
            Text("💭").font(.system(size: size * 0.13))
                .offset(x: size * 0.28, y: -size * 0.3)
            Text("🍚").font(.system(size: size * 0.09))
                .offset(x: size * 0.29, y: -size * 0.31)
        case .dirty:
            Text("💦").font(.system(size: size * 0.1))
                .offset(x: size * 0.25, y: -size * 0.25)
            // 먼지
            Circle().fill(Color.brown.opacity(0.25))
                .frame(width: size * 0.06, height: size * 0.06)
                .offset(x: -size * 0.12, y: size * 0.05)
            Circle().fill(Color.brown.opacity(0.2))
                .frame(width: size * 0.05, height: size * 0.05)
                .offset(x: size * 0.15, y: size * 0.12)
            Circle().fill(Color.brown.opacity(0.3))
                .frame(width: size * 0.04, height: size * 0.04)
                .offset(x: size * 0.05, y: -size * 0.08)
        case .full:
            Text("♨️").font(.system(size: size * 0.11))
                .offset(y: -size * 0.38)
        case .sad:
            Text("💧").font(.system(size: size * 0.08))
                .offset(x: -size * 0.22, y: size * 0.05)
        default:
            EmptyView()
        }
    }
}

// MARK: - 감자 몸통 Shape

struct PotatoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        return Path { p in
            p.move(to: CGPoint(x: w * 0.5, y: h * 0.98))
            p.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.55),
                       control1: CGPoint(x: w * 0.78, y: h * 0.98),
                       control2: CGPoint(x: w * 0.96, y: h * 0.78))
            p.addCurve(to: CGPoint(x: w * 0.72, y: h * 0.04),
                       control1: CGPoint(x: w * 0.96, y: h * 0.28),
                       control2: CGPoint(x: w * 0.88, y: h * 0.1))
            p.addCurve(to: CGPoint(x: w * 0.28, y: h * 0.04),
                       control1: CGPoint(x: w * 0.62, y: 0),
                       control2: CGPoint(x: w * 0.38, y: 0))
            p.addCurve(to: CGPoint(x: w * 0.04, y: h * 0.55),
                       control1: CGPoint(x: w * 0.12, y: h * 0.1),
                       control2: CGPoint(x: w * 0.04, y: h * 0.28))
            p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.98),
                       control1: CGPoint(x: w * 0.04, y: h * 0.78),
                       control2: CGPoint(x: w * 0.22, y: h * 0.98))
        }
    }
}

// MARK: - 잎 Shape

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                           control: CGPoint(x: rect.midX, y: 0))
            p.addQuadCurve(to: CGPoint(x: 0, y: rect.midY),
                           control: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

// MARK: - 눈 컴포넌트

struct BigEye: View {
    let size: CGFloat
    var highlight: Bool = false
    var sparkle: Bool = false
    var body: some View {
        ZStack {
            // 흰자
            Ellipse()
                .fill(Color.white)
                .frame(width: size * 0.1, height: size * 0.11)
            // 동공
            Circle()
                .fill(Color(red: 0.25, green: 0.17, blue: 0.12))
                .frame(width: size * 0.085, height: size * 0.085)
            if highlight {
                Circle().fill(Color.white)
                    .frame(width: size * 0.03, height: size * 0.03)
                    .offset(x: size * 0.015, y: -size * 0.018)
                Circle().fill(Color.white.opacity(0.6))
                    .frame(width: size * 0.015, height: size * 0.015)
                    .offset(x: -size * 0.015, y: size * 0.015)
            }
            if sparkle {
                // 반짝이
                Circle().fill(Color.white)
                    .frame(width: size * 0.035, height: size * 0.035)
                    .offset(x: size * 0.015, y: -size * 0.02)
            }
        }
    }
}

struct SmileEye: View {
    let size: CGFloat
    var body: some View {
        ArcEyeShape()
            .fill(Color(red: 0.25, green: 0.17, blue: 0.12))
            .frame(width: size * 0.09, height: size * 0.045)
    }
}

struct ClosedEyeLine: View {
    let size: CGFloat
    var body: some View {
        ArcEyeShape()
            .stroke(Color(red: 0.25, green: 0.17, blue: 0.12), lineWidth: 2)
            .frame(width: size * 0.08, height: size * 0.03)
    }
}

struct HalfEye: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.25, green: 0.17, blue: 0.12))
                .frame(width: size * 0.08, height: size * 0.04)
            Circle().fill(Color.white)
                .frame(width: size * 0.02, height: size * 0.02)
                .offset(x: size * 0.01, y: -size * 0.005)
        }
    }
}

struct SmallAngryEye: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.3, green: 0.12, blue: 0.1))
                .frame(width: size * 0.07, height: size * 0.07)
            Circle().fill(Color.white)
                .frame(width: size * 0.02, height: size * 0.02)
                .offset(x: size * 0.01, y: -size * 0.01)
        }
    }
}

struct GlassEye: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.02)
                .stroke(Color(red: 0.3, green: 0.22, blue: 0.18), lineWidth: 2.5)
                .frame(width: size * 0.11, height: size * 0.09)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(Color.white.opacity(0.15))
                )
            Circle()
                .fill(Color(red: 0.25, green: 0.17, blue: 0.12))
                .frame(width: size * 0.05, height: size * 0.05)
            Circle().fill(Color.white)
                .frame(width: size * 0.018, height: size * 0.018)
                .offset(x: size * 0.008, y: -size * 0.01)
        }
    }
}

struct TearDrop: View {
    let size: CGFloat
    var body: some View {
        Ellipse()
            .fill(
                LinearGradient(colors: [Color.cyan.opacity(0.7), Color.blue.opacity(0.4)],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: size * 0.035, height: size * 0.05)
    }
}

// MARK: - 눈 호 Shape

struct ArcEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                           control: CGPoint(x: rect.midX, y: 0))
            p.closeSubpath()
        }
    }
}

// MARK: - 입 Shape

enum PotatoMouthType { case smile, wide, frown, angry }

struct PotatoMouth: Shape {
    let type: PotatoMouthType
    func path(in rect: CGRect) -> Path {
        Path { p in
            switch type {
            case .smile:
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: 0),
                               control: CGPoint(x: rect.midX, y: rect.maxY * 1.5))
            case .wide:
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: 0),
                               control: CGPoint(x: rect.midX, y: rect.maxY * 2))
                p.closeSubpath()
            case .frown:
                p.move(to: CGPoint(x: 0, y: rect.maxY))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                               control: CGPoint(x: rect.midX, y: 0))
            case .angry:
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: 0),
                               control: CGPoint(x: rect.midX, y: rect.maxY))
            }
        }
    }
}

// MARK: - 악세서리 컴포넌트

struct SleepCap: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            // 모자 본체
            PotatoShape()
                .fill(Color(red: 0.55, green: 0.42, blue: 0.28))
                .frame(width: size * 0.5, height: size * 0.2)
            // 격자 무늬
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(Color(red: 0.45, green: 0.35, blue: 0.22))
                    .frame(width: size * 0.02, height: size * 0.15)
                    .offset(x: CGFloat(i - 1) * size * 0.1)
                    .rotationEffect(.degrees(Double(i - 1) * 15))
            }
        }
    }
}

struct ChefHat: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            // 모자 윗부분
            Ellipse()
                .fill(Color.white)
                .frame(width: size * 0.28, height: size * 0.22)
                .offset(y: -size * 0.03)
            // 모자 밴드
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: size * 0.32, height: size * 0.06)
                .offset(y: size * 0.05)
            // 모자 그림자
            Ellipse()
                .fill(Color.gray.opacity(0.15))
                .frame(width: size * 0.24, height: size * 0.06)
                .offset(y: size * 0.03)
        }
    }
}

struct AngryMark: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.red.opacity(0.7))
                .frame(width: size * 0.06, height: size * 0.02)
            Rectangle()
                .fill(Color.red.opacity(0.7))
                .frame(width: size * 0.02, height: size * 0.06)
        }
        .rotationEffect(.degrees(15))
    }
}

struct BubbleGroup: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Color.cyan.opacity(0.25))
                .frame(width: size * 0.08)
                .offset(x: size * 0.25, y: -size * 0.2)
            Circle().fill(Color.cyan.opacity(0.2))
                .frame(width: size * 0.06)
                .offset(x: -size * 0.22, y: -size * 0.15)
            Circle().fill(Color.cyan.opacity(0.15))
                .frame(width: size * 0.05)
                .offset(x: size * 0.15, y: -size * 0.3)
            Circle().fill(Color.cyan.opacity(0.2))
                .frame(width: size * 0.07)
                .offset(x: -size * 0.28, y: -size * 0.28)
            Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                .frame(width: size * 0.06)
                .offset(x: size * 0.3, y: -size * 0.1)
        }
    }
}
