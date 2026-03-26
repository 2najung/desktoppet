import SwiftUI

struct WeatherEffectView: View {
    let condition: WeatherCondition

    var body: some View {
        ZStack {
            switch condition {
            case .rain:
                RainEffect(count: 35, length: 12, speed: 180)
            case .drizzle:
                RainEffect(count: 15, length: 8, speed: 100)
            case .snow:
                SnowEffect()
            case .clear:
                SparkleEffect()
            case .thunder:
                RainEffect(count: 35, length: 12, speed: 180)
                ThunderFlash()
            case .cloudy:
                CloudEffect()
            case .fog:
                FogEffect()
            case .wind:
                WindEffect()
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 비

struct RainEffect: View {
    let count: Int
    let length: CGFloat
    let speed: Double
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                for i in 0..<count {
                    let s = Double(i)
                    let x = (s * 8.7 + 3).truncatingRemainder(dividingBy: Double(size.width))
                    let v = speed + (s * 3).truncatingRemainder(dividingBy: 40)
                    let y = ((dt * v) + s * 37).truncatingRemainder(dividingBy: Double(size.height) + 30) - 15
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: y))
                        p.addLine(to: CGPoint(x: x - 1.5, y: y + length))
                    }
                    c.stroke(path, with: .color(.cyan.opacity(0.35)), lineWidth: 1.5)
                }
            }
        }
    }
}

// MARK: - 눈

struct SnowEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                for i in 0..<25 {
                    let s = Double(i)
                    let baseX = (s * 12.3 + 5).truncatingRemainder(dividingBy: Double(size.width))
                    let drift = sin(dt * 0.7 + s * 0.6) * 25
                    let x = baseX + drift
                    let v = 25 + (s * 2.3).truncatingRemainder(dividingBy: 15)
                    let y = ((dt * v) + s * 43).truncatingRemainder(dividingBy: Double(size.height) + 20) - 10
                    let r = 2 + (s.truncatingRemainder(dividingBy: 4))
                    let circle = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    c.fill(circle, with: .color(.white.opacity(0.7)))
                }
            }
        }
    }
}

// MARK: - 맑음 (반짝이)

struct SparkleEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                for i in 0..<12 {
                    let s = Double(i)
                    let x = (s * 23.7 + 10).truncatingRemainder(dividingBy: Double(size.width))
                    let y = (s * 37.3 + 15).truncatingRemainder(dividingBy: Double(size.height) * 0.5)
                    let phase = (dt * 0.4 + s * 0.55).truncatingRemainder(dividingBy: 3.0)
                    let opacity = phase < 1.5 ? sin(phase / 1.5 * .pi) * 0.45 : 0.0
                    let r = phase < 1.5 ? sin(phase / 1.5 * .pi) * 3.5 + 0.5 : 0.0

                    if opacity > 0.01 {
                        let circle = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                        c.fill(circle, with: .color(Color(red: 1, green: 0.85, blue: 0.2, opacity: opacity)))
                    }
                }
            }
        }
    }
}

// MARK: - 천둥 번쩍

struct ThunderFlash: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            let dt = ctx.date.timeIntervalSince(t0)
            let cycle = dt.truncatingRemainder(dividingBy: 4.5)
            let flash = cycle < 0.08 || (cycle > 0.15 && cycle < 0.2)
            Rectangle()
                .fill(Color.white.opacity(flash ? 0.5 : 0))
        }
    }
}

// MARK: - 흐림 (구름)

struct CloudEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                for i in 0..<5 {
                    let s = Double(i)
                    let baseX = s * 70
                    let x = (baseX + dt * (6 + s * 1.5)).truncatingRemainder(dividingBy: Double(size.width) + 80) - 40
                    let y = 15 + s * 22
                    let w = 55 + s * 8
                    let h = 18 + s * 4
                    let cloud = Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h))
                    c.fill(cloud, with: .color(.gray.opacity(0.12)))
                }
            }
        }
    }
}

// MARK: - 안개

struct FogEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            let dt = ctx.date.timeIntervalSince(t0)
            let opacity = 0.12 + sin(dt * 0.25) * 0.05
            Rectangle()
                .fill(Color.white.opacity(opacity))
        }
    }
}

// MARK: - 바람 (나뭇잎)

struct WindEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                let leaf = c.resolve(Text("🍃").font(.system(size: 14)))
                for i in 0..<8 {
                    let s = Double(i)
                    let v = 55 + s * 12
                    let x = ((dt * v) + s * 45).truncatingRemainder(dividingBy: Double(size.width) + 40) - 20
                    let baseY = (s * 52 + 20).truncatingRemainder(dividingBy: Double(size.height) * 0.7)
                    let y = baseY + sin(dt * 1.8 + s) * 18
                    c.draw(leaf, at: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

// MARK: - 레벨업 빵빠레

struct ConfettiOverlay: View {
    @State private var t0 = Date.now
    private let colors: [Color] = [.red, .yellow, .green, .blue, .purple, .orange, .pink, .mint, .cyan]

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                if dt > 3.5 { return }

                if dt < 2 {
                    let text = c.resolve(Text("🎉 LEVEL UP! 🎉").font(.system(size: 14, weight: .black, design: .rounded)))
                    let yy = size.height * 0.15 + sin(dt * 4) * 5
                    c.draw(text, at: CGPoint(x: size.width / 2, y: yy))
                }

                for i in 0..<40 {
                    let s = Double(i)
                    let angle = s * 0.157 + s * 0.37
                    let speed = 60 + (s * 7).truncatingRemainder(dividingBy: 50)
                    let vx = cos(angle) * speed
                    let vy = -120 - s * 3
                    let gravity = 180.0
                    let x = size.width / 2 + vx * dt
                    let y = size.height * 0.4 + vy * dt + 0.5 * gravity * dt * dt
                    let opacity = max(0, 1 - dt / 3.0)
                    guard opacity > 0 else { continue }
                    let w: CGFloat = 5 + CGFloat(s.truncatingRemainder(dividingBy: 3))
                    let h: CGFloat = 3 + CGFloat(s.truncatingRemainder(dividingBy: 2))
                    let color = colors[i % colors.count]
                    let rect = CGRect(x: x - w/2, y: y - h/2, width: w, height: h)
                    c.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color.opacity(opacity)))
                }
            }
        }
        .transition(.opacity)
    }
}
